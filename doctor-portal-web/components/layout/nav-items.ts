import type { LucideIcon } from "lucide-react";
import { Inbox } from "lucide-react";

export interface NavItem {
  href: string;
  label: string;
  icon: LucideIcon;
}

export const DOCTOR_NAV: NavItem[] = [
  { href: "/enquiries", label: "Enquiries", icon: Inbox },
];
