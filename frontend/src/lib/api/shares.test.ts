import { http as mswHttp, HttpResponse } from "msw"
import { server } from "@/test/msw"
import { sharesApi } from "./shares"

beforeEach(() => {
  document.cookie = 'csrftoken=tok; path=/'
})

describe('sharesApi', () => {
  it('sends expires_in when creating a link', async () => {
    let body: unknown
    server.use(mswHttp.post('*/api/designs/d1/share_links', async ({ request }) => {
      body = await request.json()
      return HttpResponse.json({ id: 's1', token: 'secret', role: 'comment', url: '/s/secret', is_active: true, expires_at: '2026-12-17T12:00:00Z', revoked_at: null, created_at: '2026-11-17T12:00:00Z' }, { status: 201 })
    }))

    const link = await sharesApi.create('d1', { role: 'comment', expires_in: '30d' })

    expect(body).toEqual({ role: 'comment', expires_in: '30d' })
    expect(link).toMatchObject({ token: 'secret', expires_at: '2026-12-17T12:00:00Z', is_active: true })
  })

  it('keeps expiry and revocation state without exposing a missing list token', async () => {
    server.use(mswHttp.get('*/api/designs/d1/share_links', () => HttpResponse.json([
      { id: 's1', role: 'view', url: null, is_active: false, expires_at: '2026-11-01T12:00:00Z', revoked_at: null, created_at: '2026-10-01T12:00:00Z' },
    ])))

    await expect(sharesApi.list('d1')).resolves.toEqual([
      expect.objectContaining({ id: 's1', token: '', url: '', is_active: false, expires_at: '2026-11-01T12:00:00Z', revoked_at: null }),
    ])
  })
})
