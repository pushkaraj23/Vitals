import { cn } from "@/lib/utils";
import { statusLabel, type EnquiryStatus } from "@/lib/enquiries";

const STATUS_CLASS: Record<EnquiryStatus, string> = {
  open: "bg-sky text-accent-ink",
  in_review: "bg-cream text-[#8a5a00]",
  resolved: "bg-mint text-[#1d6b3a]",
};

const LEVEL_CLASS: Record<string, string> = {
  red: "bg-rose-soft text-bad",
  amber: "bg-cream text-[#8a5a00]",
  green: "bg-mint text-[#1d6b3a]",
};

export function StatusBadge({ status }: { status: EnquiryStatus }) {
  return (
    <span
      className={cn(
        "inline-flex h-6 items-center rounded-full px-2.5 text-xs font-bold",
        STATUS_CLASS[status]
      )}
    >
      {statusLabel(status)}
    </span>
  );
}

export function LevelBadge({ level }: { level: string }) {
  if (!level) return null;
  return (
    <span
      className={cn(
        "inline-flex h-6 items-center rounded-full px-2.5 text-xs font-bold capitalize",
        LEVEL_CLASS[level] ?? "bg-chip text-ink"
      )}
    >
      {level}
    </span>
  );
}
