import { render, screen } from "@testing-library/react"
import { describe, expect, it } from "vitest"
import { EditorCredit } from "./EditorCredit"

describe('editor credit', () => {
  it('shows the complete attribution as a wrapping external link', () => {
    render(<EditorCredit />)

    const link = screen.getByRole('link', {
      name: 'Doory by Siam, creator and maintainer of Doory, https://github.com/shaongitbd/doory',
    })
    expect(link).toHaveAttribute('href', 'https://github.com/shaongitbd/doory')
    expect(link).toHaveAttribute('target', '_blank')
    expect(link).toHaveAttribute('rel', 'noreferrer')
  })
})
