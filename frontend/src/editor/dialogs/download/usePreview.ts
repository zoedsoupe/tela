import { useEffect, useState } from 'react'
import type { DocPage } from "@/types/document"
import type { EditorEngine } from "../../engine/editor"
import { pageMultiplier } from "../../engine/export/formats"
import { encodeRaster } from "../../engine/export/encode"
import { type RasterFormat, hasAlpha, isLossy } from "../../engine/export/raster"
import type { ExportOptions } from "../../engine/export/registry"
import { canvasToBlob, renderPageToCanvas, safeMultiplier } from "../../engine/render"

const PREVIEW_MAX_SIDE = 1600
const GROWTH = 0.86
const ENCODE_DELAY = 120

export interface PreviewInput {
  engine: EditorEngine
  page: DocPage | null
  size: { width: number; height: number }
  format: RasterFormat | null
  options: ExportOptions
  formats: RasterFormat[]
}

export interface PreviewState {
  original: string | null
  after: string | null
  sizes: Partial<Record<RasterFormat, number>>
  bytesBefore: number | null
  approximate: Partial<Record<RasterFormat, boolean>>
  note: string | null
  failed: boolean
}

interface Drawn {
  canvas: HTMLCanvasElement
  png: Blob
  factor: number
}

const EMPTY: PreviewState = { original: null, after: null, sizes: {}, bytesBefore: null, approximate: {}, note: null, failed: false }

function objectUrl(blob: Blob): string | null {
  return typeof URL.createObjectURL === 'function' ? URL.createObjectURL(blob) : null
}

function revokeLater(url: string | null): (() => void) | undefined {
  return url ? () => URL.revokeObjectURL?.(url) : undefined
}

function onWhite(canvas: HTMLCanvasElement): HTMLCanvasElement {
  const flat = document.createElement('canvas')
  flat.width = canvas.width
  flat.height = canvas.height
  const context = flat.getContext('2d')
  if (!context) return canvas
  context.fillStyle = "#ffffff"
  context.fillRect(0, 0, flat.width, flat.height)
  context.drawImage(canvas, 0, 0)
  return flat
}

/** Browser-only image preview and file-size estimate. */
export function usePreview({ engine, page, size, format, options, formats }: PreviewInput): PreviewState {
  const [state, setState] = useState<PreviewState>(EMPTY)
  const [drawn, setDrawn] = useState<Drawn | null>(null)
  const width = size.width
  const height = size.height
  const output = safeMultiplier(width, height, pageMultiplier(options, { width, height }))
  const scale = Math.min(output, PREVIEW_MAX_SIDE / Math.max(width, height))
  const transparent = options.transparent && (format === null || hasAlpha(format))
  const formatKey = formats.join(',')

  useEffect(() => revokeLater(state.original), [state.original])
  useEffect(() => revokeLater(state.after), [state.after])

  useEffect(() => {
    if (!page) return
    let active = true
    const timer = setTimeout(() => {
      renderPageToCanvas(page, { width, height }, engine.loadContext, { multiplier: scale, transparent })
        .then(async (canvas) => {
          const png = await canvasToBlob(canvas, "image/png")
          if (!active) return
          const original = objectUrl(png)
          const factor = Math.max(1, (output * output) / (scale * scale))
          setDrawn({ canvas, png, factor })
          setState((current) => ({ ...current, original, failed: false }))
        })
        .catch(() => active && setState((current) => ({ ...current, failed: true })))
    }, ENCODE_DELAY)
    return () => {
      active = false
      clearTimeout(timer)
    }
  }, [engine, page, width, height, scale, output, transparent])

  const quality = options.quality
  const maxBytes = options.maxBytes
  useEffect(() => {
    if (!drawn) return
    let active = true
    const run = async (): Promise<void> => {
      const sizes: Partial<Record<RasterFormat, number>> = {}
      const approximate: Partial<Record<RasterFormat, boolean>> = {}
      const factor = drawn.factor
      let after: Blob | null = null
      let bytesBefore: number | null = null
      let note: string | null = null
      const selectedFormats = formatKey ? formatKey.split(',') as RasterFormat[] : []
      for (const candidate of selectedFormats) {
        if (!active) return
        const source = candidate === 'jpg' ? onWhite(drawn.canvas) : drawn.canvas
        const share = maxBytes ? Math.max(1000, Math.round(maxBytes / Math.pow(factor, GROWTH))) : undefined
        const result = await encodeRaster(source, candidate, { quality, maxBytes: isLossy(candidate) ? share : undefined, transparent })
        sizes[candidate] = Math.round(result.blob.size * Math.pow(factor, GROWTH))
        approximate[candidate] = factor > 1.01
        if (candidate === format) {
          after = result.blob
          bytesBefore = Math.round(result.bytesBefore * Math.pow(factor, GROWTH))
          note = result.note ?? null
        }
      }
      if (!active) return
      setState((current) => ({ ...current, after: after ? objectUrl(after) : null, sizes, bytesBefore, approximate, note }))
    }
    const timer = setTimeout(() => void run().catch(() => active && setState((current) => ({ ...current, failed: true }))), ENCODE_DELAY)
    return () => {
      active = false
      clearTimeout(timer)
    }
  }, [drawn, format, formatKey, quality, maxBytes, transparent])

  return state
}
