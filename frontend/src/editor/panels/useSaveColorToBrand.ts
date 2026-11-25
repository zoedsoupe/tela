import { useCallback } from 'react'
import { useEditor, useEditorState } from "../context"
import { t } from "../strings"
import { MAX_BRAND_COLORS, brandColorHex, emptyKit, pickKit, withColor } from "./brandOps"
import { setBrandPalette } from "./brandPalette"

/** Returns the explicit action that promotes a solid colour to the active Brand Kit, when available. */
export function useSaveColorToBrand(): ((color: string) => Promise<void>) | null {
  const editor = useEditor()
  const readOnly = useEditorState((state) => state.readOnly)
  const brand = editor.adapter.services.brand
  const save = useCallback(async (color: string): Promise<void> => {
    if (!brand) return
    const hex = brandColorHex(color)
    if (!hex) {
      editor.toast(t.brand.colorTransparent, 'error')
      return
    }
    try {
      const kits = await brand.list()
      const current = pickKit(kits) ?? emptyKit(t.brand.designKit, kits.length === 0)
      if (current.colors.some((entry) => entry.hex.toLowerCase() === hex.toLowerCase())) {
        editor.toast(t.brand.colorAlreadySaved)
        return
      }
      if (current.colors.length >= MAX_BRAND_COLORS) {
        editor.toast(t.brand.colorLimit(MAX_BRAND_COLORS), 'error')
        return
      }
      const saved = await brand.save(withColor(current, hex))
      setBrandPalette(saved)
      editor.toast(t.brand.colorSaved(saved.name), 'success')
    } catch {
      editor.toast(t.brand.saveFailed, 'error')
    }
  }, [brand, editor])
  return brand && !readOnly ? save : null
}
