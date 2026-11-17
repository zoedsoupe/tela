import { normalizeGuestName, readGuestName, saveGuestName } from "./sharedIdentity"

afterEach(() => localStorage.clear())

describe('shared guest identity', () => {
  it('trims and persists a display name independently for each link', () => {
    expect(saveGuestName('one', '  Pessoa  ')).toBe('Pessoa')
    expect(saveGuestName('two', 'Outra pessoa')).toBe('Outra pessoa')

    expect(readGuestName('one')).toBe('Pessoa')
    expect(readGuestName('two')).toBe('Outra pessoa')
  })

  it('rejects blank, overlong and invalid stored names', () => {
    expect(normalizeGuestName('   ')).toBeNull()
    expect(normalizeGuestName('x'.repeat(121))).toBeNull()
    expect(saveGuestName('one', '   ')).toBeNull()
    expect(readGuestName('one')).toBeNull()

    localStorage.setItem('tela.sharedGuestName.one', 'x'.repeat(121))
    expect(readGuestName('one')).toBeNull()
  })
})
