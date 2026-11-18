"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { Activity, LogOut } from "lucide-react";
import { cn } from "@/lib/utils";
import { DOCTOR_NAV } from "@/components/layout/nav-items";
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@/components/ui/tooltip";

interface SidebarProps {
  onLogout?: () => void;
}

export function Sidebar({ onLogout }: SidebarProps) {
  const pathname = usePathname();

  return (
    <aside
      aria-label="Primary"
      className="hidden w-[72px] shrink-0 flex-col items-center py-5 md:flex"
    >
      <Link
        href="/enquiries"
        className="mb-8 flex size-11 items-center justify-center rounded-2xl bg-cream text-accent-ink shadow-sm transition-transform duration-150 ease-out hover:-translate-y-0.5"
        aria-label="Enquiries"
      >
        <Activity className="size-5" strokeWidth={2.5} aria-hidden />
      </Link>

      <nav className="flex flex-1 flex-col items-center gap-1">
        {DOCTOR_NAV.map((item) => {
          const active =
            pathname === item.href || pathname.startsWith(`${item.href}/`);
          const Icon = item.icon;
          return (
            <Tooltip key={item.href}>
              <TooltipTrigger
                className={cn(
                  "relative flex size-11 items-center justify-center rounded-full border-0 text-white/55 transition-colors duration-150 ease-out hover:bg-white/8 hover:text-white",
                  active && "bg-white/10 text-white"
                )}
                render={
                  <Link
                    href={item.href}
                    aria-current={active ? "page" : undefined}
                  />
                }
              >
                {active ? (
                  <span
                    className="absolute left-0 h-5 w-1 rounded-r-full bg-accent"
                    aria-hidden
                  />
                ) : null}
                <Icon className="size-5" aria-hidden />
              </TooltipTrigger>
              <TooltipContent side="right" className="rounded-full">
                {item.label}
              </TooltipContent>
            </Tooltip>
          );
        })}
      </nav>

      <Tooltip>
        <TooltipTrigger
          type="button"
          onClick={onLogout}
          className="mt-auto flex size-11 items-center justify-center rounded-full border-0 bg-transparent text-white/55 transition-colors hover:bg-white/8 hover:text-white"
          aria-label="Sign out"
        >
          <LogOut className="size-5" aria-hidden />
        </TooltipTrigger>
        <TooltipContent side="right" className="rounded-full">
          Sign out
        </TooltipContent>
      </Tooltip>
    </aside>
  );
}
