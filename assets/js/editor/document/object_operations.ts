import { newId } from './factory'
import type { DocObject, TelaDocument, TelaPage } from './types'

export type ObjectMove = 'front' | 'back' | 'forward' | 'backward'

function pageIndex(doc: TelaDocument, pageId: string): number {
  const index = doc.pages.findIndex((page) => page.id === pageId)
  if (index < 0) throw new RangeError(`Unknown page: ${pageId}`)
  return index
}

function objectIndex(page: TelaPage, objectId: string): number {
  const index = page.objects.findIndex((object) => object.id === objectId)
  if (index < 0) throw new RangeError(`Unknown object: ${objectId} on page ${page.id}`)
  return index
}

function replacePage(doc: TelaDocument, index: number, page: TelaPage): TelaDocument {
  const pages = [...doc.pages]
  pages[index] = page
  return { ...doc, pages }
}

export function updateObject(
  doc: TelaDocument,
  pageId: string,
  objectId: string,
  properties: Partial<DocObject>,
): TelaDocument {
  const currentPageIndex = pageIndex(doc, pageId)
  const page = doc.pages[currentPageIndex]!
  const currentObjectIndex = objectIndex(page, objectId)
  const currentObject = page.objects[currentObjectIndex]!
  const updatedObject = {
    ...currentObject,
    ...properties,
    id: currentObject.id,
    type: currentObject.type,
  }
  const objects = [...page.objects]
  objects[currentObjectIndex] = updatedObject
  return replacePage(doc, currentPageIndex, { ...page, objects })
}

export function moveObject(
  doc: TelaDocument,
  pageId: string,
  objectId: string,
  direction: ObjectMove,
): TelaDocument {
  const currentPageIndex = pageIndex(doc, pageId)
  const page = doc.pages[currentPageIndex]!
  const source = objectIndex(page, objectId)
  const lastIndex = page.objects.length - 1
  const destination =
    direction === 'front' ? lastIndex
      : direction === 'back' ? 0
        : direction === 'forward' ? Math.min(lastIndex, source + 1)
          : direction === 'backward' ? Math.max(0, source - 1)
            : null

  if (destination === null) throw new RangeError(`Unknown object move direction: ${String(direction)}`)
  if (destination === source) return doc

  const objects = [...page.objects]
  const [object] = objects.splice(source, 1)
  objects.splice(destination, 0, object!)
  return replacePage(doc, currentPageIndex, { ...page, objects })
}

export function duplicateObject(doc: TelaDocument, pageId: string, objectId: string): TelaDocument {
  const currentPageIndex = pageIndex(doc, pageId)
  const page = doc.pages[currentPageIndex]!
  const sourceIndex = objectIndex(page, objectId)
  const source = page.objects[sourceIndex]!
  const duplicate = { ...structuredClone(source), id: newId() }
  const objects = [...page.objects]
  objects.splice(sourceIndex + 1, 0, duplicate)
  return replacePage(doc, currentPageIndex, { ...page, objects })
}

export function removeObject(doc: TelaDocument, pageId: string, objectId: string): TelaDocument {
  const currentPageIndex = pageIndex(doc, pageId)
  const page = doc.pages[currentPageIndex]!
  const objectPosition = objectIndex(page, objectId)
  const objects = page.objects.filter((_, index) => index !== objectPosition)
  return replacePage(doc, currentPageIndex, { ...page, objects })
}
