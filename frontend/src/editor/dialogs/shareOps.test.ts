import { describe, expect, it } from 'vitest'
import { absoluteUrl, SHARE_ROLES } from './shareOps'

describe('share links', () => {
  it('builds a same-origin share URL', () => {
    expect(absoluteUrl('/s/design-token', 'https://tela.example')).toBe('https://tela.example/s/design-token')
  })

  it('only offers the supported capability roles', () => {
    expect(SHARE_ROLES).toEqual(['view', 'comment', 'edit'])
  })
})
