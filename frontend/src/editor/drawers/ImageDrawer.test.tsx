import { act, render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, describe, expect, it, vi } from 'vitest'
import { setupEditor } from '../animation/testing'
import { EditorProvider } from '../EditorProvider'
import type { EditorEngine } from '../engine/editor'
import { t } from '../strings'
import { ImageDrawer } from './ImageDrawer'

describe('ImageDrawer', () => {
  let engine: EditorEngine | null = null

  afterEach(() => {
    engine?.dispose()
    engine = null
    document.body.innerHTML = ''
  })

  it('keeps local uploads and image-grid layouts available', async () => {
    const setup = await setupEditor()
    engine = setup.engine
    const insert = vi.spyOn(engine.imageGrids, 'insert').mockResolvedValue()
    const close = vi.fn()
    await act(async () => {
      render(<EditorProvider engine={engine!} portalRoot={document.body}><ImageDrawer close={close} /></EditorProvider>)
    })

    expect(screen.getByTestId('image-tab-uploads')).toHaveAttribute('aria-selected', 'true')
    expect(screen.getByTestId('image-tab-grids')).toBeVisible()
    expect(screen.queryByTestId('image-tab-stock')).toBeNull()
    await userEvent.click(screen.getByTestId('image-tab-grids'))
    expect(screen.getByRole('tabpanel', { name: t.imageDrawer.grids })).toBeVisible()
    await userEvent.click(await screen.findByTestId('grid-preset-two-columns'))
    expect(insert).toHaveBeenCalledWith('two-columns')
    expect(close).toHaveBeenCalledOnce()
  })
})
