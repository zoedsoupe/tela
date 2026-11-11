/**
 * Adapted from Doory's gifenc declarations for the API used here.
 * Copyright (c) 2026 Siam, creator and maintainer of Doory, and the Doory contributors.
 * https://github.com/shaongitbd/doory
 * Released under the Attribution Assurance License; retain the Doory LICENSE and NOTICE.
 * gifenc itself is MIT-licensed and ships without TypeScript declarations.
 */
declare module 'gifenc' {
  export type Palette = number[][]
  export type PixelFormat = 'rgb565' | 'rgb444' | 'rgba4444'

  export interface QuantizeOptions {
    format?: PixelFormat
    oneBitAlpha?: boolean | number
    clearAlpha?: boolean
    clearAlphaThreshold?: number
    clearAlphaColor?: number
  }

  export interface WriteFrameOptions {
    transparent?: boolean
    transparentIndex?: number
    /** Milliseconds; the file stores hundredths of a second. */
    delay?: number
    palette?: Palette | null
    /** -1 = play once, 0 = forever, n = n more times. Written with the first frame only. */
    repeat?: number
    colorDepth?: number
    dispose?: number
    first?: boolean
  }

  export interface GifEncoderInstance {
    reset(): void
    finish(): void
    bytes(): Uint8Array
    bytesView(): Uint8Array
    readonly buffer: ArrayBuffer
    writeHeader(): void
    writeFrame(index: Uint8Array, width: number, height: number, options?: WriteFrameOptions): void
  }

  export function GIFEncoder(options?: { initialCapacity?: number; auto?: boolean }): GifEncoderInstance
  export function quantize(
    rgba: Uint8Array | Uint8ClampedArray,
    maxColors: number,
    options?: QuantizeOptions,
  ): Palette
  export function applyPalette(
    rgba: Uint8Array | Uint8ClampedArray,
    palette: Palette,
    format?: PixelFormat,
  ): Uint8Array
}
