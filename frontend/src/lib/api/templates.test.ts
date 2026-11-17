import { http as mswHttp, HttpResponse } from "msw"
import { createBlankDocument } from "@/lib/document"
import { server } from "@/test/msw"
import { templatesApi } from "./templates"

beforeEach(() => {
  document.cookie = 'csrftoken=tok; path=/'
})

describe('Phoenix template API', () => {
  it('keeps template ids distinct from slugs and maps category objects', async () => {
    server.use(
      mswHttp.get('*/api/templates', () => HttpResponse.json({ templates: [{
        id: 'template-id-1',
        slug: 'spring-poster',
        title: 'Cartaz de primavera',
        description: 'Um cartaz',
        tags: ['flores'],
        category: { slug: 'posters', name: 'Cartazes' },
        width: 800,
        height: 1000,
        page_count: 1,
        thumbnail_url: '/template-assets/thumbs/spring-poster.webp',
        use_count: 2,
      }] })),
      mswHttp.get('*/api/templates/spring-poster', () => HttpResponse.json({ template: {
        id: 'template-id-1',
        slug: 'spring-poster',
        title: 'Cartaz de primavera',
        description: 'Um cartaz',
        tags: ['flores'],
        category: { slug: 'posters', name: 'Cartazes' },
        width: 800,
        height: 1000,
        page_count: 1,
        thumbnail_url: '/template-assets/thumbs/spring-poster.webp',
        use_count: 2,
        document: createBlankDocument(800, 1000),
      } })),
      mswHttp.get('*/api/template-categories', () => HttpResponse.json([{ slug: 'posters', name: 'Cartazes' }])),
    )

    const [templates, categories, detail] = await Promise.all([templatesApi.list(), templatesApi.categories(), templatesApi.get('spring-poster')])

    expect(templates.results[0]).toMatchObject({
      id: 'template-id-1',
      slug: 'spring-poster',
      category: { id: 'posters', slug: 'posters', name: 'Cartazes' },
      thumbnail_url: '/template-assets/thumbs/spring-poster.webp',
    })
    expect(categories).toEqual([expect.objectContaining({ id: 'posters', slug: 'posters', name: 'Cartazes', template_count: 1 })])
    expect(detail).toMatchObject({ id: 'template-id-1', slug: 'spring-poster', description: 'Um cartaz' })
  })

  it('uses the Phoenix copy endpoint and unwraps its design envelope', async () => {
    let called = false
    server.use(mswHttp.post('*/api/templates/spring-poster/use', () => {
      called = true
      return HttpResponse.json({ design: {
        id: 'design-1',
        title: 'Cartaz de primavera',
        width: 800,
        height: 1000,
        preset_id: null,
        page_count: 1,
        thumbnail_url: null,
        folder_id: null,
        starred: false,
        revision: 1,
        created_at: '',
        updated_at: '',
        trashed_at: null,
        document: createBlankDocument(800, 1000),
      } })
    }))

    const design = await templatesApi.use('spring-poster')

    expect(called).toBe(true)
    expect(design.id).toBe('design-1')
  })
})
