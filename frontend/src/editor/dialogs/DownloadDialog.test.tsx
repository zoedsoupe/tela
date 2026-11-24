import { render, screen, waitFor, within } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'
import { createBlankDocument } from '@/lib/document'
import { EditorProvider } from '../EditorProvider'
import { createMemoryAdapter } from '../dev/memoryAdapter'
import { EditorEngine } from '../engine/editor'
import { DownloadDialog } from './DownloadDialog'
import { t } from '../strings'

const { runExport, downloadFiles } = vi.hoisted(() => ({ runExport: vi.fn(), downloadFiles: vi.fn() }))

vi.mock('../engine/export/exporter', async (importOriginal) => ({
  ...(await importOriginal<typeof import('../engine/export/exporter')>()),
  runExport,
  downloadFiles,
}))

let engine: EditorEngine | null = null

function open(pageCount = 1) {
  const { adapter } = createMemoryAdapter()
  engine = new EditorEngine({ adapter, document: createBlankDocument(600, 400), meta: { id: 'design', title: 'Meu cartaz', mode: 'local' }, ephemeral: true })
  for (let index = 1; index < pageCount; index += 1) engine.pages.add()
  return render(<EditorProvider engine={engine} portalRoot={document.body}><DownloadDialog /></EditorProvider>)
}

describe('browser download dialog', () => {
  beforeEach(() => {
    localStorage.clear()
    runExport.mockReset()
    downloadFiles.mockReset()
    runExport.mockResolvedValue([{ blob: new Blob(['arquivo']), filename: 'Meu-cartaz.pdf' }])
  })

  afterEach(() => {
    engine?.dispose()
    engine = null
  })

  it('offers browser formats and print settings without server export options', async () => {
    open()
    const dialog = screen.getByRole('dialog', { name: t.dialog.downloadTitle })
    expect(within(dialog).getByRole('radio', { name: /PNG/ })).toBeInTheDocument()
    expect(within(dialog).getByRole('radio', { name: /PDF/ })).toBeInTheDocument()
    await userEvent.click(within(dialog).getByRole('radio', { name: /PDF/ }))
    expect(within(dialog).getByRole('spinbutton', { name: t.print.bleed })).toBeInTheDocument()
    expect(within(dialog).queryByText(/server|API|MCP/i)).toBeNull()
  })

  it('exports the selected PDF through the browser runner', async () => {
    open()
    const dialog = screen.getByRole('dialog', { name: t.dialog.downloadTitle })
    await userEvent.click(within(dialog).getByRole('radio', { name: /PDF/ }))
    await userEvent.click(within(dialog).getByRole('button', { name: t.dialog.downloadButton }))
    await waitFor(() => expect(runExport).toHaveBeenCalledWith(expect.anything(), expect.objectContaining({ formatId: 'pdf' })))
    expect(downloadFiles).toHaveBeenCalledOnce()
  })

  it('presents a multipage PDF as one file, not a ZIP', async () => {
    open(2)
    const dialog = screen.getByRole('dialog', { name: t.dialog.downloadTitle })
    await userEvent.click(within(dialog).getByRole('radio', { name: /PDF/ }))

    expect(within(dialog).getByTestId('download-summary')).toHaveTextContent('1 PDF')
    expect(within(dialog).getByTestId('download-summary')).not.toHaveTextContent(t.dialog.downloadInZip)
    expect(within(dialog).getByRole('button', { name: t.dialog.downloadButton })).toBeEnabled()
  })
})
