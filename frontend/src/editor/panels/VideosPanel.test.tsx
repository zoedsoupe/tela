import { act, render, screen } from '@testing-library/react'
import { afterEach, describe, expect, it } from 'vitest'
import { setupEditor } from '../animation/testing'
import { EditorProvider } from '../EditorProvider'
import type { EditorEngine } from '../engine/editor'
import { VideosPanel } from './VideosPanel'

describe('VideosPanel', () => {
  let engine: EditorEngine | null = null

  afterEach(() => {
    engine?.dispose()
    engine = null
    document.body.innerHTML = ''
  })

  it('shows browser-checked local video uploads without a stock tab', async () => {
    const setup = await setupEditor()
    engine = setup.engine
    await act(async () => {
      render(<EditorProvider engine={engine!} portalRoot={document.body}><VideosPanel close={() => undefined} /></EditorProvider>)
    })
    expect(screen.getByTestId('videos-panel')).toBeInTheDocument()
    expect(screen.getByTestId('video-upload-zone')).toHaveTextContent('O navegador verifica a reprodução')
    expect(screen.queryByTestId('video-tab-stock')).toBeNull()
  })
})
