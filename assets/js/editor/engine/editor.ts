import { Canvas, Ellipse, FabricImage, IText, Point, Rect, type FabricObject } from 'fabric'
import { addPage, deletePage, duplicatePage, reorderPage } from '../document/operations'
import { duplicateObject, moveObject, removeObject, updateObject, type ObjectMove } from '../document/object_operations'
import { createPage, newId } from '../document/factory'
import { migrateDocument } from '../document/migrations'
import type { DocObject, TelaDocument, TelaPage } from '../document/types'
import { History } from './history'
import { Persistence, type SaveRequest, type SaveResult, type SaveStatus } from './persistence'
import { applyObjectLockState, fitCanvasToPage, loadPage } from './page_canvas'
import { downloadDataUrl, renderPageDataUrl, type RasterFormat } from './render'
import { replaceActivePage, serializeDocument, type FabricDocumentObject } from './serialization'

type LiveEventReply = { status?: string; revision?: number; reason?: string }
type PushEvent = (event: string, payload: Record<string, unknown>, callback?: (reply: LiveEventReply) => void) => void
type CanvasCommand = Record<string, unknown> & { action?: string; id?: string; objectId?: string; pageId?: string }

const DEBOUNCE_MS = 550

export class EditorEngine {
  readonly canvas: Canvas
  private document: TelaDocument
  private activePageId: string
  private history: History
  private persistence: Persistence
  private readonly pushEvent: PushEvent
  private readonly host: HTMLElement
  private readonly resizeObserver: ResizeObserver
  private readonly handlers: Array<() => void> = []
  private saveTimer: ReturnType<typeof setTimeout> | undefined
  private loadToken = 0
  private suppressCommits = false
  private disposed = false
  private selectedId: string | undefined
  private renderedPageId: string | undefined

  constructor(element: HTMLCanvasElement, pushEvent: PushEvent) {
    this.pushEvent = pushEvent
    this.host = element.parentElement?.parentElement ?? element.parentElement ?? element
    this.document = migrateDocument({ schemaVersion: 1, width: 1080, height: 1080, pages: [] })
    this.activePageId = this.document.pages[0]!.id
    this.history = new History(this.document)
    this.persistence = new Persistence(this.document, 1, async () => ({ error: 'editor_not_ready' }))
    this.canvas = new Canvas(element, {
      width: 800,
      height: 600,
      preserveObjectStacking: true,
      selection: true,
      backgroundColor: 'transparent',
      renderOnAddRemove: true,
    })
    this.bindCanvasEvents()
    this.bindNavigation()
    this.resizeObserver = new ResizeObserver(() => this.fit())
    this.resizeObserver.observe(this.host)
  }

  async initialize(input: unknown, revision: number, activePageId?: string): Promise<void> {
    this.document = migrateDocument(input)
    this.history = new History(this.document)
    this.persistence = new Persistence(this.document, revision, (request) => this.save(request))
    this.activePageId = this.document.pages.some((page) => page.id === activePageId)
      ? activePageId!
      : this.document.pages[0]!.id
    await this.renderActivePage()
    this.sendPageSummary()
    this.sendLayerSummary()
    this.sendSelection()
    this.emitSaveStatus('saved')
  }

  handleAddElement(command: CanvasCommand): void {
    void this.addElement(command)
  }

  handleUpdateActive(command: CanvasCommand): void {
    const action = command.action
    if (action === 'zoom_in') this.zoomBy(1.2)
    else if (action === 'zoom_out') this.zoomBy(1 / 1.2)
    else if (action === 'zoom_fit') this.fit()
    else this.updateSelected(command)
  }

  handleLayerAction(command: CanvasCommand): void {
    const action = command.action
    const objectId = String(command.objectId ?? command.id ?? '')
    const page = this.activePage()
    if (!page || !objectId) return
    const object = page.objects.find((candidate) => candidate.id === objectId)

    if (action === 'select') {
      const fabricObject = this.findFabricObject(objectId)
      if (fabricObject) this.canvas.setActiveObject(fabricObject)
      else this.canvas.discardActiveObject()
      this.canvas.requestRenderAll()
      this.sendSelection()
      this.sendLayerSummary()
      return
    }

    if (!object) return

    if (action === 'delete') {
      this.commit(removeObject(this.document, page.id, objectId), 'Delete layer', true)
      return
    }
    if (action === 'duplicate') {
      this.commit(duplicateObject(this.document, page.id, objectId), 'Duplicate layer', true)
      return
    }
    if (action === 'toggle_lock' || action === 'lock') {
      const next = updateObject(this.document, page.id, objectId, { locked: action === 'lock' ? true : !object.locked })
      this.commit(next, 'Lock layer')
      return
    }
    if (action === 'toggle_visible' || action === 'hide' || action === 'show') {
      const visible = action === 'hide' ? false : action === 'show' ? true : object.visible === false
      this.commit(updateObject(this.document, page.id, objectId, { visible }), 'Change layer visibility')
      return
    }
    if (action === 'front' || action === 'back' || action === 'forward' || action === 'backward') {
      this.commit(moveObject(this.document, page.id, objectId, action as ObjectMove), 'Arrange layer', true)
    }
  }

