import type { TelaDocument } from '../document/types'

export interface HistoryEntryOptions {
  label: string
  coalesceKey?: string
}

export class History {
  private past: TelaDocument[] = []
  private future: TelaDocument[] = []
  private current: TelaDocument
  private lastCoalesceKey: string | undefined

  constructor(initial: TelaDocument) {
    this.current = initial
  }

  get canUndo(): boolean {
    return this.past.length > 0
  }

  get canRedo(): boolean {
    return this.future.length > 0
  }

  get document(): TelaDocument {
    return this.current
  }

  push(document: TelaDocument, options: HistoryEntryOptions): TelaDocument {
    const coalesceKey = options.coalesceKey

    if (!coalesceKey || coalesceKey !== this.lastCoalesceKey) {
      this.past = [...this.past, this.current]
    }

    this.current = document
    this.future = []
    this.lastCoalesceKey = coalesceKey
    return this.current
  }

  undo(): TelaDocument {
    const previous = this.past[this.past.length - 1]
    if (!previous) return this.current

    this.past = this.past.slice(0, -1)
    this.future = [this.current, ...this.future]
    this.current = previous
    this.lastCoalesceKey = undefined
    return this.current
  }

  redo(): TelaDocument {
    const next = this.future[0]
    if (!next) return this.current

    this.future = this.future.slice(1)
    this.past = [...this.past, this.current]
    this.current = next
    this.lastCoalesceKey = undefined
    return this.current
  }
}
