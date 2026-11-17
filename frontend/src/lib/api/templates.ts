import type { Design, Page, TemplateCategory, TemplateDetail, TemplateQuery, TemplateSummary } from "@/types/api"
import { http } from "./client"
import { designFromApi } from "./designs"

interface TemplateEnvelope<T> { template: T }
interface TemplateListEnvelope { templates: Array<Record<string, unknown>> }

function categoryOf(value: unknown): TemplateSummary['category'] {
  if (value && typeof value === 'object') {
    const raw = value as Record<string, unknown>
    return {
      id: String(raw.id ?? raw.slug ?? ''),
      slug: String(raw.slug ?? raw.id ?? ''),
      name: String(raw.name ?? raw.slug ?? ''),
    }
  }
  if (typeof value !== 'string' || value.length === 0) return null
  return { id: value, slug: value, name: value }
}

function summary(raw: Record<string, unknown>): TemplateSummary {
  const width = Number(raw.width ?? 0)
  const height = Number(raw.height ?? 0)
  const id = String(raw.id ?? '')
  return {
    id,
    slug: typeof raw.slug === 'string' ? raw.slug : id,
    title: typeof raw.title === 'string' ? raw.title : 'Modelo sem título',
    category: categoryOf(raw.category),
    tags: Array.isArray(raw.tags) ? raw.tags.filter((tag): tag is string => typeof tag === 'string') : [],
    width,
    height,
    orientation: width === height ? 'square' : width > height ? 'landscape' : 'portrait',
    preset: typeof raw.preset_id === 'string' ? raw.preset_id : '',
    page_count: Number(raw.page_count ?? 1),
    thumbnail_url: typeof raw.thumbnail_url === 'string' ? raw.thumbnail_url : null,
    is_featured: raw.is_featured === true,
    use_count: Number(raw.use_count ?? 0),
    created_at: typeof raw.created_at === 'string' ? raw.created_at : '',
  }
}

function page(items: TemplateSummary[], query: TemplateQuery): Page<TemplateSummary> {
  const size = query.page_size ?? 24
  const start = Math.max(0, (query.page ?? 1) - 1) * size
  return { count: items.length, next: start + size < items.length ? 'more' : null, previous: start > 0 ? 'previous' : null, results: items.slice(start, start + size) }
}

async function all(query: TemplateQuery = {}, signal?: AbortSignal): Promise<TemplateSummary[]> {
  const response = await http.get<TemplateListEnvelope>("/templates", { query: { q: query.q, category: query.category }, signal })
  return (response.templates ?? []).map(summary)
}

export const templatesApi = {
  categories: async (signal?: AbortSignal): Promise<TemplateCategory[]> => {
    const categories = await http.get<Array<{ slug: string; name: string }>>("/template-categories", { signal })
    const templates = await all({}, signal)
    return categories.map((category, sort_order) => ({
      id: category.slug,
      slug: category.slug,
      name: category.name,
      icon: '',
      template_count: templates.filter((template) => template.category?.slug === category.slug).length,
      sort_order,
    }))
  },
  list: async (query: TemplateQuery = {}, signal?: AbortSignal): Promise<Page<TemplateSummary>> => {
    const items = await all(query, signal)
    let filtered = items.filter((item) => (!query.category || item.category?.slug === query.category) && (!query.q || `${item.title} ${item.tags.join(' ')}`.toLocaleLowerCase('pt-BR').includes(query.q.toLocaleLowerCase('pt-BR'))) && (!query.orientation || item.orientation === query.orientation))
    if (query.ordering === 'title' || query.ordering === '-title') filtered = [...filtered].sort((a, b) => a.title.localeCompare(b.title, 'pt-BR') * (query.ordering === '-title' ? -1 : 1))
    else if (query.ordering === '-use_count') filtered = [...filtered].sort((a, b) => b.use_count - a.use_count)
    return page(filtered, query)
  },
  get: async (id: string, signal?: AbortSignal): Promise<TemplateDetail> => {
    const raw = (await http.get<TemplateEnvelope<Record<string, unknown>>>(`/templates/${encodeURIComponent(id)}`, { signal })).template
    return { ...summary(raw), description: typeof raw.description === 'string' ? raw.description : '', document: raw.document as TemplateDetail['document'] }
  },
  /** The endpoint creates a workspace design from the saved template document. */
  use: async (slug: string): Promise<Design> => {
    const response = await http.post<{ design: Record<string, unknown> }>(`/templates/${encodeURIComponent(slug)}/use`)
    return designFromApi(response.design)
  },
}
