import { describe, expect, it, vi } from 'vitest'
import type { TelaDocument } from '../document/types'
import { ExportCancelledError, GifDurationError, normalizeGifOptions, planGifFrames, runGifExport } from './gif_export'

const document: TelaDocument = {
  schemaVersion: 1,
  width: 400,
  height: 200,
  pages: [{ id: 'one', background: { type: 'solid', color: '#fff' }, objects: [], durationSec: 1 }],
}

describe('GIF export contract', () => {
  it('normalizes supported dimensions, fps, looping, and page scope', () => {
    expect(normalizeGifOptions(document, { scope: 'current', pageId: 'one', longestSide: 480, fps: 15, loops: 0 })).toEqual({
      width: 480,
      height: 240,
      fps: 15,
      loops: 0,
      dither: false,
      maxBytes: 100 * 1024 * 1024,
    })
    expect(() => normalizeGifOptions(document, { scope: 'all', longestSide: 999, fps: 15, loops: 0 })).toThrow()
    expect(() => normalizeGifOptions(document, { scope: 'all', longestSide: 480, fps: 12, loops: 0 })).toThrow()
  })

  it('uses integer frame indexes and exact delays without accumulated drift', () => {
    const frames = planGifFrames(document, { scope: 'all', longestSide: 480, fps: 15, loops: 0 })
    expect(frames).toHaveLength(15)
    expect(frames[0]).toEqual({ index: 0, timeMs: 0, delayCs: 7, pageIndex: 0 })
    expect(frames.at(-1)).toEqual({ index: 14, timeMs: 14000 / 15, delayCs: 6, pageIndex: 0 })
    expect(frames.reduce((total, frame) => total + frame.delayCs, 0)).toBe(100)
  })

  it('rejects timelines longer than thirty seconds before rendering', () => {
    const longDocument = { ...document, pages: [{ ...document.pages[0], durationSec: 31 }] }
    expect(() => planGifFrames(longDocument, { scope: 'all', longestSide: 480, fps: 15, loops: 0 })).toThrow(GifDurationError)
  })

  it('renders sequentially, reports progress, and stops promptly on cancellation', async () => {
    const abort = new AbortController()
    const write = vi.fn(async () => abort.abort())
    const render = vi.fn(async () => new Uint8ClampedArray(4))
    const progress = vi.fn()

    await expect(runGifExport({
      document,
      options: { scope: 'all', longestSide: 240, fps: 10, loops: 1 },
      render,
      write,
      onProgress: progress,
      signal: abort.signal,
    })).rejects.toBeInstanceOf(ExportCancelledError)
    expect(render).toHaveBeenCalledTimes(1)
    expect(write).toHaveBeenCalledTimes(1)
    expect(progress).toHaveBeenCalledWith({ rendered: 1, total: 10 })
  })
})
