"use client";

import { useRouter } from "next/navigation";
import { Sidebar } from "@/components/layout/sidebar";
import { MobileTabBar } from "@/components/layout/mobile-tab-bar";
import { TopBar } from "@/components/layout/top-bar";
import { Disclaimer } from "@/components/feedback/disclaimer";
import { useAuth } from "@/components/providers/auth-provider";

interface AppFrameProps {
  title: string;
  children: React.ReactNode;
}

export function AppFrame({ title, children }: AppFrameProps) {
  const router = useRouter();
  const { doctor, signOut } = useAuth();

  async function handleLogout() {
    await signOut();
    router.push("/login");
  }

  return (
    <div className="flex h-[100dvh] overflow-hidden bg-frame">
      <Sidebar onLogout={handleLogout} />
      <div className="flex min-w-0 flex-1 flex-col p-0 md:p-6 md:pl-2 lg:p-8 lg:pl-3">
        <div className="flex min-h-0 flex-1 flex-col overflow-hidden rounded-none bg-panel md:rounded-panel">
          <div className="flex min-h-0 flex-1 flex-col overflow-y-auto px-4 pt-5 pb-24 md:px-8 md:pt-7 md:pb-6">
            <TopBar
              title={title}
              userName={doctor?.name ?? "Doctor"}
              specialty={doctor?.specialty}
              onLogout={handleLogout}
            />
            <div className="flex-1">{children}</div>
            <footer className="mt-8 border-t border-line pt-4">
              <Disclaimer />
            </footer>
          </div>
        </div>
      </div>
      <MobileTabBar />
    </div>
  );
}
