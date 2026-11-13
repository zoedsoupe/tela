import { useCallback } from 'react'
import { useEditor } from "../context"
import { t } from "../strings"
import { useUserFonts } from "./userFonts"

export interface FontUploadEntry {
  /** Whether the adapter offers local font uploads. */
  available: boolean
  /** Opens the upload dialog. */
  start(): void
}

export function useFontUploadEntry(): FontUploadEntry {
  const editor = useEditor()
  const { canManage } = useUserFonts()
  const start = useCallback(() => {
    if (canManage) editor.openDialog('upload-font')
    else editor.toast(t.userFonts.errors.unavailable, 'info')
  }, [canManage, editor])
  return { available: canManage, start }
}
