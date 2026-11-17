import { cleanup, render, screen, waitFor } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
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
  it('opens the library and lets the navbar profile button open the profile dialog', async () => {
    apiShell()
    window.history.replaceState({}, '', '/')
    render(<App />)

    expect(await screen.findByRole('heading', { name: 'Seus projetos' })).toBeInTheDocument()
    expect(screen.getByRole('link', {
      name: 'Doory by Siam, creator and maintainer of Doory, https://github.com/shaongitbd/doory',
    })).toHaveAttribute('href', 'https://github.com/shaongitbd/doory')
    await userEvent.click(screen.getByRole('button', { name: 'Selecionar perfil' }))
    expect(await screen.findByRole('dialog', { name: 'Perfis' })).toBeInTheDocument()
  })

  it('renders the local profile settings route without account UI', async () => {
    apiShell()
    window.history.replaceState({}, '', '/configuracoes')
    render(<App />)

    expect(await screen.findByRole('heading', { name: 'Perfis' })).toBeInTheDocument()
    await waitFor(() => expect(screen.getByText('Nenhum perfil selecionado')).toBeInTheDocument())
  })
})
