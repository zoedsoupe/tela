import type { Asset, AssetKind, AssetQuery, Page, StockPage, StockProvider, StockProviderFilter } from "@/types/api"
import type { VideoAssetInfo } from "@/types/adapter"
import { http } from "./client"

export interface AssetUploadOptions {
  name?: string
  kind?: AssetKind
  metadata?: Record<string, unknown>
  video?: VideoAssetInfo
  signal?: AbortSignal
  onProgress?: (fraction: number) => void
}

function kindOf(file: File | Blob): AssetKind {
  if (file.type === 'image/svg+xml') return 'svg'
  if (file.type.startsWith('audio/')) return 'audio'
  if (file.type.startsWith('video/')) return 'video'
  return 'image'
}

export const assetsApi = {
  list: async (query: AssetQuery & { ordering?: string } = {}, signal?: AbortSignal): Promise<Page<Asset>> => {
    const items = await http.get<Asset[]>("/assets", { query: { kind: query.kind, q: query.q, ordering: query.ordering }, signal })
    const pageSize = query.page_size ?? 40
    const start = Math.max(0, (query.page ?? 1) - 1) * pageSize
    return { count: items.length, next: start + pageSize < items.length ? 'more' : null, previous: start > 0 ? 'previous' : null, results: items.slice(start, start + pageSize) }
  },
  upload: async (file: File | Blob, options: AssetUploadOptions = {}): Promise<Asset> => {
    const form = new FormData()
    const filename = file instanceof File ? file.name : (options.name ?? 'upload')
    form.append('file', file, filename)
    if (options.name) form.append('name', options.name)
    form.append('kind', options.kind ?? kindOf(file))
    if (options.video) {
      form.append('duration_ms', String(options.video.durationMs))
      form.append('width', String(options.video.width))
      form.append('height', String(options.video.height))
      form.append('metadata', JSON.stringify({ video: options.video }))
      if (options.video.posterUrl.startsWith('blob:') || options.video.posterUrl.startsWith('data:')) {
        const poster = await fetch(options.video.posterUrl).then((response) => response.blob())
        form.append('poster', poster, 'poster.png')
      }
    } else if (options.metadata) {
      form.append('metadata', JSON.stringify(options.metadata))
    }
    return http.post<Asset>("/assets", { form, signal: options.signal, onUploadProgress: options.onProgress })
  },
  remove: (id: string) => http.delete<void>(`/assets/${encodeURIComponent(id)}`),
  stock: {
    search: async ({ q, provider, page }: { q: string; provider: StockProviderFilter; page: number }): Promise<StockPage> => {
      const response = await http.get<{
        items: StockPage['results']
        next_page: number | null
        errors: StockPage['errors']
      }>("/assets/stock", { query: { q, provider, page } })
      return {
        count: response.items.length,
        next: response.next_page === null ? null : String(response.next_page),
        previous: page > 1 ? String(page - 1) : null,
        results: response.items,
        errors: response.errors,
      }
    },
    import: async (provider: StockProvider, externalId: string): Promise<Asset> => {
      const response = await http.post<{ asset: Asset }>("/assets/stock/import", { json: { provider, external_id: externalId } })
      return response.asset
    },
  },
}
