import type { ShareExpiry, ShareLink, ShareRole } from "@/types/api"

export const SHARE_ROLES: readonly ShareRole[] = ['view', 'comment', 'edit']
export const SHARE_EXPIRIES: readonly ShareExpiry[] = ['never', '1d', '7d', '30d']

export function shareLinkStatus(link: Pick<ShareLink, 'is_active' | 'expires_at' | 'revoked_at'>, now = Date.now()): 'active' | 'off' | 'expired' {
  if (link.is_active) return 'active'
  const expiresAt = link.expires_at ? Date.parse(link.expires_at) : Number.NaN
  if (!link.revoked_at && Number.isFinite(expiresAt) && expiresAt <= now) return 'expired'
  return 'off'
}

export function absoluteUrl(url: string, origin: string): string {
  return new URL(url, origin).toString()
}
