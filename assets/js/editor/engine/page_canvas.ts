import { Canvas, Rect, type FabricObject } from 'fabric'
import type { TelaDocument, TelaPage } from '../document/types'
import { deserializeSavedObjects, type FabricDocumentObject } from './serialization'

export function fitCanvasToPage(canvas: Canvas, document: TelaDocument, host: HTMLElement): void {
  const availableWidth = Math.max(320, host.clientWidth)
  const availableHeight = Math.max(240, host.clientHeight)
  const zoom = Math.max(0.05, Math.min(1, availableWidth / document.width, availableHeight / document.height))
  const width = Math.floor(availableWidth)
  const height = Math.floor(availableHeight)
  const offsetX = (width - document.width * zoom) / 2
  const offsetY = (height - document.height * zoom) / 2

  canvas.setDimensions({ width, height })
  canvas.setViewportTransform([zoom, 0, 0, zoom, offsetX, offsetY])
  canvas.requestRenderAll()
}

export async function loadPage(canvas: Canvas, page: TelaPage, document: TelaDocument): Promise<void> {
  await canvas.loadFromJSON({ objects: deserializeSavedObjects(page) })

  for (const object of canvas.getObjects()) {
    applyObjectLockState(object as FabricDocumentObject)
  }

  const background = new Rect({
    left: 0,
    top: 0,
    width: document.width,
    height: document.height,
    fill: page.background.type === 'solid' ? page.background.color : '#ffffff',
    selectable: false,
    evented: false,
    excludeFromExport: false,
  }) as FabricObject & { __editorBackground?: boolean }
  background.__editorBackground = true
  canvas.add(background)
  canvas.sendObjectToBack(background)
  canvas.discardActiveObject()
  canvas.requestRenderAll()
}

export function applyObjectLockState(object: FabricDocumentObject): void {
  const locked = object.locked === true
  object.set({
    visible: object.visible !== false,
    selectable: !locked,
    evented: !locked,
    lockMovementX: locked,
    lockMovementY: locked,
    lockScalingX: locked,
    lockScalingY: locked,
    lockRotation: locked,
    hasControls: !locked,
  })
}
