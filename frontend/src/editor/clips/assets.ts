/** Browser-side video probing and local upload progress. No conversion or server jobs are involved. */
import type { AssetRef, VideoAssetInfo, VideoService } from "@/types/adapter"

export const VIDEO_ACCEPT = "video/*,.mp4,.m4v,.mov,.webm,.mkv,.avi,.3gp"

const VIDEO_EXTENSIONS = /\.(mp4|m4v|mov|webm|mkv|avi|3gp)$/i

export function looksLikeVideo(file: File): boolean {
  return file.type.startsWith("video/") || VIDEO_EXTENSIONS.test(file.name)
}

export function videoFilesFrom(data: DataTransfer | null): File[] {
  return data ? [...data.files].filter(looksLikeVideo) : []
}

function waitFor(target: HTMLVideoElement, event: 'loadedmetadata' | 'loadeddata'): Promise<void> {
  return new Promise((resolve, reject) => {
    const ready = (): boolean => event === 'loadedmetadata'
      ? target.readyState >= HTMLMediaElement.HAVE_METADATA
      : event === 'loadeddata' && target.readyState >= HTMLMediaElement.HAVE_CURRENT_DATA
    if (ready()) return resolve()
    const cleanup = (): void => {
      target.removeEventListener(event, done)
      target.removeEventListener('error', failed)
      target.removeEventListener("abort", failed)
    }
    const done = (): void => {
      cleanup()
      resolve()
    }
    const failed = (): void => {
      cleanup()
      reject(new Error("Este vídeo não pode ser reproduzido neste navegador."))
    }
    target.addEventListener(event, done, { once: true })
    target.addEventListener('error', failed, { once: true })
    target.addEventListener("abort", failed, { once: true })
  })
}

/** Rejects unsupported codecs before the file is stored. The poster is a browser-generated data URL. */
export async function probeVideo(file: File): Promise<VideoAssetInfo> {
  if (!looksLikeVideo(file)) throw new Error("Selecione um arquivo de vídeo.")
  const source = URL.createObjectURL(file)
  const video = document.createElement('video')
  video.preload = 'auto'
  video.muted = true
  video.playsInline = true
  video.src = source
  try {
    await waitFor(video, 'loadedmetadata')
    if (!Number.isFinite(video.duration) || video.duration <= 0 || video.videoWidth <= 0 || video.videoHeight <= 0) {
      throw new Error("Este vídeo não contém metadados compatíveis com o navegador.")
    }
    await waitFor(video, 'loadeddata')
    const canvas = document.createElement('canvas')
    canvas.width = video.videoWidth
    canvas.height = video.videoHeight
    const context = canvas.getContext('2d')
    if (!context) throw new Error("Não foi possível ler um quadro deste vídeo.")
    context.drawImage(video, 0, 0, canvas.width, canvas.height)
    let posterUrl = ''
    try {
      posterUrl = canvas.toDataURL("image/webp", 0.82)
    } catch {
      posterUrl = canvas.toDataURL("image/png")
    }
    const tracks = (video as HTMLVideoElement & { audioTracks?: { length: number } }).audioTracks
    const audioBytes = (video as HTMLVideoElement & { webkitAudioDecodedByteCount?: number }).webkitAudioDecodedByteCount
    return {
      posterUrl,
      durationMs: Math.round(video.duration * 1000),
      fps: 30,
      hasAudio: tracks ? tracks.length > 0 : (audioBytes ?? 0) > 0,
      width: video.videoWidth,
      height: video.videoHeight,
    }
  } finally {
    video.removeAttribute('src')
    video.load()
    URL.revokeObjectURL(source)
  }
}

export interface VideoSending {
  key: string
  name: string
  fraction: number
}

export class VideoUploads {
  private items: readonly VideoSending[] = []
  private readonly listeners = new Set<() => void>()
  private count = 0

  constructor(private readonly service: VideoService) {}

  subscribe = (listener: () => void): (() => void) => {
    this.listeners.add(listener)
    return () => this.listeners.delete(listener)
  }

  getSnapshot = (): readonly VideoSending[] => this.items

  private set(items: readonly VideoSending[]): void {
    this.items = items
    for (const listener of [...this.listeners]) listener()
  }

  async send(file: File, metadata: VideoAssetInfo): Promise<AssetRef> {
    const key = `${++this.count}:${file.name}`
    this.set([...this.items, { key, name: file.name, fraction: 0 }])
    try {
      return await this.service.upload(file, metadata, { onProgress: (fraction) => this.set(this.items.map((item) => (item.key === key ? { ...item, fraction } : item))) })
    } finally {
      this.set(this.items.filter((item) => item.key !== key))
    }
  }
}

const uploadsCache = new WeakMap<VideoService, VideoUploads>()

export function videoUploads(service: VideoService): VideoUploads {
  let uploads = uploadsCache.get(service)
  if (!uploads) {
    uploads = new VideoUploads(service)
    uploadsCache.set(service, uploads)
  }
  return uploads
}
