import { screen, waitFor } from "@testing-library/react"
import userEvent from "@testing-library/user-event"
import { createCommentsRig } from "../panels/commentsTesting"
import { ShareDialog } from "./ShareDialog"

describe('ShareDialog', () => {
  it('creates links with seven-day expiration by default and shows their expiry', async () => {
    const user = userEvent.setup()
    const rig = createCommentsRig()
    rig.renderIn(<ShareDialog />)

    expect(screen.getByTestId('share-expiry')).toHaveValue('7d')
    await user.click(screen.getByTestId('share-create'))

    await waitFor(() => expect(screen.getByTestId('share-link')).toBeInTheDocument())
    const links = await rig.engine.adapter.services.sharing?.list()
    expect(links).toHaveLength(1)
    expect(links?.[0].expires_at).toEqual(expect.any(String))
    expect(Date.parse(links?.[0].expires_at ?? '') - Date.now()).toBeGreaterThan(6 * 24 * 60 * 60 * 1000)
    expect(screen.getByText(/^Expira /)).toBeInTheDocument()

    rig.engine.dispose()
  })

  it('allows a link without expiration', async () => {
    const user = userEvent.setup()
    const rig = createCommentsRig()
    rig.renderIn(<ShareDialog />)

    await user.selectOptions(screen.getByTestId('share-expiry'), 'never')
    await user.click(screen.getByTestId('share-create'))

    await waitFor(() => expect(screen.getByText('Sem expiração')).toBeInTheDocument())
    const links = await rig.engine.adapter.services.sharing?.list()
    expect(links?.[0]).toMatchObject({ expires_at: null, revoked_at: null, is_active: true })

    rig.engine.dispose()
  })
})
