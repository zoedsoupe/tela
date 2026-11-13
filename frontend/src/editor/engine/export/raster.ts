import type { ExportOptions } from "./registry"

export type RasterFormat = 'png' | 'jpg' | 'webp'

export const RASTER_MIME: Record<RasterFormat, string> = { png: "image/png", jpg: "image/jpeg", webp: "image/webp" }

export const isLossy = (format: RasterFormat): boolean => format !== 'png'
export const hasAlpha = (format: RasterFormat): boolean => format !== 'jpg'

let webpInBrowser: boolean | null = null

export function browserEncodes(format: RasterFormat): boolean {
  if (format === 'png' || format === 'jpg') return true
  if (webpInBrowser === null) {
    try {
      const canvas = document.createElement('canvas')
      canvas.width = canvas.height = 1
      webpInBrowser = canvas.toDataURL("image/webp").startsWith('data:image/webp')
    } catch {
      webpInBrowser = false
    }
  }
  return webpInBrowser
}

export function setBrowserWebpForTests(value: boolean | null): void {
  webpInBrowser = value
}

export type RasterOptions = Pick<ExportOptions, 'quality' | 'maxBytes' | 'transparent'>
