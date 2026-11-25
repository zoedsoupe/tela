import { useState } from 'react'
import { RELEASE_NOTES, RELEASE_NOTES_STORAGE_KEY } from './releaseNotes'

function shouldOpen(): boolean {
  try {
    return localStorage.getItem(RELEASE_NOTES_STORAGE_KEY) !== RELEASE_NOTES.version
  } catch {
    // Storage can be unavailable in private or restricted browsing contexts.
    return true
  }
}

/** Shows each release once per browser; reopening never changes the stored release. */
export function useWhatsNew() {
  const [open, setOpen] = useState(shouldOpen)

  function dismiss() {
    try {
      localStorage.setItem(RELEASE_NOTES_STORAGE_KEY, RELEASE_NOTES.version)
    } catch {
      // Dismissing still works when the preference cannot be persisted.
    }
    setOpen(false)
  }

  return { open, dismiss, reopen: () => setOpen(true) }
}
