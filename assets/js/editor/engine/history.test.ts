import { describe, expect, it } from 'vitest'
import { createDocument } from '../document/factory'
import { addPage } from '../document/operations'
import { History } from './history'

describe('editor history', () => {
  it('undoes and redoes immutable document states', () => {
    const original = createDocument({ width: 1080, height: 1080 })
    const next = addPage(original)
    const history = new History(original)
    history.push(next, { label: 'Add page' })
    expect(history.canUndo).toBe(true)
    expect(history.undo()).toBe(original)
    expect(history.canRedo).toBe(true)
    expect(history.redo()).toBe(next)
  })

  it('coalesces edits sharing a key into one undo step', () => {
    const original = createDocument({ width: 1080, height: 1080 })
    const second = addPage(original)
    const third = addPage(second)
    const history = new History(original)
    history.push(second, { label: 'Change duration', coalesceKey: 'duration' })
    history.push(third, { label: 'Change duration', coalesceKey: 'duration' })
    expect(history.undo()).toBe(original)
    expect(history.canRedo).toBe(true)
  })
})
