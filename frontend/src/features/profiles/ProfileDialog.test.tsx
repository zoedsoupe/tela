import { QueryClient, QueryClientProvider } from "@tanstack/react-query"
import { cleanup, render, screen, waitFor, within } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { http as mswHttp, HttpResponse } from "msw"
import { afterEach, beforeEach, describe, expect, it } from "vitest"
import { ToastProvider } from "@/ui"
import { server } from "@/test/msw"
import { ProfileDialog } from "./ProfileDialog"

const firstProfile = { id: 'p1', name: 'Zoey', created_at: '', updated_at: '' }
const secondProfile = { id: 'p2', name: 'Tela', created_at: '', updated_at: '' }

function renderDialog() {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } })
  return render(
    <QueryClientProvider client={client}>
      <ToastProvider>
        <ProfileDialog open onClose={() => undefined} />
      </ToastProvider>
    </QueryClientProvider>,
  )
}

describe('ProfileDialog', () => {
  beforeEach(() => {
    document.cookie = 'csrftoken=tok; path=/'
  })

  afterEach(() => cleanup())

  it('lists, selects, creates and selects, then clears the current profile', async () => {
    let profiles = [firstProfile, secondProfile]
    let current: typeof firstProfile | null = firstProfile
    let nextId = 3
    server.use(
      mswHttp.get('*/api/profiles', () => HttpResponse.json({ profiles, current_profile: current })),
      mswHttp.post('*/api/profiles', async ({ request }) => {
        const body = await request.json() as { name: string }
        const profile = { id: `p${nextId++}`, name: body.name, created_at: '', updated_at: '' }
        profiles = [...profiles, profile]
        return HttpResponse.json({ profile }, { status: 201 })
      }),
      mswHttp.post('*/api/profiles/select', async ({ request }) => {
        const body = await request.json() as { profile_id: string }
        current = profiles.find((profile) => profile.id === body.profile_id) ?? null
        return HttpResponse.json({ current_profile: current })
      }),
      mswHttp.delete('*/api/profiles/select', () => {
        current = null
        return HttpResponse.json({ current_profile: null })
      }),
    )

    renderDialog()
    const dialog = await screen.findByRole('dialog', { name: 'Perfis' })
    const rows = await within(dialog).findAllByRole('listitem')
    expect(rows[0]).toHaveTextContent('Zoey')
    expect(rows[0]).toHaveTextContent('Selecionado')
    await userEvent.click(within(rows[1]).getByRole('button', { name: 'Selecionar' }))
    await waitForCurrentProfile(dialog, 'Tela')

    await userEvent.type(within(dialog).getByLabelText('Nome de exibição'), 'Nova pessoa')
    await userEvent.click(within(dialog).getByRole('button', { name: 'Criar e selecionar' }))
    await waitForCurrentProfile(dialog, 'Nova pessoa')

    await userEvent.click(within(dialog).getByRole('button', { name: 'Limpar seleção' }))
    expect(await within(dialog).findByText('Nenhum perfil selecionado')).toBeInTheDocument()
  })
})

async function waitForCurrentProfile(dialog: HTMLElement, name: string) {
  const current = within(dialog).getByRole('region', { name: 'Perfil selecionado' })
  await waitFor(() => expect(current).toHaveTextContent(name))
  await waitFor(() => {
    const row = within(dialog).getAllByRole('listitem').find((item) => item.textContent?.includes(name))
    expect(row).toHaveTextContent('Selecionado')
  })
}
