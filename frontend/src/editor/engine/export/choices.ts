/** Browser export defaults suggested by a document's size preset and saved per browser. */
import { type SizePreset, getSizePresets } from "@/lib/sizePresets"
import { safeGetItem, safeSetItem } from "@/lib/storage"
import type { EditorEngine } from "../editor"
import { getPageSize } from "../pageSizes"
import { DEFAULT_EXPORT_OPTIONS, type ExportOptions, QUALITY_PRESETS, type QualityPreset, exportFormats } from "./registry"

export interface ExportChoice {
  formatId: string
  options: ExportOptions
}

export function designPreset(engine: EditorEngine): SizePreset | null {
  const preset = getSizePresets().byId.get(engine.state.doc.meta?.presetId ?? '')
  if (!preset) return null
  const size = getPageSize(engine.state.doc, engine.state.activePageId)
  return preset.width === size.width && preset.height === size.height ? preset : null
}

export function formatAvailable(engine: EditorEngine, id: string): boolean {
  const format = exportFormats.get(id)
  return !!format && (!format.available || format.available(engine))
}

const PICTURES = ['jpg', 'png', 'webp']

export function suggestionFor(engine: EditorEngine, preset: SizePreset): ExportChoice {
  if (preset.unit !== 'px') return { formatId: 'pdf', options: DEFAULT_EXPORT_OPTIONS }
  const formatId = preset.formats?.map((format) => (format === 'jpeg' ? 'jpg' : format)).find((format) => PICTURES.includes(format) && formatAvailable(engine, format)) ?? 'jpg'
  return {
    formatId,
    options: { ...DEFAULT_EXPORT_OPTIONS, size: '1x', quality: QUALITY_PRESETS.balanced / 100, qualityPreset: 'balanced' },
  }
}

export function describeChoice(choice: ExportChoice): string {
  const format = exportFormats.get(choice.formatId)
  const parts = [format?.label ?? choice.formatId.toUpperCase()]
  if (format?.controls.scale) parts.push(choice.options.size?.trim() || `${choice.options.scale}x`)
  return parts.join(' · ')
}

const LAST_KEY = 'tela-export-last'
const PRESETS = Object.keys(QUALITY_PRESETS) as QualityPreset[]
const num = (value: unknown, min: number, max: number): number | undefined => typeof value === 'number' && Number.isFinite(value) && value >= min && value <= max ? value : undefined
const text = (value: unknown, max = 40): string | undefined => typeof value === 'string' && value.length <= max ? value : undefined
const flag = (value: unknown): boolean | undefined => typeof value === 'boolean' ? value : undefined

export function loadLastExport(_engine?: EditorEngine): ExportChoice | null {
  try {
    const raw = JSON.parse(safeGetItem(LAST_KEY) ?? 'null') as { formatId?: unknown; options?: Record<string, unknown> } | null
    const formatId = text(raw?.formatId, 20)
    if (!formatId || !exportFormats.get(formatId)) return null
    const values = raw?.options ?? {}
    const options: ExportOptions = {
      ...DEFAULT_EXPORT_OPTIONS,
      scale: num(values.scale, 0.1, 4) ?? 1,
      quality: num(values.quality, 0.01, 1) ?? DEFAULT_EXPORT_OPTIONS.quality,
      transparent: flag(values.transparent) ?? false,
      bleedMm: num(values.bleedMm, 0, 10) ?? 0,
      cropMarks: flag(values.cropMarks) ?? false,
    }
    const size = text(values.size, 12)
    if (size) options.size = size
    if (PRESETS.includes(values.qualityPreset as QualityPreset)) options.qualityPreset = values.qualityPreset as QualityPreset
    const maxBytes = num(values.maxBytes, 1000, 1e9)
    if (maxBytes) options.maxBytes = maxBytes
    return { formatId, options }
  } catch {
    return null
  }
}

export function saveLastExport(choice: ExportChoice): void {
  const options: Partial<ExportOptions> = { ...choice.options }
  delete options.video
  safeSetItem(LAST_KEY, JSON.stringify({ formatId: choice.formatId, options }))
}
