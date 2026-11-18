"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/components/providers/auth-provider";
import { Skeleton } from "@/components/ui/skeleton";

/** Sends signed-out visitors and non-doctors back to the login screen. */
export function AuthGate({ children }: { children: React.ReactNode }) {
  const { doctor, loading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!loading && !doctor) {
      router.replace("/login");
    }
  }, [doctor, loading, router]);

  if (loading || !doctor) {
    return (
      <div className="flex min-h-full items-center justify-center bg-page-bg p-8">
        <Skeleton className="h-40 w-full max-w-md rounded-card" />
      </div>
    );
  }

  return <>{children}</>;
}
