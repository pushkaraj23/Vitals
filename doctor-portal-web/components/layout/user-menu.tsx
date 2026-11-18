"use client";

import { ChevronDown } from "lucide-react";
import { Avatar, AvatarFallback } from "@/components/ui/avatar";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";

interface UserMenuProps {
  name: string;
  specialty?: string | null;
  onLogout?: () => void;
}

export function UserMenu({ name, specialty, onLogout }: UserMenuProps) {
  const initials = name
    .split(" ")
    .map((part) => part[0])
    .join("")
    .slice(0, 2)
    .toUpperCase();

  return (
    <DropdownMenu>
      <DropdownMenuTrigger className="relative z-10 flex items-center gap-2 rounded-full bg-chip py-1.5 pr-3 pl-1.5 text-sm font-semibold text-ink outline-none transition-colors hover:bg-[color-mix(in_srgb,var(--chip),var(--ink)_5%)] focus-visible:ring-3 focus-visible:ring-ring/50">
        <Avatar className="size-8">
          <AvatarFallback className="bg-lavender text-xs font-bold text-violet">
            {initials || "DR"}
          </AvatarFallback>
        </Avatar>
        <span className="hidden max-w-[160px] truncate sm:inline">{name}</span>
        <ChevronDown className="size-4 text-ink-muted" aria-hidden />
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" sideOffset={8} className="w-52 rounded-xl">
        {specialty ? (
          <p className="px-2 py-1.5 text-xs font-medium text-ink-muted">
            {specialty}
          </p>
        ) : null}
        <DropdownMenuItem onClick={onLogout}>Sign out</DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
