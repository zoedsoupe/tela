import { cleanup, render, screen, waitFor } from "@testing-library/react"
import { http as mswHttp, HttpResponse } from "msw"
import { afterEach, describe, expect, it } from "vitest"
import { server } from "@/test/msw"
import App from "./App"

afterEach(() => {
  cleanup()
  window.history.replaceState({}, '', '/')
})

function apiShell() {
  server.use(
    mswHttp.get('*/api/designs', () => HttpResponse.json({ designs: [] })),
    mswHttp.get('*/api/folders', () => HttpResponse.json({ folders: [] })),
    mswHttp.get('*/api/profiles', () => HttpResponse.json({ profiles: [], current_profile: null })),
  )
}

describe('SPA routes', () => {
  it('opens the library at the root and keeps the visible Doory credit', async () => {
    apiShell()
    window.history.replaceState({}, '', '/')
    render(<App />)

    expect(await screen.findByRole('heading', { name: 'Seus projetos' })).toBeInTheDocument()
    expect(screen.getByText('Doory by Siam, creator and maintainer of Doory, https://github.com/shaongitbd/doory')).toBeInTheDocument()
  })

  it('renders the local profile settings route without account UI', async () => {
    apiShell()
    window.history.replaceState({}, '', '/configuracoes')
    render(<App />)

    expect(await screen.findByRole('heading', { name: 'Perfis' })).toBeInTheDocument()
    await waitFor(() => expect(screen.getByText('Nenhum perfil selecionado')).toBeInTheDocument())
  })
})
