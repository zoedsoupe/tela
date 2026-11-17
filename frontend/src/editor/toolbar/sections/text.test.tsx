import { fireEvent, render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { describe, expect, it, vi } from 'vitest'
import type { FontFamily } from '@/types/api'
import { createBlankDocument } from '@/lib/document'
import { createMemoryAdapter } from '../../dev/memoryAdapter'
import { EditorProvider } from '../../EditorProvider'
import { EditorEngine } from '../../engine/editor'
import { EMPTY_SELECTION } from '../../store/editorStore'
import { t } from '../../strings'
import { TextSection } from './text'

const family: FontFamily = {
  id: '1', family: 'Test Sans', category: 'sans-serif', scripts: ['latin'], is_variable: false,
  is_user_font: false, popularity: 1, variants: [
    { weight: 300, style: 'normal', url: '/light.woff2' },
    { weight: 600, style: 'normal', url: '/semibold.woff2' },
    { weight: 400, style: 'italic', url: '/italic.woff2' },
  ],
}

function mount(weight: number, italic = false, fontFamily = family.family, found: FontFamily | null = family) {
  const doc = createBlankDocument(800, 600)
  const engine = new EditorEngine({ adapter: createMemoryAdapter().adapter, document: doc, meta: { id: 'd', title: 'T', mode: 'local' }, ephemeral: true })
  vi.spyOn(engine.fonts, 'lookup').mockResolvedValue(found)
  const text = vi.spyOn(engine.style, 'text').mockImplementation(() => undefined)
  engine.store.setState({ selection: {
    ...EMPTY_SELECTION, pageId: doc.pages[0].id, ids: ['t1'], kinds: ['text'],
    objects: [{ id: 't1', type: 'textbox', fontFamily, fontWeight: weight, fontStyle: italic ? 'italic' : 'normal' }],
    version: 1,
  } })
  render(<EditorProvider engine={engine} portalRoot={document.body}><TextSection /></EditorProvider>)
  return { engine, text }
}

describe('font weight menu', () => {
  it('offers the selected font’s installed normal weights and applies a choice', async () => {
    const { engine, text } = mount(300)
    await waitFor(() => expect(screen.getByTestId('ed-font-weight')).toHaveTextContent(t.toolbar.weightNames[300]))
    fireEvent.click(screen.getByTestId('ed-font-weight'))
    expect(screen.getByTestId('ed-weight-300')).toHaveAttribute('aria-checked', 'true')
    expect(screen.getByTestId('ed-weight-600')).toBeEnabled()
    expect(screen.queryByTestId('ed-weight-400')).not.toBeInTheDocument()
    fireEvent.click(screen.getByTestId('ed-weight-600'))
    expect(text).toHaveBeenCalledWith({ fontWeight: 600 }, 'Change font weight')
    engine.dispose()
  })

  it('offers italic weights when italic is selected and keeps an unavailable saved weight visible', async () => {
    const { engine } = mount(600, true)
    await waitFor(() => expect(engine.fonts.lookup).toHaveBeenCalled())
    fireEvent.click(screen.getByTestId('ed-font-weight'))
    expect(screen.getByTestId('ed-weight-400')).toBeEnabled()
    expect(screen.getByTestId('ed-weight-600')).toBeDisabled()
    expect(screen.queryByTestId('ed-weight-300')).not.toBeInTheDocument()
    engine.dispose()
  })

  it('does not claim that a system font has unverified intermediate weights', async () => {
    const { engine } = mount(400, false, 'Arial', null)
    await waitFor(() => expect(engine.fonts.lookup).toHaveBeenCalledWith('Arial'))
    fireEvent.click(screen.getByTestId('ed-font-weight'))
    expect(screen.getByTestId('ed-weight-400')).toBeEnabled()
    expect(screen.getByTestId('ed-weight-700')).toBeEnabled()
    expect(screen.queryByTestId('ed-weight-500')).not.toBeInTheDocument()
    engine.dispose()
  })

  it('adjusts an unsupported weight when switching fonts and explains the change', async () => {
    const { engine, text } = mount(600)
    vi.mocked(engine.fonts.lookup).mockImplementation(async (name) => name === family.family ? family : null)
    fireEvent.click(screen.getByTestId('ed-font'))
    fireEvent.change(screen.getByTestId('font-search'), { target: { value: 'Georgia' } })
    await waitFor(() => expect(screen.getAllByRole('option').filter((row) => row.hasAttribute('data-font'))).toHaveLength(1))
    await userEvent.click(screen.getByRole('option', { name: 'Georgia' }))
    await waitFor(() => expect(text).toHaveBeenCalledWith({ fontFamily: '"Georgia", serif', fontWeight: 700 }, 'Change font'))
    expect(engine.state.toasts.at(-1)?.message).toBe(t.toolbar.fontWeightAdjusted('Georgia', t.toolbar.weightNames[600], t.toolbar.weightNames[700]))
    engine.dispose()
  })

  it('uses the nearest installed catalog face when the new family lacks the current weight', async () => {
    const inter = { ...family, family: 'Inter', variants: [{ weight: 400, style: 'normal' as const, url: '/inter-regular.woff2' }, { weight: 700, style: 'normal' as const, url: '/inter-bold.woff2' }] }
    const { engine, text } = mount(800)
    engine.fonts.remember([inter])
    engine.store.setState({ recentFonts: ['Inter'] })
    fireEvent.click(screen.getByTestId('ed-font'))
    await userEvent.click(await screen.findByRole('option', { name: 'Inter' }))
    expect(text).toHaveBeenCalledWith({ fontFamily: '"Inter", sans-serif', fontWeight: 700 }, 'Change font')
    expect(engine.state.toasts.at(-1)?.message).toBe(t.toolbar.fontWeightAdjusted('Inter', t.toolbar.weightNames[800], t.toolbar.weightNames[700]))
    engine.dispose()
  })

})
