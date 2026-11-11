import { describe, expect, it } from 'vitest'
import { createDocument, createPage } from './factory'
import { addPage, deletePage, duplicatePage, reorderPage } from './operations'

const documentWithPages = () => ({
  ...createDocument({ width: 1080, height: 1350 }),
  pages: [createPage(), createPage(), createPage()],
})

describe('document page operations', () => {
  it('creates a versioned document with one blank page', () => {
    const doc = createDocument({ width: 1080.4, height: 1350.2, presetId: 'post-instagram' })
    expect(doc.schemaVersion).toBe(1)
    expect(doc.width).toBe(1080)
    expect(doc.height).toBe(1350)
    expect(doc.pages).toHaveLength(1)
    expect(doc.pages[0]?.objects).toEqual([])
    expect(doc.meta?.presetId).toBe('post-instagram')
  })

  it('adds pages immutably after the requested page', () => {
    const original = documentWithPages()
    const next = addPage(original, original.pages[0]!.id)
    expect(next.pages).toHaveLength(4)
    expect(next.pages[1]?.id).not.toBe(original.pages[1]?.id)
    expect(next.pages[0]).toBe(original.pages[0])
    expect(original.pages).toHaveLength(3)
  })

  it('duplicates content with fresh page and object ids', () => {
    const original = documentWithPages()
    original.pages[0]!.objects.push({ id: 'original-object', type: 'rect' })
    const next = duplicatePage(original, original.pages[0]!.id)
    expect(next.pages).toHaveLength(4)
    expect(next.pages[1]?.id).not.toBe(original.pages[0]?.id)
    expect(next.pages[1]?.objects[0]?.id).not.toBe('original-object')
    expect(next.pages[1]?.objects[0]?.type).toBe('rect')
    expect(original.pages[0]?.objects[0]?.id).toBe('original-object')
  })

  it('keeps at least one page', () => {
    const doc = createDocument({ width: 1080, height: 1080 })
    expect(() => deletePage(doc, doc.pages[0]!.id)).toThrow('at least one page')
  })

  it('reorders pages without mutating the original order', () => {
    const original = documentWithPages()
    const thirdId = original.pages[2]!.id
    const next = reorderPage(original, thirdId, 0)
    expect(next.pages[0]?.id).toBe(thirdId)
    expect(original.pages[2]?.id).toBe(thirdId)
  })
})
