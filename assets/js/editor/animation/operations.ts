import { normalizeAnimation, normalizeObjectAnimation, TRANSITION_RANGE } from './model'
import type { AnimSlot, Animation, DocObject, PageTransition, TelaDocument, TelaPage } from '../document/types'

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

export function setObjectAnimation(
  doc: TelaDocument,
  pageId: string,
  objectId: string,
  slot: AnimSlot,
  animation: Animation | null,
): TelaDocument {
  const currentPageIndex = pageIndex(doc, pageId)
  const page = doc.pages[currentPageIndex]!
  const currentObjectIndex = objectIndex(page, objectId)
  const object = page.objects[currentObjectIndex]!
  const nextAnimation = normalizeObjectAnimation(object.animation) ?? {}

  if (animation === null) {
    delete nextAnimation[slot]
  } else {
    const normalized = normalizeAnimation(animation)
    if (!normalized) throw new RangeError(`Invalid animation for object ${objectId}`)
    nextAnimation[slot] = normalized
  }

  const updatedObject: DocObject = { ...object }
  if (nextAnimation.enter || nextAnimation.emphasis || nextAnimation.exit) {
    updatedObject.animation = nextAnimation
  } else {
    delete updatedObject.animation
  }

  const objects = [...page.objects]
  objects[currentObjectIndex] = updatedObject
  return replacePage(doc, currentPageIndex, { ...page, objects })
}

export function setPageTransition(
  doc: TelaDocument,
  pageId: string,
  transition: PageTransition | null,
): TelaDocument {
  const currentPageIndex = pageIndex(doc, pageId)
  const page = doc.pages[currentPageIndex]!
  const updatedPage: TelaPage = { ...page }

  if (transition === null) {
    delete updatedPage.transition
  } else {
    const normalized = normalizeAnimation(transition)
    if (!normalized) throw new RangeError(`Invalid page transition for page ${pageId}`)

    updatedPage.transition = {
      preset: normalized.preset,
      durationMs: Math.min(TRANSITION_RANGE.max, Math.max(TRANSITION_RANGE.min, normalized.durationMs)),
      easing: normalized.easing,
      ...(normalized.direction ? { direction: normalized.direction } : {}),
    }
  }

  return replacePage(doc, currentPageIndex, updatedPage)
}
