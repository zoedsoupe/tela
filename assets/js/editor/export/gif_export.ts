import type { TelaDocument, TelaPage } from '../document/types'
import { buildTimeline, frameCount } from '../animation/timeline'
import { FrameRenderer } from '../animation/frame_renderer'
import { transitionPresets } from '../animation/presets'
import type { GifSetup } from './gif_protocol'
import { downloadBlob, sanitizeExportFilename } from './download'

export { downloadBlob, sanitizeExportFilename } from './download'

export type GifExportScope = 'current' | 'all'

export interface GifExportOptions {
  scope: GifExportScope
  pageId?: string
  longestSide?: number
  fps?: number
  loops?: number
  dither?: boolean
  maxBytes?: number
}

export interface NormalizedGifOptions extends GifSetup {
  fps: 10 | 15
}

export interface GifFrame {
  index: number
  timeMs: number
  delayCs: number
  pageIndex: number
}

export interface GifExportProgress {
  rendered: number
  total: number
}

export class ExportCancelledError extends Error {
  constructor() {
    super('The export was cancelled.')
    this.name = 'ExportCancelledError'
  }
}

export class GifDurationError extends Error {
  constructor(readonly durationMs: number) {
    super('GIF exports cannot be longer than 30 seconds.')
    this.name = 'GifDurationError'
  }
}

const MAX_DURATION_MS = 30_000
const DEFAULT_MAX_BYTES = 100 * 1024 * 1024
const WARNING_BYTES = 25 * 1024 * 1024
type GifDocumentInput = Omit<TelaDocument, 'pages'> & { pages: Array<Partial<TelaPage>> }

function selectedPages(document: TelaDocument, options: GifExportOptions): { document: TelaDocument; indexes: number[] } {
  if (options.scope === 'all') {
    return { document, indexes: document.pages.map((_page, index) => index) }
  }

  if (options.scope !== 'current' || !options.pageId) throw new TypeError('A pageId is required for current-page GIF export.')
  const pageIndex = document.pages.findIndex((page) => page.id === options.pageId)
  if (pageIndex < 0) throw new RangeError(`Unknown page: ${options.pageId}`)
  const page = document.pages[pageIndex]!
  return { document: { ...document, pages: [{ ...page, transition: undefined }] }, indexes: [pageIndex] }
}

export function normalizeGifOptions(document: TelaDocument, options: GifExportOptions): NormalizedGifOptions {
  if (!document.pages.length || !Number.isFinite(document.width) || !Number.isFinite(document.height) || document.width <= 0 || document.height <= 0) {
    throw new TypeError('GIF export requires a document with pages and positive dimensions.')
  }
  const longestSide = options.longestSide ?? 480
  const fps = options.fps ?? 15
  const loops = options.loops ?? 0
  const maxBytes = options.maxBytes ?? DEFAULT_MAX_BYTES
  if (![240, 360, 480, 720].includes(longestSide)) throw new RangeError('Unsupported GIF size.')
  if (fps !== 10 && fps !== 15) throw new RangeError('Unsupported GIF frame rate.')
  if (loops !== 0 && loops !== 1) throw new RangeError('Unsupported GIF loop count.')
  if (typeof options.dither !== 'undefined' && typeof options.dither !== 'boolean') throw new TypeError('dither must be a boolean.')
  if (!Number.isSafeInteger(maxBytes) || maxBytes <= 0) throw new RangeError('maxBytes must be a positive safe integer.')
  selectedPages(document, options)

  const scale = longestSide / Math.max(document.width, document.height)
  const width = Math.max(1, Math.round(document.width * scale))
  const height = Math.max(1, Math.round(document.height * scale))
  return { width, height, fps, loops, dither: options.dither ?? false, maxBytes }
}

function timelineFor(document: TelaDocument, options: GifExportOptions): { timeline: ReturnType<typeof buildTimeline>; indexes: number[] } {
  const selected = selectedPages(document, options)
  return { timeline: buildTimeline(selected.document), indexes: selected.indexes }
}

