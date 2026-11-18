"use client";

import { useEffect } from "react";
import { useRouter } from "next/navigation";
import { useAuth } from "@/components/providers/auth-provider";
import { Skeleton } from "@/components/ui/skeleton";

export default function HomePage() {
  const { doctor, loading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (loading) return;
    router.replace(doctor ? "/enquiries" : "/login");
  }, [doctor, loading, router]);

  return (
    <div className="flex min-h-full items-center justify-center bg-page-bg p-8">
      <Skeleton className="h-40 w-full max-w-md rounded-card" />
    </div>
  );
}