  handlePageAction(command: CanvasCommand): void {
    const action = command.action
    const pageId = String(command.pageId ?? this.activePageId)
    let next = this.document

    try {
      if (action === 'add') {
        next = addPage(this.document, this.activePageId)
        this.activePageId = next.pages[next.pages.findIndex((page) => page.id === this.activePageId) + 1]!.id
      } else if (action === 'duplicate') {
        next = duplicatePage(this.document, pageId)
        this.activePageId = next.pages[next.pages.findIndex((page) => page.id === pageId) + 1]!.id
      } else if (action === 'delete') {
        const oldIndex = this.document.pages.findIndex((page) => page.id === pageId)
        next = deletePage(this.document, pageId)
        if (this.activePageId === pageId) this.activePageId = next.pages[Math.min(oldIndex, next.pages.length - 1)]!.id
      } else if (action === 'select') {
        if (this.document.pages.some((page) => page.id === pageId)) this.activePageId = pageId
      } else if (action === 'reorder') {
        const destination = Number(command.destination)
        next = reorderPage(this.document, pageId, destination)
      } else {
        return
      }

      if (next !== this.document) this.commit(next, action === 'reorder' ? 'Reorder pages' : `${action} page`)
      else void this.renderActivePage()
    } catch (error) {
      this.notify(error instanceof Error ? error.message : 'Page action failed')
    }
  }

  handleHistoryAction(command: CanvasCommand): void {
    if (command.action === 'undo' && this.history.canUndo) this.applyHistoryDocument(this.history.undo())
    if (command.action === 'redo' && this.history.canRedo) this.applyHistoryDocument(this.history.redo())
  }

  async handleExport(command: CanvasCommand): Promise<void> {
    const format = command.format
    if (format !== 'png' && format !== 'jpg') {
      this.exportStatus(`${String(format).toUpperCase()} export is planned for a dedicated export task.`)
      return
    }

    const multiplier = Number(command.multiplier)
    if (multiplier !== 1 && multiplier !== 2 && multiplier !== 3) {
      this.exportStatus('Choose a 1×, 2×, or 3× raster export size.')
      return
    }

    const page = this.activePage()
    if (!page) return
    try {
      const dataUrl = await renderPageDataUrl(this.document, page, format as RasterFormat, multiplier)
      downloadDataUrl(dataUrl, `tela-${page.name || 'pagina'}.${format}`)
      this.exportStatus(`${format.toUpperCase()} export ready at ${multiplier}×.`)
    } catch (error) {
      this.exportStatus(error instanceof Error ? error.message : 'Could not export this page.')
    }
  }

  dispose(): void {
    this.disposed = true
    if (this.saveTimer) clearTimeout(this.saveTimer)
    this.resizeObserver.disconnect()
    for (const remove of this.handlers) remove()
    this.canvas.dispose()
  }

  private bindCanvasEvents(): void {
    this.canvas.on('object:added', ({ target }) => {
      if (!this.suppressCommits && target && !(target as FabricDocumentObject).__editorBackground) this.commitCanvas('Add object')
    })
    this.canvas.on('object:removed', ({ target }) => {
      if (!this.suppressCommits && target && !(target as FabricDocumentObject).__editorBackground) this.commitCanvas('Remove object')
    })
    this.canvas.on('object:modified', () => {
      if (!this.suppressCommits) this.commitCanvas('Modify object')
    })
    this.canvas.on('selection:created', () => this.onSelectionChanged())
    this.canvas.on('selection:updated', () => this.onSelectionChanged())
    this.canvas.on('selection:cleared', () => this.onSelectionChanged())
    this.canvas.on('mouse:wheel', (event) => {
      const wheel = event.e as WheelEvent
      const zoom = Math.min(4, Math.max(0.05, this.canvas.getZoom() * Math.pow(0.999, wheel.deltaY)))
      this.canvas.zoomToPoint(new Point(wheel.offsetX, wheel.offsetY), zoom)
      wheel.preventDefault()
      wheel.stopPropagation()
    })

    let panning = false
    let lastX = 0
    let lastY = 0
    this.canvas.on('mouse:down', (event) => {
      const pointer = event.e as MouseEvent
      if (!pointer.altKey && pointer.button !== 1) return
      panning = true
      lastX = pointer.clientX
      lastY = pointer.clientY
      this.canvas.selection = false
      this.canvas.setCursor('grabbing')
    })
    this.canvas.on('mouse:move', (event) => {
      if (!panning) return
      const pointer = event.e as MouseEvent
      this.canvas.relativePan(new Point(pointer.clientX - lastX, pointer.clientY - lastY))
      lastX = pointer.clientX
      lastY = pointer.clientY
    })
    this.canvas.on('mouse:up', () => {
      if (!panning) return
      panning = false
      this.canvas.selection = true
      this.canvas.setCursor('default')
    })
  }

