"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";
import { DOCTOR_NAV } from "@/components/layout/nav-items";

export function MobileTabBar() {
  const pathname = usePathname();

  return (
    <nav
      aria-label="Primary"
      className="fixed inset-x-3 bottom-3 z-40 flex items-center justify-around rounded-full bg-frame px-2 py-2 shadow-frame md:hidden"
    >
      {DOCTOR_NAV.map((item) => {
        const active =
          pathname === item.href || pathname.startsWith(`${item.href}/`);
        const Icon = item.icon;
        return (
          <Link
            key={item.href}
            href={item.href}
            aria-current={active ? "page" : undefined}
            className={cn(
              "flex flex-col items-center gap-0.5 rounded-full px-3 py-1.5 text-[10px] font-semibold text-white/55 transition-colors",
              active && "bg-white/10 text-white"
            )}
          >
            <Icon className="size-5" aria-hidden />
            <span>{item.label}</span>
          </Link>
        );
      })}
    </nav>
  );
}
