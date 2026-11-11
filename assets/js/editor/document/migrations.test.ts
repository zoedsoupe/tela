import { describe, expect, it } from 'vitest'
import { createDocument } from './factory'
import { DocumentError, migrateDocument } from './migrations'

describe('document migrations', () => {
  it('normalizes missing pages and ids', () => {
    const doc = migrateDocument({ schemaVersion: 1, width: 1080, height: 1080 })
    expect(doc.pages).toHaveLength(1)
    expect(doc.pages[0]?.id).toBeTruthy()
    expect(doc.pages[0]?.background).toEqual({ type: 'solid', color: '#ffffff' })
  })

  it('rejects unsupported and future documents', () => {
    expect(() => migrateDocument(null)).toThrow(DocumentError)
    expect(() => migrateDocument({ schemaVersion: 99 })).toThrow('newer version')
  })

  it('preserves valid unknown animation presets for forward compatibility', () => {
    const original = createDocument({ width: 1080, height: 1080 })
    original.pages[0]!.objects.push({
      id: 'title', type: 'textbox',
      animation: { enter: { preset: 'future-effect', durationMs: 500, delayMs: 0, easing: 'ease-out' } },
    })
    const migrated = migrateDocument(original)
    expect(migrated.pages[0]?.objects[0]?.animation).toEqual(original.pages[0]?.objects[0]?.animation)
  })
})
