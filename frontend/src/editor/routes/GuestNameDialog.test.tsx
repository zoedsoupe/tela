import { render, screen } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { GuestNameDialog } from "./GuestNameDialog"

describe('GuestNameDialog', () => {
  it('submits a trimmed display name', async () => {
    const user = userEvent.setup()
    const onSubmit = vi.fn()
    render(<GuestNameDialog onSubmit={onSubmit} />)

    await user.type(screen.getByTestId('shared-guest-name'), '  Pessoa  ')
    await user.click(screen.getByTestId('shared-guest-name-submit'))

    expect(onSubmit).toHaveBeenCalledWith('Pessoa')
  })

  it('does not accept whitespace as a name', async () => {
    const user = userEvent.setup()
    const onSubmit = vi.fn()
    render(<GuestNameDialog onSubmit={onSubmit} />)

    await user.type(screen.getByTestId('shared-guest-name'), '   ')
    await user.click(screen.getByTestId('shared-guest-name-submit'))

    expect(onSubmit).not.toHaveBeenCalled()
    expect(screen.getByText('Digite um nome para continuar.')).toBeInTheDocument()
  })
})
