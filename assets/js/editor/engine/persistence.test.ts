import { describe, expect, it, vi } from 'vitest'
import { createDocument } from '../document/factory'
import { addPage } from '../document/operations'
import { Persistence } from './persistence'

describe('persistence controller', () => {
  it('serializes saves and queues only the latest follow-up snapshot', async () => {
    const original = createDocument({ width: 1080, height: 1080 })
    const second = addPage(original)
    const third = addPage(second)
    let resolveFirst!: (value: { revision: number }) => void
    const save = vi.fn()
      .mockImplementationOnce(() => new Promise<{ revision: number }>((resolve) => { resolveFirst = resolve }))
      .mockResolvedValue({ revision: 3 })
    const persistence = new Persistence(original, 1, save)
    void persistence.save(second)
    void persistence.save(second)
    void persistence.save(third)
    expect(save).toHaveBeenCalledTimes(1)
    resolveFirst({ revision: 2 })
    await persistence.idle()
    expect(save).toHaveBeenCalledTimes(2)
    expect(save.mock.calls[1]?.[0].document).toBe(third)
    expect(save.mock.calls[1]?.[0].expectedRevision).toBe(2)
    expect(persistence.revision).toBe(3)
  })

  it('surfaces revision conflicts without overwriting the dirty document', async () => {
    const original = createDocument({ width: 1080, height: 1080 })
    const next = addPage(original)
    const persistence = new Persistence(original, 1, vi.fn().mockResolvedValue({ error: 'revision_conflict' }))
    await persistence.save(next)
    expect(persistence.status).toBe('conflict')
    expect(persistence.document).toBe(next)
    expect(persistence.revision).toBe(1)
  })
})
