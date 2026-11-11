import type { TelaDocument } from '../document/types'

export type SaveStatus = 'saved' | 'saving' | 'conflict' | 'error'

export type SaveResult =
  | { revision: number }
  | { error: 'revision_conflict' | string }

export interface SaveRequest {
  document: TelaDocument
  expectedRevision: number
}

export type SaveFunction = (request: SaveRequest) => SaveResult | Promise<SaveResult>

export class Persistence {
  private currentDocument: TelaDocument
  private currentRevision: number
  private currentStatus: SaveStatus = 'saved'
  private pendingDocument: TelaDocument | undefined
  private running = false
  private drainPromise: Promise<void> | undefined

  constructor(
    document: TelaDocument,
    revision: number,
    private readonly saveFn: SaveFunction,
  ) {
    this.currentDocument = document
    this.currentRevision = revision
  }

  get document(): TelaDocument {
    return this.currentDocument
  }

  get revision(): number {
    return this.currentRevision
  }

  get status(): SaveStatus {
    return this.currentStatus
  }

  save(document: TelaDocument): Promise<void> {
    this.currentDocument = document
    this.pendingDocument = document
    this.currentStatus = 'saving'

    if (!this.running) this.startDrain()

    return this.drainPromise ?? Promise.resolve()
  }

  idle(): Promise<void> {
    return this.drainPromise ?? Promise.resolve()
  }

  private startDrain(): void {
    let resolveDrain!: () => void
    const drainPromise = new Promise<void>((resolve) => {
      resolveDrain = resolve
    })

    this.running = true
    this.drainPromise = drainPromise

    const settle = (): void => {
      if (this.pendingDocument !== undefined) {
        void this.flush().then(settle)
        return
      }

      this.running = false
      if (this.drainPromise === drainPromise) this.drainPromise = undefined
      resolveDrain()
    }

    void this.flush().then(settle)
  }

  private async flush(): Promise<void> {
    while (this.pendingDocument !== undefined) {
      const document = this.pendingDocument
      this.pendingDocument = undefined

      let result: SaveResult

      try {
        result = await this.saveFn({
          document,
          expectedRevision: this.currentRevision,
        })
      } catch {
        this.pendingDocument = undefined
        this.currentStatus = 'error'
        return
      }

      if ('revision' in result) {
        this.currentRevision = result.revision

        if (this.pendingDocument === undefined) {
          this.currentStatus = 'saved'
        }

        continue
      }

      this.pendingDocument = undefined
      this.currentStatus = result.error === 'revision_conflict' ? 'conflict' : 'error'
      return
    }
  }
}
