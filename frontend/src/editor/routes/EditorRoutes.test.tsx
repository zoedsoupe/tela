import { QueryClient, QueryClientProvider } from "@tanstack/react-query"
import { cleanup, render, screen, waitFor } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { http as mswHttp, HttpResponse } from "msw"
import { afterEach, describe, expect, it, vi } from "vitest"
import type { ReactNode } from "react"
import { MemoryRouter, Route, Routes, useLocation } from "react-router-dom"
import { ToastProvider } from "@/ui"
import { server } from "@/test/msw"
import { WorkspaceEditor } from "./EditorRoutes"

vi.mock("../EditorApp", () => ({
  EditorApp: ({ topBarStart, topBarEnd }: { topBarStart?: ReactNode; topBarEnd?: ReactNode }) => (
    <div data-testid="mock-editor">{topBarStart}{topBarEnd}</div>
  ),
}))

function StateProbe() {
  const location = useLocation()
  return <output data-testid="navigation-state">{location.state?.newDesign ? 'new' : 'existing'}</output>
}

function renderWorkspace(state: unknown) {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } })
  return render(
    <QueryClientProvider client={client}>
      <ToastProvider>
        <MemoryRouter initialEntries={[{ pathname: '/design/d1', state }]}>
          <Routes>
            <Route path="/design/:id" element={<><WorkspaceEditor /><StateProbe /></>} />
          </Routes>
        </MemoryRouter>
      </ToastProvider>
    </QueryClientProvider>,
  )
}

describe('workspace editor profile prompt', () => {
  afterEach(() => cleanup())

  function mockWorkspace(currentProfile: { id: string; name: string; created_at: string; updated_at: string } | null) {
    server.use(
      mswHttp.get('*/api/designs/d1', () => HttpResponse.json({
        design: { id: 'd1', title: 'Teste', revision: 1, document: {} },
      })),
      mswHttp.get('*/api/profiles', () => HttpResponse.json({
        profiles: currentProfile ? [currentProfile] : [],
        current_profile: currentProfile,
      })),
    )
  }

  it('opens the profile dialog only for a newly created design with no profile, and consumes the navigation state', async () => {
    mockWorkspace(null)
    renderWorkspace({ newDesign: true })

    expect(await screen.findByRole('dialog', { name: 'Perfis' })).toBeInTheDocument()
    await waitFor(() => expect(screen.getByTestId('navigation-state')).toHaveTextContent('existing'))
    await userEventClickClose()
    expect(screen.queryByRole('dialog', { name: 'Perfis' })).not.toBeInTheDocument()
    expect(screen.getByTestId('navigation-state')).toHaveTextContent('existing')
  })

  it('does not prompt for an existing design or when a profile is already selected', async () => {
    mockWorkspace(null)
    renderWorkspace(null)
    await screen.findByTestId('mock-editor')
    expect(screen.queryByRole('dialog', { name: 'Perfis' })).not.toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Selecionar perfil' })).toBeInTheDocument()

    cleanup()
    mockWorkspace({ id: 'p1', name: 'Zoey', created_at: '', updated_at: '' })
    renderWorkspace({ newDesign: true })
    await screen.findByTestId('mock-editor')
    expect(screen.queryByRole('dialog', { name: 'Perfis' })).not.toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Perfil atual: Zoey' })).toBeInTheDocument()
  })
})

async function userEventClickClose() {
  await userEvent.click(screen.getByRole('button', { name: 'Fechar caixa de diálogo' }))
}
