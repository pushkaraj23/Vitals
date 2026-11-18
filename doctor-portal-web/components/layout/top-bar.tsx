"use client";

import { UserMenu } from "@/components/layout/user-menu";

interface TopBarProps {
  title: string;
  userName: string;
  specialty?: string | null;
  onLogout?: () => void;
}

export function TopBar({ title, userName, specialty, onLogout }: TopBarProps) {
  return (
    <header className="mb-6 flex flex-wrap items-center justify-between gap-4">
      <h1 className="text-[36px] font-extrabold tracking-tight text-ink md:text-[40px]">
        {title}
      </h1>
      <UserMenu name={userName} specialty={specialty} onLogout={onLogout} />
    </header>
  );
}
