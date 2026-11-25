import { render, screen } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { RELEASE_NOTES, RELEASE_NOTES_STORAGE_KEY } from './releaseNotes'
import { useWhatsNew } from './useWhatsNew'
import { WhatsNewDialog } from './WhatsNewDialog'

function Harness() {
  const whatsNew = useWhatsNew()
  return (
    <>
      <button type="button" onClick={whatsNew.reopen}>Novidades</button>
      <WhatsNewDialog open={whatsNew.open} onClose={whatsNew.dismiss} />
    </>
  )
}

describe('WhatsNewDialog', () => {
  beforeEach(() => localStorage.removeItem(RELEASE_NOTES_STORAGE_KEY))

  it('opens for a new version and remembers it when dismissed', async () => {
    render(<Harness />)

    expect(screen.getByRole('dialog', { name: RELEASE_NOTES.title })).toBeInTheDocument()
    expect(screen.getByText(`Novidades da versão ${RELEASE_NOTES.version}`)).toBeInTheDocument()
    await userEvent.click(screen.getByRole('button', { name: 'Entendi' }))

    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
    expect(localStorage.getItem(RELEASE_NOTES_STORAGE_KEY)).toBe(RELEASE_NOTES.version)
  })

  it('does not open again after the version was seen', () => {
    localStorage.setItem(RELEASE_NOTES_STORAGE_KEY, RELEASE_NOTES.version)
    render(<Harness />)

    expect(screen.queryByRole('dialog')).not.toBeInTheDocument()
  })

  it('opens for a different version and can always be reopened', async () => {
    localStorage.setItem(RELEASE_NOTES_STORAGE_KEY, '2026.10')
    render(<Harness />)
    await userEvent.click(screen.getByRole('button', { name: 'Entendi' }))
    await userEvent.click(screen.getByRole('button', { name: 'Novidades' }))

    expect(screen.getByRole('dialog', { name: RELEASE_NOTES.title })).toBeInTheDocument()
  })
})
