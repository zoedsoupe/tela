/** Temporary browser-only adapter used by the harness until the Phoenix workspace adapter is integrated. */
import { localRepository, type LocalRepository } from "@/lib/local"
import type { AssetRef, EditorAdapter, SaveInput, VideoAssetInfo } from "@/types/adapter"
import type { Asset, AssetKind, Page } from "@/types/api"
import { readImageSize } from "../engine/assets"
import { createMemoryAdapter, type MemoryAdapterHandle, type MemoryAdapterOptions } from "./memoryAdapter"

const LOCAL_SRC = /^idb:\/\/([0-9a-f-]{36})$/i

function page<T>(items: T[], pageNumber = 1, pageSize = 50): Page<T> {
  const start = (pageNumber - 1) * pageSize
  const results = items.slice(start, start + pageSize)
  return { count: items.length, next: start + pageSize < items.length ? 'next' : null, previous: null, results }
}

function kindOf(mime: string): AssetKind {
  if (mime === "image/svg+xml") return 'svg'
  if (mime.startsWith("audio/")) return 'audio'
  if (mime.startsWith("video/")) return 'video'
  return 'image'
}

function assetOf(asset: Awaited<ReturnType<LocalRepository['listAssets']>>[number]): Asset {
  const kind = kindOf(asset.mime)
  const url = `idb://${asset.id}`
  return {
    id: asset.id,
    kind,
    name: asset.name,
    url,
    thumb_url: asset.metadata?.video?.posterUrl ?? (kind === 'image' || kind === 'svg' ? url : ''),
    width: asset.width,
    height: asset.height,
    size: asset.blob.size,
    mime: asset.mime,
    tags: [],
    attribution: null,
    duration_ms: asset.metadata?.video?.durationMs ?? null,
    created_at: new Date(asset.createdAt).toISOString(),
  }
}

function refOf(asset: Awaited<ReturnType<LocalRepository['listAssets']>>[number]): AssetRef {
  const kind = kindOf(asset.mime)
  const url = `idb://${asset.id}`
  return {
    id: asset.id,
    url,
    thumbUrl: asset.metadata?.video?.posterUrl ?? (kind === 'image' || kind === 'svg' ? url : ''),
    width: asset.width,
    height: asset.height,
    name: asset.name,
    kind,
    ...(asset.metadata?.video ? { video: asset.metadata.video } : {}),
  }
}

function isAudio(file: File | Blob): boolean {
  const name = file instanceof File ? file.name : ''
  return file.type.startsWith("audio/") || /\.(mp3|ogg|oga|opus|wav|m4a|weba|webm)$/i.test(name)
}

export function createLocalAdapter(id: string, options: MemoryAdapterOptions = {}, repository: LocalRepository = localRepository): MemoryAdapterHandle {
  const memory = createMemoryAdapter(options)
  const base = memory.adapter

  const adapter: EditorAdapter = {
    ...base,
    async save(input: SaveInput) {
      await base.save(input)
      const saved = await repository.saveDesign({ id, title: input.title, document: input.document, thumbnail: input.thumbnail })
      return { savedAt: saved.updatedAt }
    },
    async uploadAsset(file, options) {
      const name = options?.name ?? (file instanceof File ? file.name : "Arquivo")
      let width = 0
      let height = 0
      if (!isAudio(file)) {
        const preview = URL.createObjectURL(file)
        try {
          const size = await readImageSize(preview)
          width = size.width
          height = size.height
        } finally {
          URL.revokeObjectURL(preview)
        }
      }
      const asset = await repository.putAsset({ blob: file, name, mime: file.type || 'application/octet-stream', width, height })
      memory.uploads.push({ name, size: file.size })
      const url = `idb://${asset.id}`
      const kind = kindOf(asset.mime)
      return { id: asset.id, url, thumbUrl: kind === 'image' || kind === 'svg' ? url : '', width, height, name, kind }
    },
    async resolveSrc(src) {
      const match = LOCAL_SRC.exec(src)
      if (!match) return src
      const url = await repository.getAssetObjectUrl(match[1])
      if (!url) throw new Error("Este arquivo não está mais salvo neste navegador.")
      return url
    },
    services: {
      ...base.services,
      assets: {
        async list(query) {
          const all = (await repository.listAssets())
            .filter((asset) => !query.kind || kindOf(asset.mime) === query.kind)
            .filter((asset) => !query.q || asset.name.toLocaleLowerCase('pt-BR').includes(query.q.toLocaleLowerCase('pt-BR')))
            .map(assetOf)
          return page(all, query.page, query.page_size)
        },
        remove: (assetId) => repository.deleteAsset(assetId),
      },
      video: {
        async list(pageNumber) {
          const videos = (await repository.listAssets()).filter((asset) => kindOf(asset.mime) === 'video' && asset.metadata?.video).map(refOf)
          return page(videos, pageNumber, 30)
        },
        async upload(file, metadata: VideoAssetInfo, options) {
          options?.onProgress?.(0)
          const asset = await repository.putAsset({
            blob: file,
            name: file.name,
            mime: file.type || "video/*",
            width: metadata.width,
            height: metadata.height,
            metadata: { video: metadata },
          })
          options?.onProgress?.(1)
          const ref = refOf(asset)
          memory.uploads.push({ name: file.name, size: file.size })
          return ref
        },
      },
    },
  }

  return { ...memory, adapter }
}
