import { afterEach, describe, expect, it } from 'vitest'
import { DEFAULT_EXPORT_OPTIONS } from './registry'
import { encodeRaster } from './encode'
import { setBrowserWebpForTests } from './raster'

function fakeCanvas({ webp = true, bytes = (_type: string, quality = 1) => Math.round(1000 * quality) + 100 } = {}): HTMLCanvasElement {
  return {
    width: 10,
    height: 10,
    toBlob(callback: BlobCallback, type = 'image/png', quality?: number) {
      const actual = type === 'image/webp' && !webp ? 'image/png' : type
      callback(new Blob(['x'.repeat(bytes(actual, quality))], { type: actual }))
    },
  } as unknown as HTMLCanvasElement
}

afterEach(() => setBrowserWebpForTests(null))

describe('browser raster encoding', () => {
  it('encodes JPEG in the browser', async () => {
    const result = await encodeRaster(fakeCanvas(), 'jpg', DEFAULT_EXPORT_OPTIONS)
    expect(result.format).toBe('jpg')
    expect(result.blob.type).toBe('image/jpeg')
    expect(result.optimized).toBe(false)
  })

  it('uses PNG when the browser cannot encode WebP', async () => {
    setBrowserWebpForTests(false)
    const result = await encodeRaster(fakeCanvas({ webp: false }), 'webp', DEFAULT_EXPORT_OPTIONS)
    expect(result.format).toBe('png')
    expect(result.blob.type).toBe('image/png')
    expect(result.note).toContain('PNG')
  })

  it('fits a lossy image under its local byte limit by lowering quality', async () => {
    const canvas = fakeCanvas({ bytes: (_type, quality = 1) => Math.round(2000 * quality) })
    const result = await encodeRaster(canvas, 'jpg', { ...DEFAULT_EXPORT_OPTIONS, quality: 0.92, maxBytes: 1000 })
    expect(result.blob.size).toBeLessThanOrEqual(1000)
    expect(result.blob.size).toBeGreaterThan(900)
  })
})
