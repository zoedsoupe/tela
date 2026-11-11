import { createPage, newId } from './factory'
import { MAX_PAGES, type TelaDocument, type TelaPage } from './types'

function pageIndex(doc: TelaDocument, pageId: string): number {
  const index = doc.pages.findIndex((page) => page.id === pageId)
  if (index < 0) throw new RangeError(`Unknown page: ${pageId}`)
  return index
}

function withPages(doc: TelaDocument, pages: TelaPage[]): TelaDocument {
  return { ...doc, pages }
}

export function addPage(doc: TelaDocument, afterPageId?: string): TelaDocument {
  if (doc.pages.length >= MAX_PAGES) throw new RangeError(`A document cannot exceed ${MAX_PAGES} pages`)
  const index = afterPageId ? pageIndex(doc, afterPageId) + 1 : doc.pages.length
  const pages = [...doc.pages]
  pages.splice(index, 0, createPage())
  return withPages(doc, pages)
}

function regenerateIds(page: TelaPage): TelaPage {
  const objects = structuredClone(page.objects).map((object) => ({ ...object, id: newId() }))
  return { ...structuredClone(page), id: newId(), objects }
}

export function duplicatePage(doc: TelaDocument, pageId: string): TelaDocument {
  if (doc.pages.length >= MAX_PAGES) throw new RangeError(`A document cannot exceed ${MAX_PAGES} pages`)
  const index = pageIndex(doc, pageId)
  const pages = [...doc.pages]
  pages.splice(index + 1, 0, regenerateIds(doc.pages[index]!))
  return withPages(doc, pages)
}

export function deletePage(doc: TelaDocument, pageId: string): TelaDocument {
  if (doc.pages.length === 1) throw new RangeError('A document must keep at least one page')
  const index = pageIndex(doc, pageId)
  return withPages(doc, doc.pages.filter((_, candidate) => candidate !== index))
}

export function reorderPage(doc: TelaDocument, pageId: string, destination: number): TelaDocument {
  const source = pageIndex(doc, pageId)
  if (!Number.isInteger(destination) || destination < 0 || destination >= doc.pages.length) {
    throw new RangeError('Page destination is out of bounds')
  }
  const pages = [...doc.pages]
  const [page] = pages.splice(source, 1)
  pages.splice(destination, 0, page!)
  return withPages(doc, pages)
}
