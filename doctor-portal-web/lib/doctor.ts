import type { User } from "firebase/auth";
import { doc, getDoc } from "firebase/firestore";
import { getDb } from "@/lib/firebase";

export interface DoctorProfile {
  uid: string;
  name: string;
  email: string;
  specialty: string | null;
}

function text(value: unknown): string {
  return typeof value === "string" ? value.trim() : "";
}

export class DoctorAccessError extends Error {
  constructor(message: string) {
    super(message);
    this.name = "DoctorAccessError";
  }
}

/** Doctor accounts live in `doctors/{uid}`. Patients are not admitted. */
export async function fetchDoctorProfile(user: User): Promise<DoctorProfile | null> {
  try {
    const snap = await getDoc(doc(getDb(), "doctors", user.uid));
    if (!snap.exists()) return null;

    const data = snap.data();
    if (data.active === false) return null;

    return {
      uid: user.uid,
      name: text(data.name) || user.displayName || "Doctor",
      email: text(data.email) || user.email || "",
      specialty: text(data.specialty) || null,
    };
  } catch (error) {
    const code =
      typeof error === "object" && error && "code" in error
        ? String((error as { code: string }).code)
        : "";
    if (code === "permission-denied") {
      throw new DoctorAccessError(
        "Firestore blocked reading doctors/" +
          user.uid +
          ". Deploy rules that allow a signed-in doctor to read their own profile."
      );
    }
    throw error;
  }
}
