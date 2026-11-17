import type { BulkAction, Design, DesignCreateInput, DesignPatchInput, DesignQuery, DesignSummary, Page, VersionDetail, VersionSummary } from "@/types/api"
import { http } from "./client"

interface DesignEnvelope<T> { design: T }
interface DesignListEnvelope { designs: Array<Record<string, unknown>> }

function summary(raw: Record<string, unknown>): DesignSummary {
  const preset = typeof raw.preset_id === 'string' ? raw.preset_id : typeof raw.preset === 'string' ? raw.preset : ''
  const folder = typeof raw.folder_id === 'string' ? raw.folder_id : typeof raw.folder === 'string' ? raw.folder : null
  return {
    id: String(raw.id ?? ''),
    title: typeof raw.title === 'string' ? raw.title : 'Design sem título',
    width: Number(raw.width ?? 0),
    height: Number(raw.height ?? 0),
    preset,
    preset_id: preset || null,
    category: typeof raw.category === 'string' ? raw.category : undefined,
    page_count: Number(raw.page_count ?? 1),
    thumbnail_url: typeof raw.thumbnail_url === 'string' ? raw.thumbnail_url : null,
    folder,
    folder_id: folder,
    starred: raw.starred === true,
    revision: Number(raw.revision ?? 1),
    created_at: typeof raw.created_at === 'string' ? raw.created_at : '',
    updated_at: typeof raw.updated_at === 'string' ? raw.updated_at : '',
    trashed_at: typeof raw.trashed_at === 'string' ? raw.trashed_at : null,
  }
}

function detail(raw: Record<string, unknown>): Design {
  return { ...summary(raw), document: raw.document as Design['document'] }
}

function page(items: DesignSummary[], pageNumber = 1, pageSize = items.length || 24): Page<DesignSummary> {
  const start = Math.max(0, pageNumber - 1) * pageSize
  return {
    count: items.length,
    next: start + pageSize < items.length ? 'more' : null,
    previous: start > 0 ? 'previous' : null,
    results: items.slice(start, start + pageSize),
  }
}

function sort(items: DesignSummary[], ordering: DesignQuery['ordering']): DesignSummary[] {
  const copy = [...items]
  if (ordering === 'title' || ordering === '-title') {
    copy.sort((a, b) => a.title.localeCompare(b.title, 'pt-BR') * (ordering === '-title' ? -1 : 1))
  } else if (ordering === '-created_at') {
    copy.sort((a, b) => b.created_at.localeCompare(a.created_at))
  } else {
    copy.sort((a, b) => b.updated_at.localeCompare(a.updated_at))
  }
  return copy
}

function queryParams(query: DesignQuery): Record<string, string | number | boolean | null | undefined> {
  return {
    q: query.q,
    folder_id: query.folder === 'root' ? 'root' : query.folder,
    starred: query.starred,
    trashed: query.trashed,
  }
}

function patchBody(input: DesignPatchInput): Record<string, unknown> {
  const body: Record<string, unknown> = { ...input }
  if ('base_revision' in body && !('expected_revision' in body)) body.expected_revision = body.base_revision
  if ('folder' in body && !('folder_id' in body)) body.folder_id = body.folder
  delete body.base_revision
  delete body.folder
  return body
}

export const designsApi = {
  list: async (query: DesignQuery = {}, signal?: AbortSignal): Promise<Page<DesignSummary>> => {
    const data = await http.get<DesignListEnvelope>("/designs", { query: queryParams(query), signal })
    const items = sort((data.designs ?? []).map(summary), query.ordering)
    return page(items, query.page, query.page_size)
  },
  get: async (id: string, signal?: AbortSignal): Promise<Design> => detail((await http.get<DesignEnvelope<Record<string, unknown>>>(`/designs/${encodeURIComponent(id)}`, { signal })).design),
  create: async (input: DesignCreateInput): Promise<Design> => {
    const body: Record<string, unknown> = { ...input }
    if (input.preset && !input.preset_id) body.preset_id = input.preset
    if (input.folder && !input.folder_id) body.folder_id = input.folder
    delete body.preset
    delete body.folder
    return detail((await http.post<DesignEnvelope<Record<string, unknown>>>("/designs", { json: body })).design)
  },
  patch: async (id: string, input: DesignPatchInput): Promise<Design> => detail((await http.patch<DesignEnvelope<Record<string, unknown>>>(`/designs/${encodeURIComponent(id)}`, { json: patchBody(input) })).design),
  /** Soft delete (moves to trash). */
  trash: (id: string) => http.delete<void>(`/designs/${encodeURIComponent(id)}`),
  /** Hard delete; only valid for designs already in the trash. */
  deleteForever: (id: string) => http.delete<void>(`/designs/${encodeURIComponent(id)}`, { query: { permanent: true } }),
  restore: async (id: string) => detail((await http.post<DesignEnvelope<Record<string, unknown>>>(`/designs/${encodeURIComponent(id)}/restore`)).design),
  duplicate: async (id: string) => detail((await http.post<DesignEnvelope<Record<string, unknown>>>(`/designs/${encodeURIComponent(id)}/duplicate`)).design),
  uploadThumbnail: (id: string, image: Blob) => {
    const form = new FormData()
    form.append('image', image, image.type === "image/png" ? 'thumbnail.png' : 'thumbnail.webp')
    return http.put<{ thumbnail_url: string }>(`/designs/${encodeURIComponent(id)}/thumbnail`, { form })
  },
  /** Kept for the dashboard bulk action supplied by the parallel backend implementation. */
  bulk: (input: { ids: string[]; action: BulkAction; folder?: string | null }) => http.post<{ affected: number }>("/designs/bulk", { json: { ...input, folder_id: input.folder } }),
  emptyTrash: () => http.delete<void>("/designs/trash"),
  versions: {
    list: async (designId: string) => (await http.get<{ versions: VersionSummary[] }>(`/designs/${encodeURIComponent(designId)}/versions`)).versions,
    create: async (designId: string, label: string) => (await http.post<{ version: VersionSummary }>(`/designs/${encodeURIComponent(designId)}/versions`, { json: { label } })).version,
    get: async (designId: string, versionId: string) => (await http.get<{ version: VersionDetail }>(`/designs/${encodeURIComponent(designId)}/versions/${encodeURIComponent(versionId)}`)).version,
    restore: async (designId: string, versionId: string) => detail((await http.post<DesignEnvelope<Record<string, unknown>>>(`/designs/${encodeURIComponent(designId)}/versions/${encodeURIComponent(versionId)}/restore`)).design),
  },
}

export { detail as designFromApi, summary as designSummaryFromApi }
