import type { ShareRole } from "@/types/api"

export const SHARE_ROLES: readonly ShareRole[] = ['view', 'comment', 'edit']

export function absoluteUrl(url: string, origin: string): string {
  return new URL(url, origin).toString()
}
