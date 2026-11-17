import { http as mswHttp, HttpResponse } from "msw"
import { server } from "@/test/msw"
import { profilesApi } from "./profiles"

beforeEach(() => {
  document.cookie = 'csrftoken=tok; path=/'
})

describe('profiles API', () => {
  it('reads the available profiles and current selection', async () => {
    server.use(mswHttp.get('*/api/profiles', () => HttpResponse.json({
      profiles: [{ id: 'p1', name: 'Zoey', created_at: '', updated_at: '' }],
      current_profile: { id: 'p1', name: 'Zoey', created_at: '', updated_at: '' },
    })))

    await expect(profilesApi.list()).resolves.toMatchObject({ profiles: [{ id: 'p1', name: 'Zoey' }], current_profile: { id: 'p1' } })
  })

  it('creates, selects and clears a profile with Phoenix contracts', async () => {
    let selection: unknown
    server.use(
      mswHttp.post('*/api/profiles', () => HttpResponse.json({ profile: { id: 'p2', name: 'Tela', created_at: '', updated_at: '' } }, { status: 201 })),
      mswHttp.post('*/api/profiles/select', async ({ request }) => {
        selection = await request.json()
        return HttpResponse.json({ current_profile: { id: 'p2', name: 'Tela', created_at: '', updated_at: '' } })
      }),
      mswHttp.delete('*/api/profiles/select', () => HttpResponse.json({ current_profile: null })),
    )

    const profile = await profilesApi.create('Tela')
    await profilesApi.select(profile.id)
    await profilesApi.clear()

    expect(selection).toEqual({ profile_id: 'p2' })
  })
})
