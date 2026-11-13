import { cleanup, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import type { ReactNode } from 'react'
import { afterEach, describe, expect, it } from 'vitest'
import { createBlankDocument } from '@/lib/document'
import type { EditorAdapter } from '@/types/adapter'
import type { FontFamily } from '@/types/api'
import { EditorProvider } from '../EditorProvider'
import { createMemoryAdapter } from '../dev/memoryAdapter'
import { createMemoryUserFonts } from '../dev/memoryFonts'
import { DialogHost } from '../dialogs/DialogHost'
import { EditorEngine } from '../engine/editor'
import { FontPicker } from '../toolbar/FontPicker'

const family = (name: string, id = name): FontFamily => ({
  id,
  family: name,
  category: 'sans-serif',
  scripts: ['latin'],
  is_variable: false,
  is_user_font: true,
  variants: [{ weight: 400, style: 'normal', url: `blob:${id}` }],
  popularity: 9999,
})

function setup(mode: 'local' | 'shared-edit' = 'local') {
  const handle = createMemoryAdapter()
  const fonts = handle.adapter.services.fonts
  fonts.mine = mode === 'local' ? createMemoryUserFonts({ initial: [family('Fonte da comunidade')] }) : null
  if (mode === 'shared-edit') fonts.provided = [family('Fonte compartilhada', 'shared')]
  const adapter: EditorAdapter = handle.adapter
  const engine = new EditorEngine({ adapter, document: createBlankDocument(800, 600), meta: { id: 'design', title: 'Design', mode }, ephemeral: true })
  const wrap = (children: ReactNode) => <EditorProvider engine={engine} portalRoot={document.body}>{children}<DialogHost onTitle={() => undefined} /></EditorProvider>
  return { engine, wrap }
}

describe('local font picker', () => {
  afterEach(() => {
    cleanup()
    document.body.innerHTML = ''
  })

  it('lists the local font library and opens its upload dialog', async () => {
    const { engine, wrap } = setup()
    render(wrap(<FontPicker current="" onPreview={() => undefined} onPick={() => undefined} onClose={() => undefined} />))
    expect(await screen.findByRole('option', { name: 'Fonte da comunidade' })).toBeInTheDocument()
    await userEvent.click(screen.getByTestId('font-upload-row'))
    expect(await screen.findByRole('dialog')).toBeInTheDocument()
    engine.dispose()
  })

  it('shows fonts provided by a shared design without offering upload', async () => {
    const { engine, wrap } = setup('shared-edit')
    render(wrap(<FontPicker current="" onPreview={() => undefined} onPick={() => undefined} onClose={() => undefined} />))
    expect(await screen.findByRole('option', { name: 'Fonte compartilhada' })).toBeInTheDocument()
    expect(screen.queryByTestId('font-upload-row')).toBeNull()
    engine.dispose()
  })
})
