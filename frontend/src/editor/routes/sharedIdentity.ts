import { safeGetItem, safeSetItem } from "@/lib/storage"

const KEY_PREFIX = 'tela.sharedGuestName.'
const MAX_NAME_LENGTH = 120

export function normalizeGuestName(value: string): string | null {
  const name = value.trim()
  return name.length > 0 && name.length <= MAX_NAME_LENGTH ? name : null
}

export function readGuestName(token: string): string | null {
  const stored = safeGetItem(KEY_PREFIX + token)
  return stored === null ? null : normalizeGuestName(stored)
}

/** Persists a per-link display name when storage is available; the returned name also works for this session. */
export function saveGuestName(token: string, value: string): string | null {
  const name = normalizeGuestName(value)
  if (name) safeSetItem(KEY_PREFIX + token, name)
  return name
}
