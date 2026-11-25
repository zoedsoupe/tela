import { act, renderHook } from '@testing-library/react'
import type { ReactNode } from 'react'
import type { BrandKit } from '@/types/api'
import { createBlankDocument } from '@/lib/document'
import { EditorProvider } from '../EditorProvider'
import { createMemoryAdapter } from '../dev/memoryAdapter'
import { EditorEngine } from '../engine/editor'
import { t } from '../strings'
import { emptyKit } from './brandOps'
import { setBrandPalette } from './brandPalette'
import { useSaveColorToBrand } from './useSaveColorToBrand'

const engines: EditorEngine[] = []

function setup(kits: BrandKit[], mode: 'local' | 'shared-view' = 'local') {
  const handle = createMemoryAdapter()
  const list = vi.fn().mockResolvedValue(kits)
  const save = vi.fn(async (kit: BrandKit) => ({ ...kit, id: kit.id || 'saved-kit' }))
  handle.adapter.services.brand = { list, save, remove: vi.fn() }
  const engine = new EditorEngine({ adapter: handle.adapter, document: createBlankDocument(800, 600), meta: { id: 'brand-test', title: 'Brand', mode }, ephemeral: true })
  engines.push(engine)
  const wrapper = ({ children }: { children: ReactNode }) => <EditorProvider engine={engine} portalRoot={document.body}>{children}</EditorProvider>
  const { result } = renderHook(() => useSaveColorToBrand(), { wrapper })
  return { engine, list, save, result }
}

afterEach(() => {
  while (engines.length) engines.pop()?.dispose()
  setBrandPalette(null)
})

describe('useSaveColorToBrand', () => {
  it('adds an opaque colour to the default kit', async () => {
    const first = { ...emptyKit('First', false), id: 'first' }
    const active = { ...emptyKit('Active', true), id: 'active' }
    const { engine, save, result } = setup([first, active])
    const saveColor = result.current
    if (!saveColor) throw new Error('Expected brand saving to be available')

    await act(() => saveColor('#ABC'))

    expect(save).toHaveBeenCalledWith(expect.objectContaining({ id: 'active', colors: [expect.objectContaining({ hex: '#aabbcc' })] }))
    expect(engine.state.toasts.at(-1)?.message).toBe(t.brand.colorSaved('Active'))
  })

  it('creates the design kit when none exists', async () => {
    const { save, result } = setup([])
    const saveColor = result.current
    if (!saveColor) throw new Error('Expected brand saving to be available')

    await act(() => saveColor('#112233'))

    expect(save).toHaveBeenCalledWith(expect.objectContaining({ name: t.brand.designKit, is_default: true, colors: [expect.objectContaining({ hex: '#112233' })] }))
  })

  it('does not save duplicates or transparent colours', async () => {
    const active = { ...emptyKit('Active', true), id: 'active', colors: [{ id: 'colour', name: 'Colour', hex: '#aabbcc' }] }
    const { engine, list, save, result } = setup([active])
    const saveColor = result.current
    if (!saveColor) throw new Error('Expected brand saving to be available')

    await act(() => saveColor('#ABC'))
    expect(save).not.toHaveBeenCalled()
    expect(engine.state.toasts.at(-1)?.message).toBe(t.brand.colorAlreadySaved)

    await act(() => saveColor('#11223380'))
    expect(list).toHaveBeenCalledTimes(1)
    expect(engine.state.toasts.at(-1)?.message).toBe(t.brand.colorTransparent)
  })

  it('is unavailable in read-only mode', () => {
    const { result } = setup([], 'shared-view')
    expect(result.current).toBeNull()
  })
})
