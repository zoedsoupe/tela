import { http as mswHttp, HttpResponse } from 'msw'
import { server } from '@/test/msw'
import { assetsApi } from './assets'

describe('assetsApi.stock', () => {
  beforeEach(() => {
    document.cookie = 'csrftoken=tok; path=/'
  })

  it('maps the stock endpoint response to a page and preserves provider errors', async () => {
    const requestedUrls: URL[] = []
    server.use(mswHttp.get('*/api/assets/stock', ({ request }) => {
      requestedUrls.push(new URL(request.url))
      return HttpResponse.json({
        items: [{
          external_id: 'photo-1',
          provider: 'unsplash',
          thumb_url: 'https://images.example.test/thumb.jpg',
          full_url: 'https://images.example.test/full.jpg',
          author: 'Ada',
          author_url: 'https://unsplash.com/@ada?utm_source=tela&utm_medium=referral',
          source_url: 'https://unsplash.com/?utm_source=tela&utm_medium=referral',
        }],
        next_page: 4,
        errors: [{ provider: 'pexels', code: 'timeout' }],
      })
    }))

    const page = await assetsApi.stock.search({ q: 'beach', provider: 'all', page: 1 })

    const requestedUrl = requestedUrls[0]
    expect(requestedUrl?.searchParams.get('q')).toBe('beach')
    expect(requestedUrl?.searchParams.get('provider')).toBe('all')
    expect(requestedUrl?.searchParams.get('page')).toBe('1')
    expect(page).toMatchObject({
      count: 1,
      next: '4',
      previous: null,
      results: [{ external_id: 'photo-1', author_url: 'https://unsplash.com/@ada?utm_source=tela&utm_medium=referral' }],
      errors: [{ provider: 'pexels', code: 'timeout' }],
    })
  })

  it('imports a provider photo and unwraps the returned asset', async () => {
    let requestBody: unknown
    server.use(mswHttp.post('*/api/assets/stock/import', async ({ request }) => {
      requestBody = await request.json()
      return HttpResponse.json({
        asset: {
          id: 'asset-1',
          kind: 'image',
          name: 'Photo',
          url: 'https://images.unsplash.com/photo-1?utm_source=tela&utm_medium=referral',
          thumb_url: 'https://images.unsplash.com/photo-1?w=400',
          width: 1200,
          height: 800,
          size: 0,
          mime: 'image/jpeg',
          tags: [],
          attribution: {
            provider: 'unsplash',
            author: 'Ada',
            author_url: 'https://unsplash.com/@ada?utm_source=tela&utm_medium=referral',
            source_url: 'https://unsplash.com/?utm_source=tela&utm_medium=referral',
          },
          created_at: '',
        },
      })
    }))

    const imported = await assetsApi.stock.import('unsplash', 'photo-1')

    expect(requestBody).toEqual({ provider: 'unsplash', external_id: 'photo-1' })
    expect(imported).toMatchObject({
      id: 'asset-1',
      url: 'https://images.unsplash.com/photo-1?utm_source=tela&utm_medium=referral',
      attribution: { provider: 'unsplash', author: 'Ada' },
    })
  })
})