export function planGifFrames(document: GifDocumentInput, options: GifExportOptions): GifFrame[] {
  const validDocument = document as TelaDocument
  const normalized = normalizeGifOptions(validDocument, options)
  const { timeline, indexes } = timelineFor(validDocument, options)
  if (timeline.totalMs > MAX_DURATION_MS) throw new GifDurationError(timeline.totalMs)
  const fps = normalized.fps
  const count = frameCount(timeline.totalMs, fps)
  const totalDelayCs = Math.round(timeline.totalMs / 10)
  const baseDelayCs = Math.floor(totalDelayCs / count)
  const extraDelayCs = totalDelayCs - baseDelayCs * count
  const ceilBoundary = (boundary: number) => Math.ceil((boundary * extraDelayCs) / count)
  return Array.from({ length: count }, (_unused, index) => {
    const timeMs = (index * 1000) / fps
    const segment = timeline.segments.find((candidate) => timeMs >= candidate.startMs && timeMs < candidate.endMs)
    const localPageIndex = segment?.pageIndex ?? Math.max(0, timeline.segments.at(-1)?.pageIndex ?? 0)
    return {
      index,
      timeMs,
      delayCs: baseDelayCs + ceilBoundary(index + 1) - ceilBoundary(index),
      pageIndex: indexes[localPageIndex] ?? 0,
    }
  })
}

export interface RunGifExportArgs<TFrame = Uint8ClampedArray, TResult = unknown> {
  document: TelaDocument
  options: GifExportOptions
  render: (frame: GifFrame) => TFrame | Promise<TFrame>
  write: (frame: TFrame, delayCs: number, metadata: GifFrame) => TResult | Promise<TResult>
  onProgress?: (progress: GifExportProgress) => void
  signal?: AbortSignal
}

export async function runGifExport<TFrame = Uint8ClampedArray, TResult = unknown>(
  args: RunGifExportArgs<TFrame, TResult>,
): Promise<TResult | undefined> {
  const frames = planGifFrames(args.document, args.options)
  let result: TResult | undefined
  for (const frame of frames) {
    if (args.signal?.aborted) throw new ExportCancelledError()
    const pixels = await args.render(frame)
    if (args.signal?.aborted) throw new ExportCancelledError()
    result = await args.write(pixels, frame.delayCs, frame)
    args.onProgress?.({ rendered: frame.index + 1, total: frames.length })
    if (args.signal?.aborted) throw new ExportCancelledError()
  }
  return result
}

export function estimateGifSize(width: number, height: number, durationMs: number, fps: number): number {
  if (![width, height, durationMs, fps].every(Number.isFinite) || width <= 0 || height <= 0 || durationMs <= 0 || fps <= 0) return 0
  // Approximation includes a conservative 1.5 bytes per pixel per frame plus container overhead.
  return Math.ceil(width * height * (durationMs * fps / 1000) * 1.5 + 1024)
}

export function shouldWarnGifSize(estimatedBytes: number): boolean {
  return estimatedBytes > WARNING_BYTES
}

interface WorkerResponse {
  type: 'ready' | 'written' | 'done' | 'error'
  bytes?: ArrayBuffer
  message?: string
}

function workerMessage(
  worker: Worker,
  message: unknown,
  transfer: Transferable[] = [],
  signal?: AbortSignal,
): Promise<WorkerResponse> {
  return new Promise((resolve, reject) => {
    if (signal?.aborted) {
      reject(new ExportCancelledError())
      return
    }
    const onMessage = (event: MessageEvent<WorkerResponse>) => {
      if (event.data.type === 'error') {
        cleanup()
        reject(new Error(event.data.message ?? 'GIF encoding failed.'))
      } else {
        cleanup()
        resolve(event.data)
      }
    }
    const onError = (event: ErrorEvent) => {
      cleanup()
      reject(event.error ?? new Error(event.message))
    }
    const onAbort = () => {
      cleanup()
      reject(new ExportCancelledError())
    }
    const cleanup = () => {
      worker.removeEventListener('message', onMessage)
      worker.removeEventListener('error', onError)
      signal?.removeEventListener('abort', onAbort)
    }
    worker.addEventListener('message', onMessage)
    worker.addEventListener('error', onError)
    signal?.addEventListener('abort', onAbort, { once: true })
    worker.postMessage(message, transfer)
  })
}

