/**
 * Adapted from Doory's GIF export protocol.
 * Copyright (c) 2026 Siam, creator and maintainer of Doory, and the Doory contributors.
 * https://github.com/shaongitbd/doory
 * Released under the Attribution Assurance License; retain the Doory LICENSE and NOTICE.
 */

export interface GifSetup {
  width: number
  height: number
  /** 0 = forever, 1 = once, n = n plays in all. */
  loops: number
  dither: boolean
  /** The maximum encoded file size in bytes. */
  maxBytes: number
}

export class GifTooLargeError extends Error {
  constructor(readonly limit: number) {
    super('The GIF is larger than the browser can build.')
    this.name = 'GifTooLargeError'
  }
}
