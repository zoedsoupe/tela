/// <reference path="./gifenc.d.ts" />
import { createGifWriter } from './gif'
import type { GifSetup } from './gif_protocol'

type WorkerRequest =
  | { type: 'init'; setup: GifSetup }
  | { type: 'frame'; buffer: ArrayBuffer; delayCs: number }
  | { type: 'finish' }

const workerScope = self as unknown as {
  onmessage: ((event: MessageEvent<WorkerRequest>) => void) | null
  postMessage: (message: unknown, transfer?: Transferable[]) => void
}
let writer: ReturnType<typeof createGifWriter> | undefined
let maxBytes = 100 * 1024 * 1024

workerScope.onmessage = (event: MessageEvent<WorkerRequest>) => {
  try {
    const request = event.data
    if (request.type === 'init') {
      maxBytes = request.setup.maxBytes
      writer = createGifWriter(request.setup)
      workerScope.postMessage({ type: 'ready' })
      return
    }

    if (!writer) throw new Error('GIF worker has not been initialized.')
    if (request.type === 'frame') {
      const pixels = new Uint8ClampedArray(request.buffer)
      writer.push(pixels, request.delayCs, true)
      if (writer.bytes > maxBytes) throw new Error('The GIF exceeds the configured size limit.')
      workerScope.postMessage({ type: 'written' })
      return
    }

    const bytes = writer.finishBytes()
    const buffer = bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength)
    workerScope.postMessage({ type: 'done', bytes: buffer }, [buffer])
    writer = undefined
  } catch (error) {
    workerScope.postMessage({ type: 'error', message: error instanceof Error ? error.message : 'GIF encoding failed.' })
  }
}
