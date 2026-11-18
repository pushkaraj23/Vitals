import { cn } from "@/lib/utils";

interface EmptyStateProps {
  title: string;
  description?: string;
  className?: string;
  action?: React.ReactNode;
}

/** Placeholder when a list or view has no data. */
export function EmptyState({
  title,
  description,
  className,
  action,
}: EmptyStateProps) {
  return (
    <div
      className={cn(
        "flex flex-col items-center justify-center rounded-card bg-chip px-6 py-12 text-center",
        className
      )}
    >
      <h3 className="text-lg font-bold text-ink">{title}</h3>
      {description ? (
        <p className="mt-2 max-w-sm text-sm font-medium text-ink-muted">
          {description}
        </p>
      ) : null}
      {action ? <div className="mt-5">{action}</div> : null}
    </div>
  );
}
