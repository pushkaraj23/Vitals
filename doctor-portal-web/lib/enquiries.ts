import {
  doc,
  onSnapshot,
  orderBy,
  query,
  collection,
  serverTimestamp,
  setDoc,
  updateDoc,
  type Unsubscribe,
} from "firebase/firestore";
import { format } from "date-fns";
import { getDb } from "@/lib/firebase";
import type { DoctorProfile } from "@/lib/doctor";

export const ENQUIRY_STATUSES = ["open", "in_review", "resolved"] as const;
export type EnquiryStatus = (typeof ENQUIRY_STATUSES)[number];

export const ENQUIRY_VERDICTS = [
  "Confirmed",
  "Not concerning",
  "Needs consultation",
] as const;
export type EnquiryVerdict = (typeof ENQUIRY_VERDICTS)[number];

export interface Enquiry {
  id: string;
  patientId: string;
  patientName: string;
  patientEmail: string | null;
  flagId: string;
  flagTitle: string;
  flagLevel: string;
  metric: string;
  message: string;
  status: EnquiryStatus;
  verdict: EnquiryVerdict | null;
  doctorNote: string;
  doctorId: string | null;
  doctorName: string | null;
  createdAt: Date | null;
  updatedAt: Date | null;
}

export interface EnquiryUpdate {
  status: EnquiryStatus;
  verdict: EnquiryVerdict | null;
  doctorNote: string;
}

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

function asDate(value: unknown): Date | null {
  if (
    value &&
    typeof value === "object" &&
    "toDate" in value &&
    typeof (value as { toDate: unknown }).toDate === "function"
  ) {
    const date = (value as { toDate: () => Date }).toDate();
    return Number.isNaN(date.getTime()) ? null : date;
  }
  return null;
}

function asStatus(value: unknown): EnquiryStatus {
  return value === "in_review" || value === "resolved" || value === "open"
    ? value
    : "open";
}

function asVerdict(value: unknown): EnquiryVerdict | null {
  return ENQUIRY_VERDICTS.find((verdict) => verdict === value) ?? null;
}

export function toEnquiry(id: string, data: Record<string, unknown>): Enquiry {
  return {
    id,
    patientId: text(data.patientId),
    patientName: text(data.patientName) || "Patient",
    patientEmail: text(data.patientEmail) || null,
    flagId: text(data.flagId),
    flagTitle: text(data.flagTitle) || "Pattern flag",
    flagLevel: text(data.flagLevel),
    metric: text(data.metric),
    message: text(data.message),
    status: asStatus(data.status),
    verdict: asVerdict(data.verdict),
    doctorNote: text(data.doctorNote),
    doctorId: text(data.doctorId) || null,
    doctorName: text(data.doctorName) || null,
    createdAt: asDate(data.createdAt),
    updatedAt: asDate(data.updatedAt),
  };
}

export function statusLabel(status: EnquiryStatus): string {
  switch (status) {
    case "in_review":
      return "In review";
    case "resolved":
      return "Resolved";
    default:
      return "Open";
  }
}

export function subscribeEnquiries(
  onData: (items: Enquiry[]) => void,
  onError: (error: Error) => void
): Unsubscribe {
  const enquiryQuery = query(
    collection(getDb(), "enquiries"),
    orderBy("createdAt", "desc")
  );
  return onSnapshot(
    enquiryQuery,
    (snap) => {
      onData(snap.docs.map((item) => toEnquiry(item.id, item.data())));
    },
    (error) => onError(error)
  );
}

export function subscribeEnquiry(
  id: string,
  onData: (item: Enquiry | null) => void,
  onError: (error: Error) => void
): Unsubscribe {
  return onSnapshot(
    doc(getDb(), "enquiries", id),
    (snap) => {
      onData(snap.exists() ? toEnquiry(snap.id, snap.data()) : null);
    },
    (error) => onError(error)
  );
}

/**
 * Saves the doctor's response and mirrors a completed or in-progress
 * review onto the patient's `users/{uid}/reviews/{flagId}` document.
 */
export async function saveEnquiryResponse(
  enquiry: Enquiry,
  doctor: DoctorProfile,
  update: EnquiryUpdate
): Promise<void> {
  const note = update.doctorNote.trim();
  await updateDoc(doc(getDb(), "enquiries", enquiry.id), {
    status: update.status,
    verdict: update.status === "resolved" ? update.verdict : null,
    doctorNote: note,
    doctorId: doctor.uid,
    doctorName: doctor.name,
    updatedAt: serverTimestamp(),
  });

  if (!enquiry.patientId || !enquiry.flagId) return;

  const reviewedAt = format(new Date(), "yyyy-MM-dd");
  const patientNote =
    note ||
    (update.status === "resolved"
      ? "Reviewed in the doctor portal."
      : update.status === "in_review"
        ? "A doctor is reviewing this pattern."
        : "Review request received.");

  const patientStatus =
    update.status === "resolved"
      ? "reviewed"
      : update.status === "in_review"
        ? "in_review"
        : "pending";

  try {
    await setDoc(
      doc(getDb(), "users", enquiry.patientId, "reviews", enquiry.flagId),
      {
        verdict:
          update.status === "resolved" && update.verdict
            ? update.verdict
            : "",
        note: patientNote,
        reviewerName: doctor.name,
        reviewedAt,
        simulated: false,
        status: patientStatus,
        updatedAt: serverTimestamp(),
      },
      { merge: true }
    );
  } catch (error) {
    const reason = error instanceof Error ? error.message : "Permission denied";
    throw new Error(
      `Enquiry saved, but the patient app could not be updated (${reason}). Allow doctors to write users/{uid}/reviews.`
    );
  }
}
