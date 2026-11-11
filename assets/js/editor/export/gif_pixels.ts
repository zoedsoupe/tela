/**
 * Adapted from Doory's GIF pixel utilities.
 * Copyright (c) 2026 Siam, creator and maintainer of Doory, and the Doory contributors.
 * https://github.com/shaongitbd/doory
 * Released under the Attribution Assurance License; retain the Doory LICENSE and NOTICE.
 */

/** True when two frames contain the same RGBA bytes. */
export function framesEqual(a: Uint8ClampedArray, b: Uint8ClampedArray): boolean {
  if (a.length !== b.length) return false
  for (let i = 0; i < a.length; i++) {
    if (a[i] !== b[i]) return false
  }
  return true
}

const clampByte = (value: number): number => Math.max(0, Math.min(255, value))

/** Maps RGBA pixels to palette indices with serpentine Floyd-Steinberg dithering. */
export function ditherToPalette(
  rgba: Uint8ClampedArray,
  width: number,
  height: number,
  palette: readonly (readonly number[])[],
): Uint8Array {
  const indices = new Uint8Array(width * height)
  if (palette.length === 0 || width === 0 || height === 0) return indices

  const nearest = new NearestColour(palette)
  const stride = (width + 2) * 3
  let current = new Float32Array(stride)
  let next = new Float32Array(stride)

  for (let y = 0; y < height; y++) {
    const leftToRight = (y & 1) === 0
    next.fill(0)

    for (let step = 0; step < width; step++) {
      const x = leftToRight ? step : width - 1 - step
      const pixelOffset = (y * width + x) * 4
      const errorOffset = (x + 1) * 3
      const r = clampByte(rgba[pixelOffset]! + current[errorOffset]!)
      const g = clampByte(rgba[pixelOffset + 1]! + current[errorOffset + 1]!)
      const b = clampByte(rgba[pixelOffset + 2]! + current[errorOffset + 2]!)
      const chosen = nearest.indexOf(Math.round(r), Math.round(g), Math.round(b))
      indices[y * width + x] = chosen

      const colour = palette[chosen]!
      const errorR = r - colour[0]!
      const errorG = g - colour[1]!
      const errorB = b - colour[2]!
      const ahead = leftToRight ? errorOffset + 3 : errorOffset - 3
      const behind = leftToRight ? errorOffset - 3 : errorOffset + 3

      current[ahead] = current[ahead]! + (errorR * 7) / 16
      current[ahead + 1] = current[ahead + 1]! + (errorG * 7) / 16
      current[ahead + 2] = current[ahead + 2]! + (errorB * 7) / 16
      next[behind] = next[behind]! + (errorR * 3) / 16
      next[behind + 1] = next[behind + 1]! + (errorG * 3) / 16
      next[behind + 2] = next[behind + 2]! + (errorB * 3) / 16
      next[errorOffset] = next[errorOffset]! + (errorR * 5) / 16
      next[errorOffset + 1] = next[errorOffset + 1]! + (errorG * 5) / 16
      next[errorOffset + 2] = next[errorOffset + 2]! + (errorB * 5) / 16
      next[ahead] = next[ahead]! + errorR / 16
      next[ahead + 1] = next[ahead + 1]! + errorG / 16
      next[ahead + 2] = next[ahead + 2]! + errorB / 16
    }

    const swap = current
    current = next
    next = swap
  }

  return indices
}

class NearestColour {
  private readonly cache = new Int16Array(32_768).fill(-1)
  private readonly exact = new Map<number, number>()

  constructor(private readonly palette: readonly (readonly number[])[]) {
    palette.forEach((colour, index) => {
      const key = (colour[0]! << 16) | (colour[1]! << 8) | colour[2]!
      if (!this.exact.has(key)) this.exact.set(key, index)
    })
  }

  indexOf(r: number, g: number, b: number): number {
    const exact = this.exact.get((r << 16) | (g << 8) | b)
    if (exact !== undefined) return exact

    const key = ((r >> 3) << 10) | ((g >> 3) << 5) | (b >> 3)
    const cached = this.cache[key]!
    if (cached >= 0) return cached

    const cellR = (r & 0xf8) | 4
    const cellG = (g & 0xf8) | 4
    const cellB = (b & 0xf8) | 4
    let best = 0
    let bestDistance = Number.POSITIVE_INFINITY

    for (let index = 0; index < this.palette.length; index++) {
      const colour = this.palette[index]!
      const dr = colour[0]! - cellR
      const dg = colour[1]! - cellG
      const db = colour[2]! - cellB
      const distance = 2 * dr * dr + 4 * dg * dg + 3 * db * db
      if (distance < bestDistance) {
        bestDistance = distance
        best = index
      }
    }

    this.cache[key] = best
    return best
  }
}
