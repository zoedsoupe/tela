import { describe, expect, it } from 'vitest'
import { absoluteUrl, SHARE_EXPIRIES, SHARE_ROLES, shareLinkStatus } from './shareOps'

describe('share links', () => {
  it('builds a same-origin share URL', () => {
    expect(absoluteUrl('/s/design-token', 'https://tela.example')).toBe('https://tela.example/s/design-token')
  })

  it('only offers the supported capability roles and expiration choices', () => {
    expect(SHARE_ROLES).toEqual(['view', 'comment', 'edit'])
    expect(SHARE_EXPIRIES).toEqual(['never', '1d', '7d', '30d'])
  })

  it('distinguishes expired, revoked and active links', () => {
    const now = Date.parse('2026-11-17T12:00:00Z')
    expect(shareLinkStatus({ is_active: false, expires_at: '2026-11-17T11:59:59Z', revoked_at: null }, now)).toBe('expired')
    expect(shareLinkStatus({ is_active: false, expires_at: '2026-11-17T11:59:59Z', revoked_at: '2026-11-17T11:00:00Z' }, now)).toBe('off')
    expect(shareLinkStatus({ is_active: false, expires_at: null, revoked_at: null }, now)).toBe('off')
    expect(shareLinkStatus({ is_active: true, expires_at: '2026-11-18T12:00:00Z', revoked_at: null }, now)).toBe('active')
  })
})
