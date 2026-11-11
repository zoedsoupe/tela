/**
 * Adapted from Doory's animated GIF writer.
 * Copyright (c) 2026 Siam, creator and maintainer of Doory, and the Doory contributors.
 * https://github.com/shaongitbd/doory
 * Released under the Attribution Assurance License; retain the Doory LICENSE and NOTICE.
 */

/// <reference path="./gifenc.d.ts" />
import { GIFEncoder, applyPalette, quantize } from 'gifenc'
import { framesEqual, ditherToPalette } from './gif_pixels'
import { type GifSetup, GifTooLargeError } from './gif_protocol'

export { GifTooLargeError }
export type { GifSetup }

const MAX_DELAY_CS = 65_535

export interface GifWriter {
  /** Adds a frame shown for delayCs hundredths of a second. Kept pixels are copied unless owned is true. */
  push(rgba: Uint8ClampedArray, delayCs: number, owned?: boolean): void
  /** Extends the currently held frame by delayCs hundredths of a second. */
  extend(delayCs: number): void
  /** Number of logical frames held or already written. */
  readonly frames: number
  /** Bytes currently written to the encoder, excluding any held frame. */
  readonly bytes: number
  finishBytes(): Uint8Array
  finish(): Blob
}

export function createGifWriter(setup: GifSetup): GifWriter {
  const encoder = GIFEncoder({ initialCapacity: 1 << 18 })
  const repeat = setup.loops === 0 ? 0 : setup.loops === 1 ? -1 : setup.loops - 1
  let held: Uint8ClampedArray | null = null
  let heldDelay = 0
  let written = 0
  let finishedBytes: Uint8Array | null = null

  const writeHeldFrame = (): void => {
    if (!held) return

    const rgba = new Uint8Array(held.buffer, held.byteOffset, held.byteLength)
    const palette = quantize(rgba, 256, { format: 'rgb565' })
    const indices = setup.dither
      ? ditherToPalette(held, setup.width, setup.height, palette)
      : applyPalette(rgba, palette, 'rgb565')

    let remaining = heldDelay
    do {
      const delay = Math.min(remaining, MAX_DELAY_CS)
      encoder.writeFrame(indices, setup.width, setup.height, {
        palette,
        delay: delay * 10,
        repeat,
        first: written === 0,
      })
      written += 1
      remaining -= delay
    } while (remaining > 0)

    held = null
    heldDelay = 0
  }

  const assertOpen = (): void => {
    if (finishedBytes) throw new Error('The GIF writer is already finished.')
  }

  const finishBytes = (): Uint8Array => {
    if (finishedBytes) return checkedBytes(finishedBytes, setup.maxBytes)

    writeHeldFrame()
    encoder.finish()
    finishedBytes = encoder.bytes()
    return checkedBytes(finishedBytes, setup.maxBytes)
  }

  return {
    push(rgba, delayCs, owned = false) {
      assertOpen()
      if (held && framesEqual(held, rgba)) {
        heldDelay += delayCs
        return
      }

      writeHeldFrame()
      held = owned ? rgba : new Uint8ClampedArray(rgba)
      heldDelay = delayCs
    },
    extend(delayCs) {
      assertOpen()
      if (held) heldDelay += delayCs
    },
    get frames() {
      return written + (held ? 1 : 0)
    },
    get bytes() {
      return encoder.bytesView().length
    },
    finishBytes,
    finish() {
      return new Blob([finishBytes() as Uint8Array<ArrayBuffer>], { type: 'image/gif' })
    },
  }
}

function checkedBytes(bytes: Uint8Array, maxBytes: number): Uint8Array {
  if (bytes.byteLength > maxBytes) throw new GifTooLargeError(maxBytes)
  return bytes
}