function createFrameRenderer(document: TelaDocument, width: number, height: number): FrameRenderer {
  const element = globalThis.document.createElement('canvas')
  const renderer = new FrameRenderer(element, document)
  renderer.canvas.setDimensions({ width, height })
  renderer.canvas.setViewportTransform([width / document.width, 0, 0, height / document.height, 0, 0])
  return renderer
}

async function createBrowserFrameRenderer(document: TelaDocument, width: number, height: number): Promise<{
  render: (frame: GifFrame) => Promise<Uint8ClampedArray>
  dispose: () => Promise<void>
}> {
  const current = createFrameRenderer(document, width, height)
  const outgoing = createFrameRenderer(document, width, height)
  const incoming = createFrameRenderer(document, width, height)
  const composite = globalThis.document.createElement('canvas')
  composite.width = width
  composite.height = height
  const context = composite.getContext('2d', { willReadFrequently: true })
  if (!context) throw new Error('A 2D canvas context is required for GIF export.')
  const timeline = buildTimeline(document)
  return {
    async render(frame) {
      const segment = timeline.segments.find((candidate) => frame.timeMs >= candidate.startMs && frame.timeMs < candidate.endMs)
      const index = segment?.pageIndex ?? frame.pageIndex
      if (segment?.kind !== 'transition' || index < 1) {
        const page = document.pages[index]!
        const localStart = timeline.segments.find((candidate) => candidate.kind === 'page' && candidate.pageIndex === index)?.startMs ?? 0
        await current.render(page, frame.timeMs - localStart)
        context.clearRect(0, 0, width, height)
        context.drawImage(current.canvas.lowerCanvasEl, 0, 0)
      } else {
        const nextPage = document.pages[index]!
        const priorPage = document.pages[index - 1]!
        const progress = Math.min(1, Math.max(0, (frame.timeMs - segment.startMs) / segment.durationMs))
        const previousSegment = timeline.segments.find((candidate) => candidate.kind === 'page' && candidate.pageIndex === index - 1)
        await Promise.all([
          outgoing.render(priorPage, previousSegment?.durationMs ?? 0),
          incoming.render(nextPage, 0),
        ])
        context.clearRect(0, 0, width, height)
        context.drawImage(outgoing.canvas.lowerCanvasEl, 0, 0)
        const transition = nextPage.transition
        const ease = (value: number) => {
          switch (transition?.easing) {
            case 'ease-in': return value * value
            case 'ease-out': return 1 - (1 - value) * (1 - value)
            case 'ease-in-out': return value < 0.5 ? 2 * value * value : 1 - 2 * (1 - value) * (1 - value)
            case 'spring': return Math.min(1, Math.max(0, 1 - Math.exp(-6 * value) * Math.cos(10 * value)))
            default: return value
          }
        }
        const effect = transition && transitionPresets.get(transition.preset)?.effect(ease(progress), { direction: transition.direction })
        const easedProgress = ease(progress)
        if (transition?.preset === 'slide') {
          const direction = transition.direction ?? 'right'
          const offsets: Record<string, [number, number]> = {
            left: [-1, 0], right: [1, 0], up: [0, -1], down: [0, 1], in: [1, 0], out: [-1, 0],
          }
          const [x, y] = offsets[direction] ?? offsets.right!
          context.save()
          context.drawImage(incoming.canvas.lowerCanvasEl, x * (1 - easedProgress) * width, y * (1 - easedProgress) * height)
          context.restore()
        } else if (transition?.preset === 'wipe') {
          context.save()
          const clipProgress = effect?.clipProgress ?? ease(progress)
          context.beginPath()
          if (transition.direction === 'left') context.rect(width * (1 - clipProgress), 0, width * clipProgress, height)
          else if (transition.direction === 'up') context.rect(0, height * (1 - clipProgress), width, height * clipProgress)
          else if (transition.direction === 'down') context.rect(0, 0, width, height * clipProgress)
          else context.rect(0, 0, width * clipProgress, height)
          context.clip()
          context.drawImage(incoming.canvas.lowerCanvasEl, 0, 0)
          context.restore()
        } else {
          context.globalAlpha = effect?.opacity ?? progress
          context.drawImage(incoming.canvas.lowerCanvasEl, 0, 0)
          context.globalAlpha = 1
        }
      }
      return new Uint8ClampedArray(context.getImageData(0, 0, width, height).data)
    },
    async dispose() {
      await Promise.all([current.dispose(), outgoing.dispose(), incoming.dispose()])
      composite.width = 0
      composite.height = 0
    },
  }
}

