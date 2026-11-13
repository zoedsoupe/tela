/** Autosave and save state. The editor delegates persistence to its adapter. */
import type { SaveState } from "@/types/adapter"
import type { DoryDocument } from "@/types/document"
import type { EditorEngine } from "./editor"
import { renderPageToCanvas, canvasToBlob } from "./render"
import { pageSize } from "./docOps"
import { assertSaveable } from "./assets"

export const AUTOSAVE_DELAY_MS = 1500
export const THUMBNAIL_WIDTH = 480

export function isRevisionConflict(err: unknown): boolean {
  return err instanceof Error && err.name === "RevisionConflictError"
}

export interface PersistenceCallbacks {
  onSaveStateChange?: (state: SaveState) => void
  onConflict?: () => void
}

export class PersistenceController {
  private timer: ReturnType<typeof setTimeout> | null = null
  private saving: Promise<void> | null = null
  private again = false
  private lastSavedDoc: DoryDocument
  private lastSavedTitle: string
  private thumbnailPage: unknown = null
  private callbacks: PersistenceCallbacks = {}
  private disposers: (() => void)[] = []
  private disposed = false

  constructor(private readonly engine: EditorEngine) {
    this.lastSavedDoc = engine.state.doc
    this.lastSavedTitle = engine.state.title
  }

  start(callbacks: PersistenceCallbacks): void {
    this.disposed = false
    this.callbacks = callbacks
    if (this.engine.readOnly) return
    this.disposers.push(this.engine.store.subscribe((state, previous) => {
      if (state.doc !== previous.doc || state.title !== previous.title) this.onChange()
    }))
    const flush = (): void => {
      if (this.isDirty()) void this.flush()
    }
    const onVisibility = (): void => {
      if (document.visibilityState === 'hidden') flush()
    }
    document.addEventListener('visibilitychange', onVisibility)
    window.addEventListener('pagehide', flush)
    window.addEventListener('beforeunload', flush)
    this.disposers.push(() => {
      document.removeEventListener('visibilitychange', onVisibility)
      window.removeEventListener('pagehide', flush)
      window.removeEventListener('beforeunload', flush)
    })
  }

  get savedDocument(): DoryDocument {
    return this.lastSavedDoc
  }

  isDirty(): boolean {
    const state = this.engine.state
    return state.doc !== this.lastSavedDoc || state.title !== this.lastSavedTitle
  }

  adoptTitle(title: string): void {
    this.lastSavedTitle = title
  }

  private setState(state: SaveState): void {
    this.engine.store.setState({ save: state, conflict: state.status === 'conflict' })
    this.callbacks.onSaveStateChange?.(state)
  }

  private onChange(): void {
    if (this.disposed || this.engine.readOnly) return
    if (this.engine.state.save.status === 'conflict') return
    if (!this.saving) this.setState({ status: 'dirty' })
    if (this.timer) clearTimeout(this.timer)
    this.timer = setTimeout(() => void this.flush(), AUTOSAVE_DELAY_MS)
  }

  async saveNow(): Promise<void> {
    if (this.engine.readOnly) return
    if (this.timer) {
      clearTimeout(this.timer)
      this.timer = null
    }
    if (this.engine.state.save.status === 'conflict') this.engine.store.setState({ conflict: false })
    await this.flush(true)
  }

  private async flush(force = false): Promise<void> {
    if (this.timer) {
      clearTimeout(this.timer)
      this.timer = null
    }
    if (this.saving) {
      this.again = true
      await this.saving
      return
    }
    if (!force && !this.isDirty()) return
    if (!force && this.engine.state.save.status === 'conflict') return
    const run = this.perform().finally(() => {
      this.saving = null
    })
    this.saving = run
    await run
    if (this.again && !this.disposed) {
      this.again = false
      if (this.isDirty() && this.engine.state.save.status !== 'conflict' && this.engine.state.save.status !== 'error') await this.flush()
    }
  }

  private async perform(): Promise<void> {
    const engine = this.engine
    const snapshotDoc = engine.state.doc
    const snapshotTitle = engine.state.title
    this.setState({ status: 'saving' })
    try {
      const document = await engine.assets.persistInline(snapshotDoc)
      assertSaveable(document)
      const thumbnail = await this.thumbnail(snapshotDoc)
      const result = await engine.adapter.save({ document, title: snapshotTitle, thumbnail })
      this.lastSavedDoc = snapshotDoc
      this.lastSavedTitle = snapshotTitle
      if (thumbnail || this.thumbnailPage === null) this.thumbnailPage = snapshotDoc.pages[0]
      const stillDirty = this.isDirty()
      this.setState(stillDirty ? { status: 'dirty' } : engine.state.mode === 'local' ? { status: 'local', savedAt: result.savedAt } : { status: 'saved', savedAt: result.savedAt })
      if (stillDirty) this.onChange()
    } catch (error) {
      if (isRevisionConflict(error)) {
        this.setState({ status: 'conflict' })
        this.callbacks.onConflict?.()
      } else {
        this.setState({ status: 'error', message: error instanceof Error ? error.message : "Não foi possível salvar o design." })
      }
    }
  }

  private async thumbnail(doc: DoryDocument): Promise<Blob | undefined> {
    const first = doc.pages[0]
    if (this.thumbnailPage === first) return undefined
    try {
      const size = pageSize(doc, first)
      const canvas = await renderPageToCanvas(first, size, this.engine.loadContext, { multiplier: Math.min(1, THUMBNAIL_WIDTH / size.width) })
      return await canvasToBlob(canvas, "image/webp", 0.85)
    } catch {
      return undefined
    }
  }

  dispose(): void {
    this.disposed = true
    if (this.timer) clearTimeout(this.timer)
    for (const off of this.disposers) off()
    this.disposers = []
  }
}
