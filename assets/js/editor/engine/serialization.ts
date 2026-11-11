import type { Canvas, FabricObject } from 'fabric'
import type { DocObject, TelaDocument, TelaPage } from '../document/types'

export const EXTRA_PROPS = [
  'id',
  'name',
  'locked',
  'visible',
  'assetId',
  'catalogAssetId',
  'effects',
  'origFill',
  'origStroke',
  'docSrc',
  'animation',
] as const

export type FabricDocumentObject = FabricObject & Partial<DocObject> & Record<string, unknown>

export function serializePage(canvas: Canvas, page: TelaPage): TelaPage {
  const objects = canvas.getObjects()
    .filter((object) => !(object as FabricDocumentObject).__editorBackground)
    .map((object) => {
      const serialized = object.toObject([...EXTRA_PROPS]) as Record<string, unknown>
      const fabricObject = object as FabricDocumentObject
      return {
        ...serialized,
        id: typeof fabricObject.id === 'string' ? fabricObject.id : crypto.randomUUID(),
        type: typeof serialized.type === 'string' ? serialized.type : 'unknown',
        ...(typeof fabricObject.name === 'string' ? { name: fabricObject.name } : {}),
        ...(typeof fabricObject.locked === 'boolean' ? { locked: fabricObject.locked } : {}),
        ...(typeof fabricObject.visible === 'boolean' ? { visible: fabricObject.visible } : {}),
      } as DocObject
    })

  return { ...page, objects }
}

export function serializeDocument(document: TelaDocument, canvas: Canvas, activePageId: string): TelaDocument {
  return {
    ...document,
    pages: document.pages.map((page) => page.id === activePageId ? serializePage(canvas, page) : page),
  }
}

export function deserializeSavedObjects(page: TelaPage): Record<string, unknown>[] {
  return page.objects.map((object) => ({
    ...structuredClone(object),
    id: object.id,
    type: object.type,
    visible: object.visible !== false,
  }))
}

export function replaceActivePage(document: TelaDocument, page: TelaPage): TelaDocument {
  return {
    ...document,
    pages: document.pages.map((current) => current.id === page.id ? page : current),
  }
}
