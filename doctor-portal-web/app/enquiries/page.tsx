"use client";

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import { formatDistanceToNow } from "date-fns";
import { AppFrame } from "@/components/layout/app-frame";
import { AuthGate } from "@/components/layout/auth-gate";
import { LevelBadge, StatusBadge } from "@/components/enquiries/badges";
import { EmptyState } from "@/components/feedback/empty-state";
import { ErrorState } from "@/components/feedback/error-state";
import { Input } from "@/components/ui/input";
import { Skeleton } from "@/components/ui/skeleton";
import {
  statusLabel,
  subscribeEnquiries,
  type Enquiry,
  type EnquiryStatus,
} from "@/lib/enquiries";
import { cn } from "@/lib/utils";

type Filter = "all" | EnquiryStatus;

const FILTERS: { id: Filter; label: string }[] = [
  { id: "all", label: "All" },
  { id: "open", label: "Open" },
  { id: "in_review", label: "In review" },
  { id: "resolved", label: "Resolved" },
];

export default function EnquiriesPage() {
  return (
    <AuthGate>
      <EnquiryList />
    </AuthGate>
  );
}

function EnquiryList() {
  const [items, setItems] = useState<Enquiry[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [filter, setFilter] = useState<Filter>("open");
  const [search, setSearch] = useState("");
  const [retryKey, setRetryKey] = useState(0);

  useEffect(() => {
    setError(null);
    const unsubscribe = subscribeEnquiries(
      (next) => {
        setItems(next);
        setError(null);
      },
      (err) => {
        setItems([]);
        setError(err.message);
      }
    );
    return unsubscribe;
  }, [retryKey]);

  const counts = useMemo(() => {
    const list = items ?? [];
    return {
      all: list.length,
      open: list.filter((item) => item.status === "open").length,
      in_review: list.filter((item) => item.status === "in_review").length,
      resolved: list.filter((item) => item.status === "resolved").length,
    };
  }, [items]);

  const visible = useMemo(() => {
    const query = search.trim().toLowerCase();
    return (items ?? []).filter((item) => {
      if (filter !== "all" && item.status !== filter) return false;
      if (!query) return true;
      return [item.patientName, item.patientEmail, item.flagTitle, item.metric]
        .filter(Boolean)
        .join(" ")
        .toLowerCase()
        .includes(query);
    });
  }, [filter, items, search]);

  return (
    <AppFrame title="Enquiries">
      <p className="mb-5 max-w-2xl text-sm font-medium text-ink-muted">
        Patient review requests from the VitalWatch app. Updates appear as they
        are sent.
      </p>

      <div className="mb-4 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex flex-wrap gap-2">
          {FILTERS.map((item) => (
            <button
              key={item.id}
              type="button"
              onClick={() => setFilter(item.id)}
              className={cn(
                "rounded-full px-4 py-2 text-sm font-semibold transition-colors",
                filter === item.id
                  ? "bg-accent text-accent-ink"
                  : "bg-chip text-ink"
              )}
            >
              {item.label}
              <span className="ml-1.5 text-xs opacity-70">{counts[item.id]}</span>
            </button>
          ))}
        </div>
        <Input
          value={search}
          onChange={(event) => setSearch(event.target.value)}
          placeholder="Search patient or flag"
          aria-label="Search enquiries"
          className="h-10 w-full rounded-2xl border-line bg-chip px-4 sm:max-w-xs"
        />
      </div>

      {items === null && !error ? (
        <Skeleton className="h-64 w-full rounded-card" />
      ) : error ? (
        <ErrorState
          title="Could not load enquiries"
          message={error}
          onRetry={() => setRetryKey((key) => key + 1)}
        />
      ) : visible.length === 0 ? (
        <EmptyState
          title={items?.length ? "Nothing in this view" : "No enquiries yet"}
          description={
            items?.length
              ? `No ${filter === "all" ? "" : statusLabel(filter).toLowerCase() + " "}enquiries match.`
              : "When a patient requests a review in the app, it shows up here."
          }
        />
      ) : (
        <ul className="space-y-3">
          {visible.map((item) => (
            <li key={item.id}>
              <Link
                href={`/enquiries/${item.id}`}
                className="block rounded-card border border-line bg-panel p-4 transition-colors hover:bg-chip/60"
              >
                <div className="flex flex-wrap items-start justify-between gap-3">
                  <div className="min-w-0">
                    <p className="text-base font-bold text-ink">{item.patientName}</p>
                    {item.patientEmail ? (
                      <p className="text-xs font-medium text-ink-muted">
                        {item.patientEmail}
                      </p>
                    ) : null}
                    <p className="mt-2 text-sm font-semibold text-ink">
                      {item.flagTitle}
                    </p>
                    {item.metric ? (
                      <p className="text-xs font-medium text-ink-muted capitalize">
                        {item.metric.replace(/_/g, " ")}
                      </p>
                    ) : null}
                  </div>
                  <div className="flex flex-wrap items-center gap-2">
                    <LevelBadge level={item.flagLevel} />
                    <StatusBadge status={item.status} />
                  </div>
                </div>
                <p className="mt-3 line-clamp-2 text-sm font-medium text-ink-muted">
                  {item.message || "No message included."}
                </p>
                <p className="mt-3 text-xs font-semibold text-ink-muted">
                  {item.createdAt
                    ? formatDistanceToNow(item.createdAt, { addSuffix: true })
                    : "Just now"}
                </p>
              </Link>
            </li>
          ))}
        </ul>
      )}
    </AppFrame>
  );
}