  private bindNavigation(): void {
    const onKeyDown = (event: KeyboardEvent): void => {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'z') {
        event.preventDefault()
        this.handleHistoryAction({ action: event.shiftKey ? 'redo' : 'undo' })
      }
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'y') {
        event.preventDefault()
        this.handleHistoryAction({ action: 'redo' })
      }
      if (event.key === 'Delete' || event.key === 'Backspace') {
        const selected = this.canvas.getActiveObject() as FabricDocumentObject | undefined
        if (selected?.id && !selected.locked) this.handleLayerAction({ action: 'delete', objectId: selected.id })
      }
    }
    window.addEventListener('keydown', onKeyDown)
    this.handlers.push(() => window.removeEventListener('keydown', onKeyDown))
  }

  private async addElement(command: CanvasCommand): Promise<void> {
    const action = String(command.action ?? command.type ?? '')
    const left = this.document.width / 2 - 100
    const top = this.document.height / 2 - 50
    let object: FabricObject | undefined

    if (action === 'text') {
      object = new IText('Seu texto', { left, top, fontSize: 56, fill: '#202124', fontFamily: 'DM Sans' })
    } else if (action === 'rect') {
      object = new Rect({ left, top, width: 220, height: 140, fill: 'transparent', stroke: '#202124', strokeWidth: 3 })
    } else if (action === 'ellipse') {
      object = new Ellipse({ left, top, rx: 100, ry: 70, fill: 'transparent', stroke: '#202124', strokeWidth: 3 })
    } else if (action === 'image') {
      const source = typeof command.src === 'string' ? command.src.trim() : ''
      if (!source) {
        this.notify('Enter an image URL first.')
        return
      }
      try {
        object = await FabricImage.fromURL(source, { crossOrigin: 'anonymous' })
        object.set({ left, top, scaleX: Math.min(1, 360 / (object.width || 360)), scaleY: Math.min(1, 360 / (object.width || 360)) })
        ;(object as FabricDocumentObject).docSrc = source
      } catch {
        this.notify('The image could not be loaded. Check the URL and its cross-origin policy.')
        return
      }
    }

    if (!object) return
    const fabricObject = object as FabricDocumentObject
    fabricObject.id = newId()
    fabricObject.name = action === 'text' ? 'Texto' : action === 'image' ? 'Imagem' : action === 'ellipse' ? 'Elipse' : 'Retângulo'
    fabricObject.locked = false
    fabricObject.visible = true
    this.canvas.add(object)
    this.canvas.setActiveObject(object)
    this.canvas.requestRenderAll()
  }

  private updateSelected(command: CanvasCommand): void {
    const selected = this.canvas.getActiveObject() as FabricDocumentObject | undefined
    if (!selected?.id || selected.locked) return
    const page = this.activePage()
    if (!page) return
    const property = typeof command.property === 'string' ? command.property : undefined
    const action = command.action
    const properties = property
      ? { [property]: this.coerceValue(command.value, property) }
      : this.objectProperties(command)
    if (action === 'delete') {
      this.handleLayerAction({ action: 'delete', objectId: selected.id })
      return
    }
    if (Object.keys(properties).length === 0) return
    this.commit(updateObject(this.document, page.id, selected.id, properties as Partial<DocObject>), 'Update properties')
  }

  private objectProperties(input: Record<string, unknown>): Record<string, unknown> {
    const allowed = new Set(['left', 'top', 'scaleX', 'scaleY', 'angle', 'fill', 'stroke', 'strokeWidth', 'opacity', 'fontSize', 'fontFamily', 'text', 'width', 'height'])
    return Object.fromEntries(Object.entries(input).filter(([key]) => allowed.has(key)))
  }

  private coerceValue(value: unknown, property: string): unknown {
    if (['left', 'top', 'scaleX', 'scaleY', 'angle', 'strokeWidth', 'opacity', 'fontSize', 'width', 'height'].includes(property)) {
      const number = Number(value)
      return Number.isFinite(number) ? number : value
    }
    return value
  }

  private commitCanvas(label: string): void {
    const next = serializeDocument(this.document, this.canvas, this.activePageId)
    this.commit(next, label)
  }

  private commit(next: TelaDocument, label: string, refreshCanvas = false): void {
    if (this.disposed) return
    this.document = this.history.push(next, { label })
    const activePage = this.activePage()
    if (refreshCanvas || !activePage || activePage.id !== this.renderedPageId) {
      void this.renderActivePage()
    } else {
      this.applyLockStateToCanvas()
      this.sendLayerSummary()
      this.sendPageSummary()
    }
    this.scheduleSave()
  }

  private applyHistoryDocument(document: TelaDocument): void {
    this.document = document
    if (!this.document.pages.some((page) => page.id === this.activePageId)) this.activePageId = this.document.pages[0]!.id
    void this.renderActivePage().then(() => this.scheduleSave())
  }

  private async renderActivePage(): Promise<void> {
    const token = ++this.loadToken
    const page = this.activePage()
    if (!page) return
    this.suppressCommits = true
    try {
      await loadPage(this.canvas, page, this.document)
      if (token !== this.loadToken || this.disposed) return
      this.renderedPageId = page.id
      this.fit()
    } finally {
      this.suppressCommits = false
    }
    this.selectedId = undefined
    this.sendSelection()
    this.sendLayerSummary()
    this.sendPageSummary()
  }

  private scheduleSave(): void {
    if (this.saveTimer) clearTimeout(this.saveTimer)
    this.emitSaveStatus('dirty')
    this.saveTimer = setTimeout(() => {
      this.emitSaveStatus('saving')
      void this.persistence.save(this.document).then(() => this.emitSaveStatus(this.persistence.status))
    }, DEBOUNCE_MS)
  }

  private async save(request: SaveRequest): Promise<SaveResult> {
    return new Promise((resolve) => {
      this.pushEvent('design:save', {
        document: request.document,
        expected_revision: request.expectedRevision,
      }, (reply) => {
        if (reply.status === 'saved' && typeof reply.revision === 'number') resolve({ revision: reply.revision })
        else if (reply.status === 'conflict') resolve({ error: 'revision_conflict' })
        else resolve({ error: reply.reason ?? 'save_failed' })
      })
    })
  }

  private activePage(): TelaPage | undefined {
    return this.document.pages.find((page) => page.id === this.activePageId)
  }

  private findFabricObject(id: string): FabricObject | undefined {
    return this.canvas.getObjects().find((object) => (object as FabricDocumentObject).id === id)
  }

  private applyLockStateToCanvas(): void {
    const page = this.activePage()
    if (!page) return
    for (const object of this.canvas.getObjects()) {
      const serialized = page.objects.find((candidate) => candidate.id === (object as FabricDocumentObject).id)
      if (!serialized) continue
      Object.assign(object, serialized)
      applyObjectLockState(object as FabricDocumentObject)
      object.setCoords()
    }
    this.canvas.requestRenderAll()
    this.sendLayerSummary()
  }

  private onSelectionChanged(): void {
    const selected = this.canvas.getActiveObject() as FabricDocumentObject | undefined
    this.selectedId = typeof selected?.id === 'string' ? selected.id : undefined
    this.sendSelection()
    this.sendLayerSummary()
  }

  private sendSelection(): void {
    const object = this.selectedId ? this.findFabricObject(this.selectedId) as FabricDocumentObject | undefined : undefined
    const selection = object ? {
      id: object.id,
      type: object.type,
      name: object.name,
      width: Math.round((object.width ?? 0) * (object.scaleX ?? 1)),
      height: Math.round((object.height ?? 0) * (object.scaleY ?? 1)),
      left: object.left,
      top: object.top,
      angle: object.angle,
      fill: object.fill,
      fontSize: object.fontSize,
    } : null
    this.pushEvent('editor:selection_changed', { selection })
  }

  private sendLayerSummary(): void {
    const page = this.activePage()
    const layers = [...(page?.objects ?? [])].reverse().map((object) => ({
      id: object.id,
      name: object.name ?? object.type,
      type: object.type,
      visible: object.visible !== false,
      locked: object.locked === true,
      selected: object.id === this.selectedId,
    }))
    this.pushEvent('editor:layers_updated', { layers })
  }

  private sendPageSummary(): void {
    const pages = this.document.pages.map((page, index) => ({
      id: page.id,
      name: page.name ?? `Página ${index + 1}`,
      objectCount: page.objects.length,
    }))
    this.pushEvent('editor:pages_updated', { pages, activePageId: this.activePageId })
  }

  private emitSaveStatus(status: SaveStatus | 'dirty'): void {
    this.pushEvent('editor:dirty', { status })
  }

  private fit(): void {
    fitCanvasToPage(this.canvas, this.document, this.host)
  }

  private zoomBy(factor: number): void {
    const zoom = Math.min(4, Math.max(0.05, this.canvas.getZoom() * factor))
    this.canvas.zoomToPoint(new Point(this.canvas.getWidth() / 2, this.canvas.getHeight() / 2), zoom)
  }

  private notify(message: string): void {
    this.exportStatus(message)
  }

  private exportStatus(message: string): void {
    this.pushEvent('editor:export_status', { message })
  }
}
