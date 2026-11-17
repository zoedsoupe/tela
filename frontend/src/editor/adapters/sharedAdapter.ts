import { commentsApi, elementsApi, fontsApi, isApiError, sharedApi, templatesApi } from "@/lib/api"
import type { EditorAdapter, SaveInput } from "@/types/adapter"
import type { CommentInput, CommentT, FontFamily, Page, ShareRole, TemplateCategory, TemplateDetail, TemplateSummary, VersionSummary } from "@/types/api"
import type { DoryDocument } from "@/types/document"
import { ReadOnlyDesignError, RevisionConflictError } from "./errors"

function raiseConflict(error: unknown): never {
  if (isApiError(error) && error.status === 409 && error.code === 'revision_conflict') {
    const data = error.data as { current?: { revision?: unknown }; error?: { current_revision?: unknown } } | undefined
    const revision = data?.current?.revision ?? data?.error?.current_revision
    throw new RevisionConflictError(typeof revision === 'number' ? revision : null)
  }
  throw error
}

export interface SharedAdapterOptions {
  token: string
  designId: string
  role: ShareRole
  revision: number
  title: string
  authorName?: string
  fonts?: readonly FontFamily[]
}

/** Capability-limited adapter for a bearer share link. */
export function createSharedAdapter(options: SharedAdapterOptions): EditorAdapter {
  const canEdit = options.role === 'edit'
  const authorName = options.authorName?.trim() ?? ''
  let revision = options.revision
  let title = options.title

  return {
    async save(input: SaveInput) {
      if (!canEdit) throw new ReadOnlyDesignError()
      try {
        if (input.title !== title) {
          const renamed = await sharedApi.rename(options.token, { title: input.title, expected_revision: revision })
          revision = renamed.revision
          title = renamed.title
        }
        const saved = await sharedApi.patch(options.token, { document: input.document, expected_revision: revision })
        revision = saved.revision
        title = saved.title
      } catch (error) {
        raiseConflict(error)
      }
      return { savedAt: Date.now(), revision }
    },
    async uploadAsset() {
      throw new ReadOnlyDesignError()
    },
    resolveSrc: async (src) => src,
    exportFilenames: { style: 'simple', timestamp: false },
    services: {
      fonts: { list: (query) => fontsApi.list(query), provided: options.fonts ?? [] },
      elements: { packs: () => elementsApi.packs(), list: (query) => elementsApi.list(query) },
      templates: {
        categories: (): Promise<TemplateCategory[]> => templatesApi.categories(),
        list: (query): Promise<Page<TemplateSummary>> => templatesApi.list(query),
        get: (id): Promise<TemplateDetail> => templatesApi.get(id),
      },
      assets: {
        list: async () => ({ count: 0, next: null, previous: null, results: [] }),
        remove: async () => { throw new ReadOnlyDesignError() },
      },
      brand: null,
      versions: canEdit ? {
        list: (): Promise<VersionSummary[]> => sharedApi.versions.list(options.token),
        create: (label) => sharedApi.versions.create(options.token, label),
        restore: async (versionId): Promise<DoryDocument> => {
          const restored = await sharedApi.restoreVersion(options.token, versionId, revision)
          revision = restored.revision
          title = restored.title
          return (await sharedApi.get(options.token)).document
        },
      } : null,
      sharing: null,
      // Guests may read and create threads. Resolve, move and delete stay workspace-only.
      comments: options.role === 'view' ? null : {
        list: (): Promise<CommentT[]> => commentsApi.listShared(options.token),
        create: async (input: CommentInput) => {
          if (!authorName) throw new Error('Informe um nome para comentar neste design.')
          return commentsApi.createShared(options.token, { ...input, author_name: authorName })
        },
        viewer: async () => null,
      },
    },
  }
}
