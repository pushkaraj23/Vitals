import { cn } from "@/lib/utils";

/** Short medical disclaimer — VitalWatch does not diagnose. */
export function Disclaimer({ className }: { className?: string }) {
  return (
    <p
      className={cn(
        "text-center text-xs font-medium leading-relaxed text-ink-muted",
        className
      )}
    >
      VitalWatch provides wellness insights, not medical diagnoses. Notes saved
      here are shared with the patient in the app. This is not an emergency
      service.
    </p>
  );
}
