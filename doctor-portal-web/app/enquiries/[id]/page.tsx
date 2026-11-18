"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import { format } from "date-fns";
import { ArrowLeft } from "lucide-react";
import { toast } from "sonner";
import { AppFrame } from "@/components/layout/app-frame";
import { AuthGate } from "@/components/layout/auth-gate";
import { LevelBadge, StatusBadge } from "@/components/enquiries/badges";
import { EmptyState } from "@/components/feedback/empty-state";
import { ErrorState } from "@/components/feedback/error-state";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Skeleton } from "@/components/ui/skeleton";
import { useAuth } from "@/components/providers/auth-provider";
import {
  ENQUIRY_STATUSES,
  ENQUIRY_VERDICTS,
  saveEnquiryResponse,
  statusLabel,
  subscribeEnquiry,
  type Enquiry,
  type EnquiryStatus,
  type EnquiryVerdict,
} from "@/lib/enquiries";

export default function EnquiryDetailPage() {
  return (
    <AuthGate>
      <EnquiryDetail />
    </AuthGate>
  );
}

function EnquiryDetail() {
  const params = useParams<{ id: string }>();
  const rawId = Array.isArray(params.id) ? params.id[0] : params.id;
  const enquiryId = decodeURIComponent(rawId ?? "");
  const { doctor } = useAuth();
  const [enquiry, setEnquiry] = useState<Enquiry | null | undefined>(undefined);
  const [error, setError] = useState<string | null>(null);
  const [retryKey, setRetryKey] = useState(0);
  const [status, setStatus] = useState<EnquiryStatus>("open");
  const [verdict, setVerdict] = useState<EnquiryVerdict | "">("");
  const [note, setNote] = useState("");
  const [dirty, setDirty] = useState(false);
  const [saving, setSaving] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);

  useEffect(() => {
    setError(null);
    setEnquiry(undefined);
    const unsubscribe = subscribeEnquiry(
      enquiryId,
      (next) => {
        setEnquiry(next);
        setError(null);
      },
      (err) => {
        setEnquiry(null);
        setError(err.message);
      }
    );
    return unsubscribe;
  }, [enquiryId, retryKey]);

  useEffect(() => {
    if (!enquiry || dirty) return;
    setStatus(enquiry.status);
    setVerdict(enquiry.verdict ?? "");
    setNote(enquiry.doctorNote);
  }, [enquiry, dirty]);

  async function onSubmit(event: React.FormEvent) {
    event.preventDefault();
    if (!enquiry || !doctor) return;
    if (status === "resolved" && !verdict) {
      setFormError("Choose a verdict before resolving this enquiry.");
      return;
    }
    setFormError(null);
    setSaving(true);
    try {
      await saveEnquiryResponse(enquiry, doctor, {
        status,
        verdict: verdict || null,
        doctorNote: note,
      });
      setDirty(false);
      toast.success("Enquiry updated.");
    } catch (err) {
      const message = err instanceof Error ? err.message : "Could not save.";
      setFormError(message);
      toast.error(message);
    } finally {
      setSaving(false);
    }
  }

  return (
    <AppFrame title="Enquiry">
      <Link
        href="/enquiries"
        className="mb-5 inline-flex items-center gap-2 text-sm font-bold text-accent-ink"
      >
        <ArrowLeft className="size-4" aria-hidden />
        All enquiries
      </Link>

      {enquiry === undefined && !error ? (
        <Skeleton className="h-80 w-full rounded-card" />
      ) : error ? (
        <ErrorState
          title="Could not load this enquiry"
          message={error}
          onRetry={() => setRetryKey((key) => key + 1)}
        />
      ) : !enquiry ? (
        <EmptyState
          title="Enquiry not found"
          description="It may have been removed."
        />
      ) : (
        <div className="grid gap-4 lg:grid-cols-[minmax(0,1.1fr)_minmax(0,0.9fr)]">
          <section className="rounded-card bg-sky/60 p-5">
            <div className="flex flex-wrap items-center gap-2">
              <LevelBadge level={enquiry.flagLevel} />
              <StatusBadge status={enquiry.status} />
            </div>
            <h2 className="mt-3 text-2xl font-extrabold text-ink">
              {enquiry.flagTitle}
            </h2>
            <p className="mt-1 text-sm font-semibold text-ink">
              {enquiry.patientName}
              {enquiry.patientEmail ? (
                <span className="font-medium text-ink-muted">
                  {" "}
                  · {enquiry.patientEmail}
                </span>
              ) : null}
            </p>
            {enquiry.metric ? (
              <p className="mt-1 text-xs font-semibold tracking-wide text-ink-muted uppercase">
                {enquiry.metric.replace(/_/g, " ")}
              </p>
            ) : null}
            <p className="mt-4 text-sm leading-relaxed font-medium whitespace-pre-wrap text-ink">
              {enquiry.message || "The patient did not include a message."}
            </p>
            <p className="mt-4 text-xs font-semibold text-ink-muted">
              {enquiry.createdAt
                ? `Received ${format(enquiry.createdAt, "d MMM yyyy, HH:mm")}`
                : "Received just now"}
              {enquiry.doctorName ? ` · Last reply by ${enquiry.doctorName}` : ""}
            </p>
          </section>

          <form
            onSubmit={onSubmit}
            className="rounded-card border border-line p-5"
          >
            <h2 className="text-lg font-extrabold text-ink">Your response</h2>
            <p className="mt-1 text-sm font-medium text-ink-muted">
              Resolving writes the verdict back to the patient&apos;s review.
            </p>

            <div className="mt-5 space-y-2">
              <Label htmlFor="status">Status</Label>
              <select
                id="status"
                value={status}
                onChange={(event) => {
                  setDirty(true);
                  setStatus(event.target.value as EnquiryStatus);
                }}
                className="h-11 w-full rounded-2xl border border-line bg-chip px-4 text-sm font-semibold text-ink outline-none focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50"
              >
                {ENQUIRY_STATUSES.map((value) => (
                  <option key={value} value={value}>
                    {statusLabel(value)}
                  </option>
                ))}
              </select>
            </div>

            <div className="mt-4 space-y-2">
              <Label htmlFor="verdict">Verdict</Label>
              <select
                id="verdict"
                value={verdict}
                onChange={(event) => {
                  setDirty(true);
                  setVerdict(event.target.value as EnquiryVerdict | "");
                }}
                className="h-11 w-full rounded-2xl border border-line bg-chip px-4 text-sm font-semibold text-ink outline-none focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50"
              >
                <option value="">Not set</option>
                {ENQUIRY_VERDICTS.map((value) => (
                  <option key={value} value={value}>
                    {value}
                  </option>
                ))}
              </select>
            </div>

            <div className="mt-4 space-y-2">
              <Label htmlFor="note">Note to the patient</Label>
              <textarea
                id="note"
                value={note}
                onChange={(event) => {
                  setDirty(true);
                  setNote(event.target.value);
                }}
                rows={6}
                placeholder="What should the patient know about this pattern?"
                className="w-full rounded-xl border border-line bg-chip px-4 py-3 text-sm font-medium text-ink outline-none placeholder:text-ink-muted focus-visible:border-ring focus-visible:ring-3 focus-visible:ring-ring/50"
              />
            </div>

            {formError ? (
              <p className="mt-3 text-sm font-semibold text-bad" role="alert">
                {formError}
              </p>
            ) : null}

            <Button type="submit" className="mt-5 w-full" disabled={saving}>
              {saving ? "Saving…" : "Save response"}
            </Button>
          </form>
        </div>
      )}
    </AppFrame>
  );
}
