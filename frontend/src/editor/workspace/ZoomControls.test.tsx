import { act, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { createBlankDocument } from '@/lib/document'
import { createMemoryAdapter } from '../dev/memoryAdapter'
import { EditorProvider } from '../EditorProvider'
import { EditorEngine } from '../engine/editor'
import { t } from '../strings'
import { createEditorStore, writePrefs } from '../store/editorStore'
import { ZoomControls } from './ZoomControls'

function setup() {
  const engine = new EditorEngine({ adapter: createMemoryAdapter().adapter, document: createBlankDocument(800, 600), meta: { id: 'grid-test', title: 'Grid', mode: 'local' }, ephemeral: true })
  render(<EditorProvider engine={engine} portalRoot={document.body}><ZoomControls /></EditorProvider>)
  return engine
}

describe('ZoomControls grid size', () => {
  afterEach(() => {
    localStorage.clear()
  })

  it('shows a custom spacing field only while the visual grid is enabled', async () => {
    const engine = setup()
    expect(screen.queryByRole('textbox', { name: t.workspace.gridSize })).toBeNull()

    act(() => engine.patchUi({ grid: true }))
    const input = screen.getByRole('textbox', { name: t.workspace.gridSize })
    await userEvent.clear(input)
    await userEvent.type(input, '32')
    await userEvent.tab()

    expect(engine.state.ui.gridSize).toBe(32)
    expect(engine.gridSize).toBe(32)
    act(() => engine.patchUi({ grid: false }))
    expect(screen.queryByRole('textbox', { name: t.workspace.gridSize })).toBeNull()
    engine.dispose()
  })

  it('invalidates the page overlay when the spacing changes', async () => {
    const engine = setup()
    const host = document.createElement('div')
    document.body.append(host)
    const pageId = engine.state.doc.pages[0].id
    engine.mountPage(pageId, host)
    const view = await engine.whenView(pageId)
    const invalidate = vi.spyOn(view, 'invalidateOverlay')
    engine.start()

    act(() => engine.patchUi({ gridSize: 36 }))
    expect(invalidate).toHaveBeenCalled()
    engine.dispose()
    host.remove()
  })

  it('restores and saves the spacing with the other editor preferences', () => {
    localStorage.setItem('tela.editor.prefs.v1', JSON.stringify({ gridSize: 44 }))
    const store = createEditorStore({ doc: createBlankDocument(800, 600), title: 'Grid', mode: 'local' })
    expect(store.getState().ui.gridSize).toBe(44)

    store.setState((state) => ({ ui: { ...state.ui, gridSize: 56 } }))
    writePrefs(store.getState())
    const saved = JSON.parse(localStorage.getItem('tela.editor.prefs.v1') ?? '{}') as { gridSize?: number }
    expect(saved.gridSize).toBe(56)
  })
})
