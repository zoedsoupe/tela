import { act, render, screen } from '@testing-library/react'
import { buildCatalogue } from './catalogue'
import { BUILTIN_CATALOGUE, getSizePresets, loadSizePresets, resetSizePresetsForTests, setSizePresetsForTests, useSizePresets } from './store'

const local = buildCatalogue({ version: 1, groups: [{ slug: 'custom', label: 'Personalizados', presets: [{ slug: 'banner', label: 'Faixa', width: 1200, height: 300, unit: 'px' }] }] })!

beforeEach(() => resetSizePresetsForTests())

describe('loading the size preset catalogue', () => {
  it('resolves to the bundled catalogue without a request', async () => {
    expect(getSizePresets()).toBe(BUILTIN_CATALOGUE)
    await expect(loadSizePresets()).resolves.toBe(BUILTIN_CATALOGUE)
  })

  it('re-renders when the local catalogue changes', async () => {
    function Names() {
      return <p>{useSizePresets().presets.some((preset) => preset.id === 'banner') ? 'personalizado' : 'padrão'}</p>
    }
    render(<Names />)
    expect(screen.getByText('padrão')).toBeInTheDocument()
    await act(() => setSizePresetsForTests(local))
    expect(await screen.findByText('personalizado')).toBeInTheDocument()
  })
})
