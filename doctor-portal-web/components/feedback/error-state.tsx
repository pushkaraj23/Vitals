import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";

interface ErrorStateProps {
  title?: string;
  message?: string;
  onRetry?: () => void;
  className?: string;
}

/** Error surface for failed data views. */
export function ErrorState({
  title = "Something went wrong",
  message = "We could not load this view. Try again in a moment.",
  onRetry,
  className,
}: ErrorStateProps) {
  return (
    <div
      className={cn(
        "flex flex-col items-center justify-center rounded-card bg-rose-soft px-6 py-12 text-center",
        className
      )}
    >
      <h3 className="text-lg font-bold text-ink">{title}</h3>
      <p className="mt-2 max-w-sm text-sm font-medium text-ink-muted">{message}</p>
      {onRetry ? (
        <Button className="mt-5" onClick={onRetry} type="button">
          Try again
        </Button>
      ) : null}
    </div>
  );
}
