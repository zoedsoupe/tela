import { http as mswHttp, HttpResponse } from "msw"
import { createBlankDocument } from "@/lib/document"
import { server } from "@/test/msw"
import { createWorkspaceAdapter } from "./workspaceAdapter"

beforeEach(() => {
  document.cookie = 'csrftoken=tok; path=/'
})

describe('WorkspaceAdapter', () => {
  it('saves a document with expected_revision and uploads its thumbnail after the save', async () => {
    const document = createBlankDocument(640, 480)
    let patchBody: unknown
    const calls: string[] = []
    server.use(
      mswHttp.patch('*/api/designs/d1', async ({ request }) => {
        calls.push('save')
        patchBody = await request.json()
        return HttpResponse.json({ design: { id: 'd1', title: 'Poster', width: 640, height: 480, preset_id: null, page_count: 1, thumbnail_url: null, folder_id: null, starred: false, revision: 8, created_at: '', updated_at: '', trashed_at: null, document } })
      }),
      mswHttp.put('*/api/designs/d1/thumbnail', () => {
        calls.push('thumbnail')
        return HttpResponse.json({ thumbnail_url: '/uploads/design-thumbnails/t1' })
      }),
    )

    const adapter = createWorkspaceAdapter('d1', 7)
    const result = await adapter.save({ document, title: 'Poster', thumbnail: new Blob(['thumb'], { type: 'image/png' }) })

    expect(patchBody).toMatchObject({ expected_revision: 7, title: 'Poster' })
    expect((patchBody as { document: unknown }).document).toEqual(JSON.parse(JSON.stringify(document)))
    expect(calls).toEqual(['save', 'thumbnail'])
    expect(result.revision).toBe(8)
  })

  it('maps a Phoenix revision conflict to the editor conflict error', async () => {
    server.use(mswHttp.patch('*/api/designs/d1', () => HttpResponse.json({
      error: { code: 'revision_conflict', message: 'Conflito', current_revision: 12 },
    }, { status: 409 })))

    const adapter = createWorkspaceAdapter('d1', 7)
    await expect(adapter.save({ document: createBlankDocument(100, 100), title: 'Poster' }))
      .rejects.toMatchObject({ name: 'RevisionConflictError', currentRevision: 12 })
  })
})
