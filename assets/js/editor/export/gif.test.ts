import { describe, expect, it } from 'vitest'
import { createGifWriter, GifTooLargeError } from './gif'

const red = () => new Uint8ClampedArray([255, 0, 0, 255])
const blue = () => new Uint8ClampedArray([0, 0, 255, 255])
const setup = { width: 1, height: 1, loops: 0, dither: false, maxBytes: 1024 * 1024 }

describe('GIF writer', () => {
  it('coalesces repeated frames and writes a valid infinitely looping GIF', () => {
    const writer = createGifWriter(setup)
    writer.push(red(), 7)
    writer.push(red(), 6)
    expect(writer.frames).toBe(1)
    const bytes = writer.finishBytes()
    expect(new TextDecoder().decode(bytes.slice(0, 6))).toBe('GIF89a')
    expect(new TextDecoder().decode(bytes)).toContain('NETSCAPE2.0')
  })

  it('stores different frames and returns an image/gif blob', () => {
    const writer = createGifWriter({ ...setup, loops: 1 })
    writer.push(red(), 10)
    writer.push(blue(), 10)
    expect(writer.frames).toBe(2)
    expect(writer.finish().type).toBe('image/gif')
  })

  it('enforces the configured byte limit', () => {
    const writer = createGifWriter({ ...setup, maxBytes: 1 })
    writer.push(red(), 10)
    writer.push(blue(), 10)
    expect(() => writer.finishBytes()).toThrow(GifTooLargeError)
  })
})
