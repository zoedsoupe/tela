/** Encodes a rendered page using browser canvas APIs only. */
import { canvasToBlob } from "../render"
import { type RasterFormat, type RasterOptions, RASTER_MIME, browserEncodes, isLossy } from "./raster"

export interface EncodedRaster {
  blob: Blob
  format: RasterFormat
  bytesBefore: number
  optimized: false
  note?: string
}

const FIT_STEPS = 7

async function fitInBrowser(canvas: HTMLCanvasElement, mime: string, maxBytes: number, quality: number): Promise<Blob> {
  const first = await canvasToBlob(canvas, mime, quality)
  if (first.size <= maxBytes) return first
  let low = 0.05
  let high = quality
  let best: Blob | null = null
  for (let index = 0; index < FIT_STEPS; index++) {
    const middle = (low + high) / 2
    const blob = await canvasToBlob(canvas, mime, middle)
    if (blob.size <= maxBytes) {
      best = blob
      low = middle
    } else high = middle
  }
  return best ?? canvasToBlob(canvas, mime, 0.05)
}

export async function encodeRaster(canvas: HTMLCanvasElement, format: RasterFormat, options: RasterOptions): Promise<EncodedRaster> {
  if (!browserEncodes(format)) {
    const blob = await canvasToBlob(canvas, RASTER_MIME.png)
    return { blob, format: 'png', bytesBefore: blob.size, optimized: false, note: "Este navegador não exporta WebP; o arquivo foi salvo como PNG." }
  }
  const mime = RASTER_MIME[format]
  const blob = isLossy(format) && options.maxBytes
    ? await fitInBrowser(canvas, mime, options.maxBytes, options.quality)
    : await canvasToBlob(canvas, mime, isLossy(format) ? options.quality : undefined)
  const actualFormat = blob.type === mime || !blob.type ? format : 'png'
  return { blob, format: actualFormat, bytesBefore: blob.size, optimized: false }
}
