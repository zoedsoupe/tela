import { assetsApi, brandApi, commentsApi, designsApi, elementsApi, fontsApi, isApiError, profilesApi, sharesApi, templatesApi } from "@/lib/api"
import type { EditorAdapter, SaveInput, VideoAssetInfo, VideoUploadOptions } from "@/types/adapter"
import type { Asset, BrandKit, CommentInput, CommentMove, CommentT, Page, ShareLinkInput, TemplateCategory, TemplateDetail, TemplateSummary } from "@/types/api"
import type { DoryDocument } from "@/types/document"
import { RevisionConflictError } from "./errors"

function videoInfo(asset: Asset): VideoAssetInfo | undefined {
  const info = (asset.video && typeof asset.video === 'object' ? asset.video : undefined) as Partial<VideoAssetInfo> | undefined
  if (!info) return undefined
  return {
    posterUrl: asset.thumb_url || (typeof info.posterUrl === 'string' ? info.posterUrl : ''),
    durationMs: Number(info.durationMs ?? asset.duration_ms ?? 0),
    fps: Number(info.fps ?? 0),
    hasAudio: info.hasAudio === true,
    width: Number(info.width ?? asset.width),
    height: Number(info.height ?? asset.height),
  }
}

function assetRef(asset: Asset) {
  return {
    id: asset.id,
    url: asset.url,
    thumbUrl: asset.thumb_url,
    width: asset.width,
    height: asset.height,
    name: asset.name,
    kind: asset.kind,
    ...(asset.kind === 'video' && videoInfo(asset) ? { video: videoInfo(asset) } : {}),
  }
}

function conflict(error: unknown): never {
  if (isApiError(error) && error.status === 409 && error.code === 'revision_conflict') {
    const data = error.data as { current_revision?: unknown; current?: { revision?: unknown }; error?: { current_revision?: unknown } } | undefined
    const revision = data?.current_revision ?? data?.current?.revision ?? data?.error?.current_revision
    throw new RevisionConflictError(typeof revision === 'number' ? revision : null)
  }
  throw error
}

function brandInput(kit: BrandKit) {
  return { name: kit.name, is_default: kit.is_default, colors: kit.colors, fonts: kit.fonts, logo_ids: kit.logos.map((logo) => logo.id) }
}

function viewerFromProfile(profile: Awaited<ReturnType<typeof profilesApi.list>>['current_profile']) {
  return profile ? { id: profile.id, owner: true } : null
}

/** Workspace adapter: the Phoenix REST API is the only persistence boundary for the editor. */
export function createWorkspaceAdapter(designId: string, initialRevision: number): EditorAdapter {
  let revision = initialRevision

  return {
    async save(input: SaveInput) {
      try {
        const saved = await designsApi.patch(designId, { document: input.document, title: input.title, expected_revision: revision })
        revision = saved.revision
      } catch (error) {
        conflict(error)
      }
      if (input.thumbnail) {
        try {
          await designsApi.uploadThumbnail(designId, input.thumbnail)
        } catch {
          // The document save is authoritative; thumbnail failure must not roll it back.
        }
      }
      return { savedAt: Date.now(), revision }
    },
    async uploadAsset(file, options) {
      const asset = await assetsApi.upload(file, { name: options?.name })
      return assetRef(asset)
    },
    resolveSrc: async (src) => src,
    exportFilenames: { style: 'simple', timestamp: false },
    services: {
      fonts: {
        list: (query) => fontsApi.list(query),
        mine: {
          list: () => fontsApi.mine(),
          upload: (input, options) => fontsApi.upload(input, options),
          remove: (id) => fontsApi.removeMine(id),
        },
      },
      elements: { packs: () => elementsApi.packs(), list: (query) => elementsApi.list(query) },
      templates: {
        categories: (): Promise<TemplateCategory[]> => templatesApi.categories(),
        list: (query): Promise<Page<TemplateSummary>> => templatesApi.list(query),
        get: (id): Promise<TemplateDetail> => templatesApi.get(id),
      },
      assets: {
        list: async (query) => {
          const found = await assetsApi.list(query)
          return { ...found, results: found.results }
        },
        remove: (id) => assetsApi.remove(id),
        stock: {
          search: (query) => assetsApi.stock.search(query),
          import: (provider, externalId) => assetsApi.stock.import(provider, externalId),
        },
      },
      brand: {
        list: () => brandApi.list(),
        save: (kit) => (kit.id ? brandApi.update(kit.id, brandInput(kit)) : brandApi.create(brandInput(kit))),
        remove: (id) => brandApi.remove(id),
      },
      versions: {
        list: () => designsApi.versions.list(designId),
        create: async (label) => designsApi.versions.create(designId, label),
        restore: async (id): Promise<DoryDocument> => {
          const restored = await designsApi.versions.restore(designId, id)
          revision = restored.revision
          return restored.document
        },
      },
      sharing: {
        list: () => sharesApi.list(designId),
        create: (input: ShareLinkInput) => sharesApi.create(designId, input),
        update: async (id, patch) => {
          if (patch.is_active === false) {
            const current = (await sharesApi.list(designId)).find((link) => link.id === id)
            return sharesApi.update(id, patch, current)
          }
          return sharesApi.update(id, patch)
        },
        revoke: (id) => sharesApi.revoke(id),
      },
      comments: {
        list: (): Promise<CommentT[]> => commentsApi.list(designId),
        create: (input: CommentInput): Promise<CommentT> => commentsApi.create(designId, input),
        resolve: (id, resolved) => commentsApi.resolve(designId, id, resolved),
        remove: (id) => commentsApi.remove(designId, id),
        move: (id, to: CommentMove) => commentsApi.move(designId, id, to),
        viewer: async () => viewerFromProfile((await profilesApi.list()).current_profile),
      },
      video: {
        list: async (pageNumber) => {
          const found = await assetsApi.list({ kind: 'video', page: pageNumber, page_size: 30 })
          return { ...found, results: found.results.map(assetRef) }
        },
        upload: async (file, metadata: VideoAssetInfo, options?: VideoUploadOptions) => assetRef(await assetsApi.upload(file, { kind: 'video', video: metadata, signal: options?.signal, onProgress: options?.onProgress })),
      },
    },
  }
}
