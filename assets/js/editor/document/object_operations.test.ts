import { describe, expect, it } from 'vitest'
import { createDocument } from './factory'
import { duplicateObject, moveObject, removeObject, updateObject } from './object_operations'

const documentWithObjects = () => {
  const doc = createDocument({ width: 1080, height: 1080 })
  doc.pages[0]!.objects = [
    { id: 'one', type: 'rect', fill: '#ff0000' },
    { id: 'two', type: 'textbox', text: 'Olá' },
    { id: 'three', type: 'circle' },
  ]
  return doc
}

describe('object operations', () => {
  it('updates allowed object properties without changing identity or siblings', () => {
    const original = documentWithObjects()
    const next = updateObject(original, original.pages[0]!.id, 'one', { fill: '#00ff00', id: 'forbidden', type: 'forbidden' })
    expect(next.pages[0]?.objects[0]).toMatchObject({ id: 'one', type: 'rect', fill: '#00ff00' })
    expect(next.pages[0]?.objects[1]).toBe(original.pages[0]?.objects[1])
    expect(original.pages[0]?.objects[0]?.fill).toBe('#ff0000')
  })

  it('moves objects through the z-order', () => {
    const original = documentWithObjects()
    expect(moveObject(original, original.pages[0]!.id, 'one', 'front').pages[0]?.objects.map((o) => o.id)).toEqual(['two', 'three', 'one'])
    expect(moveObject(original, original.pages[0]!.id, 'three', 'backward').pages[0]?.objects.map((o) => o.id)).toEqual(['one', 'three', 'two'])
  })

  it('duplicates with a fresh id and removes immutably', () => {
    const original = documentWithObjects()
    const duplicated = duplicateObject(original, original.pages[0]!.id, 'two')
    expect(duplicated.pages[0]?.objects.map((o) => o.id).slice(0, 3)).toEqual(['one', 'two', duplicated.pages[0]?.objects[2]?.id])
    expect(duplicated.pages[0]?.objects[2]?.id).not.toBe('two')
    const removed = removeObject(duplicated, duplicated.pages[0]!.id, 'two')
    expect(removed.pages[0]?.objects.some((object) => object.id === 'two')).toBe(false)
    expect(duplicated.pages[0]?.objects.some((object) => object.id === 'two')).toBe(true)
  })
})
