import { http as mswHttp, HttpResponse } from "msw"
import { createBlankDocument } from "@/lib/document"
import { server } from "@/test/msw"
import { createSharedAdapter } from "./sharedAdapter"

beforeEach(() => {
  document.cookie = 'csrftoken=tok; path=/'
})

describe('SharedAdapter', () => {
  it('does not expose write services to a view link', async () => {
    const adapter = createSharedAdapter({ token: 'token-view', designId: 'd1', role: 'view', revision: 1, title: 'Shared' })

    await expect(adapter.save({ document: createBlankDocument(100, 100), title: 'Changed' }))
      .rejects.toMatchObject({ name: 'ReadOnlyDesignError' })
    expect(adapter.services.comments).toBeNull()
    expect(adapter.services.sharing).toBeNull()
    expect(adapter.services.versions).toBeNull()
  })

  it('renames and saves an edit link in separate expected-revision requests', async () => {
    const document = createBlankDocument(100, 100)
    const bodies: unknown[] = []
    server.use(
      mswHttp.patch('*/api/shared/token-edit', async ({ request }) => {
        const body = await request.json()
        bodies.push(body)
        if ('title' in (body as Record<string, unknown>)) {
          return HttpResponse.json({ design_id: 'd1', title: 'After', revision: 2, updated_at: '' })
        }
        return HttpResponse.json({ design_id: 'd1', title: 'After', revision: 3, updated_at: '' })
      }),
    )
    const adapter = createSharedAdapter({ token: 'token-edit', designId: 'd1', role: 'edit', revision: 1, title: 'Before' })

    const result = await adapter.save({ document, title: 'After' })

    expect(bodies).toEqual([
      { title: 'After', expected_revision: 1 },
      { document, expected_revision: 2 },
    ])
    expect(result.revision).toBe(3)
  })

  it('restores a version through the edit token with its current revision', async () => {
    const document = createBlankDocument(100, 100)
    let body: unknown
    server.use(
      mswHttp.post('*/api/shared/token-edit/versions/v1/restore', async ({ request }) => {
        body = await request.json()
        return HttpResponse.json({ design_id: 'd1', revision: 2, title: 'Shared', updated_at: '' })
      }),
      mswHttp.get('*/api/shared/token-edit', () => HttpResponse.json({
        design_id: 'd1',
        role: 'edit',
        title: 'Shared',
        width: 100,
        height: 100,
        page_count: 1,
        revision: 2,
        document,
        fonts: [],
      })),
    )
    const adapter = createSharedAdapter({ token: 'token-edit', designId: 'd1', role: 'edit', revision: 1, title: 'Shared' })

    await expect(adapter.services.versions?.restore('v1')).resolves.toEqual(document)

    expect(body).toEqual({ expected_revision: 1 })
  })
})
