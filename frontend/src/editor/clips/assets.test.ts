import { describe, expect, it, vi } from 'vitest'
import type { AssetRef, VideoAssetInfo, VideoService } from '@/types/adapter'
import { looksLikeVideo, videoFilesFrom, videoUploads } from './assets'

const metadata: VideoAssetInfo = { posterUrl: 'data:image/png;base64,AA==', durationMs: 1000, fps: 30, hasAudio: false, width: 640, height: 360 }
const ref: AssetRef = { id: 'video-1', url: 'idb://00000000-0000-0000-0000-000000000001', thumbUrl: metadata.posterUrl, width: 640, height: 360, name: 'clip.mp4', kind: 'video', video: metadata }

describe('local video uploads', () => {
  it('recognises browser video files by MIME type or extension', () => {
    expect(looksLikeVideo(new File(['video'], 'clip.mp4'))).toBe(true)
    expect(looksLikeVideo(new File(['image'], 'photo.png', { type: 'image/png' }))).toBe(false)
  })

  it('filters dropped files to videos', () => {
    const transfer = { files: [new File(['video'], 'clip.webm'), new File(['image'], 'image.png')] } as unknown as DataTransfer
    expect(videoFilesFrom(transfer).map((file) => file.name)).toEqual(['clip.webm'])
  })

  it('passes browser-probed metadata to the local adapter and tracks upload progress', async () => {
    const upload = vi.fn(async (_file: File, _metadata: VideoAssetInfo, options) => {
      options?.onProgress?.(1)
      return ref
    })
    const service: VideoService = { list: async () => ({ count: 0, next: null, previous: null, results: [] }), upload }
    const uploads = videoUploads(service)
    const seen: number[] = []
    const stop = uploads.subscribe(() => seen.push(...uploads.getSnapshot().map((item) => item.fraction)))
    await expect(uploads.send(new File(['video'], 'clip.mp4', { type: 'video/mp4' }), metadata)).resolves.toEqual(ref)
    expect(upload).toHaveBeenCalledWith(expect.any(File), metadata, expect.objectContaining({ onProgress: expect.any(Function) }))
    expect(seen).toContain(1)
    expect(uploads.getSnapshot()).toEqual([])
    stop()
  })
})