export interface BrowserGifExportOptions extends GifExportOptions {
  onProgress?: (progress: GifExportProgress) => void
  signal?: AbortSignal
  render?: (frame: GifFrame, size: Pick<NormalizedGifOptions, 'width' | 'height'>) => Uint8ClampedArray | Promise<Uint8ClampedArray>
}

/** Browser entry point: renders on the main thread and keeps palette/LZW encoding in a lazy worker. */
export async function exportGif(document: TelaDocument, options: BrowserGifExportOptions): Promise<Blob> {
  const normalized = normalizeGifOptions(document, options)
  const frames = planGifFrames(document, options)
  if (!frames.length) throw new RangeError('The selected GIF timeline has no frames.')
  if (options.signal?.aborted) throw new ExportCancelledError()

  const worker = new Worker(new URL('./gif_export.worker.ts', import.meta.url), { type: 'module' })
  let renderer: Awaited<ReturnType<typeof createBrowserFrameRenderer>> | undefined
  const abort = () => worker.terminate()
  options.signal?.addEventListener('abort', abort, { once: true })
  try {
    const ready = workerMessage(worker, { type: 'init', setup: normalized }, [], options.signal)
    const exportDocument = selectedPages(document, options).document
    renderer = options.render ? undefined : await createBrowserFrameRenderer(exportDocument, normalized.width, normalized.height)
    const readyResponse = await ready
    if (readyResponse.type !== 'ready') throw new Error('GIF worker failed to initialize.')
    await runGifExport({
      document,
      options,
      signal: options.signal,
      onProgress: options.onProgress,
      render: (frame) => options.render
        ? options.render(frame, normalized)
        : renderer!.render(frame),
      write: async (pixels, delayCs, frame) => {
        const pixelsCopy = new Uint8ClampedArray(pixels)
        const reply = workerMessage(worker, {
          type: 'frame',
          buffer: pixelsCopy.buffer,
          delayCs,
          index: frame.index,
        }, [pixelsCopy.buffer], options.signal)
        if (options.signal?.aborted) throw new ExportCancelledError()
        await reply
      },
    })
    if (options.signal?.aborted) throw new ExportCancelledError()
    const result = await workerMessage(worker, { type: 'finish' }, [], options.signal)
    if (result.type !== 'done' || !result.bytes) throw new Error('GIF worker did not return an encoded file.')
    if (result.bytes.byteLength > normalized.maxBytes) throw new Error('The GIF exceeds the configured size limit.')
    return new Blob([result.bytes], { type: 'image/gif' })
  } finally {
    options.signal?.removeEventListener('abort', abort)
    worker.terminate()
    await renderer?.dispose()
  }
}
