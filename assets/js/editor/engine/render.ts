import { StaticCanvas } from 'fabric'
import type { TelaDocument, TelaPage } from '../document/types'
import { deserializeSavedObjects } from './serialization'

export type RasterFormat = 'png' | 'jpg'

export async function renderPageDataUrl(
  document: TelaDocument,
  page: TelaPage,
  format: RasterFormat,
  multiplier: 1 | 2 | 3,
): Promise<string> {
  const element = globalThis.document.createElement('canvas')
  const renderer = new StaticCanvas(element, {
    width: document.width,
    height: document.height,
    backgroundColor: page.background.type === 'solid' ? page.background.color : '#ffffff',
    renderOnAddRemove: false,
  })

  try {
    await renderer.loadFromJSON({ objects: deserializeSavedObjects(page) })
    renderer.renderAll()
    return renderer.toDataURL({
      format: format === 'jpg' ? 'jpeg' : 'png',
      multiplier,
      quality: format === 'jpg' ? 0.92 : undefined,
    })
  } finally {
    await renderer.dispose()
  }
}

export function downloadDataUrl(dataUrl: string, filename: string): void {
  const link = document.createElement('a')
  link.href = dataUrl
  link.download = filename
  link.click()
}
