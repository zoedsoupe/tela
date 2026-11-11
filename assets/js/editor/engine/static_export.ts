import { FabricImage, Pattern, StaticCanvas } from 'fabric'
import type { TelaDocument, TelaPage } from '../document/types'
import { deserializeSavedObjects } from './serialization'
import { downloadBlob, sanitizeExportFilename } from '../export/download'

async function createStaticRenderer(document: TelaDocument, page: TelaPage): Promise<StaticCanvas> {
  const element = globalThis.document.createElement('canvas')
  const renderer = new StaticCanvas(element, {
    width: document.width,
    height: document.height,
    backgroundColor: page.background.type === 'solid' ? page.background.color : '#ffffff',
    renderOnAddRemove: false,
  })
  try {
    await renderer.loadFromJSON({ objects: deserializeSavedObjects(page) })
    if (page.background.type === 'image') {
      const image = await FabricImage.fromURL(page.background.src, { crossOrigin: 'anonymous' })
      const naturalWidth = image.width || 1
      const naturalHeight = image.height || 1
      if (page.background.fit === 'tile') {
        renderer.backgroundColor = new Pattern({ source: image.getElement(), repeat: 'repeat' })
        renderer.backgroundImage = undefined
        renderer.renderAll()
        return renderer
      }
      const scale = page.background.fit === 'contain'
        ? Math.min(document.width / naturalWidth, document.height / naturalHeight)
        : Math.max(document.width / naturalWidth, document.height / naturalHeight)
      image.set({
        left: document.width / 2,
        top: document.height / 2,
        originX: 'center',
        originY: 'center',
        scaleX: scale,
        scaleY: scale,
        opacity: page.background.opacity ?? 1,
      })
      renderer.add(image)
      renderer.sendObjectToBack(image)
    }
    renderer.renderAll()
    return renderer
  } catch (error) {
    await renderer.dispose()
    throw error
  }
}

function blobDataUrl(blob: Blob): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => typeof reader.result === 'string' ? resolve(reader.result) : reject(new Error('Could not encode image data.'))
    reader.onerror = () => reject(reader.error ?? new Error('Could not read image data.'))
    reader.readAsDataURL(blob)
  })
}

async function embedExternalImages(svgText: string): Promise<string> {
  const parsed = new DOMParser().parseFromString(svgText, 'image/svg+xml')
  const images = Array.from(parsed.querySelectorAll('image'))
  for (const image of images) {
    const source = image.getAttribute('href') ?? image.getAttribute('xlink:href')
    if (!source || source.startsWith('data:')) continue
    const response = await fetch(source)
    if (!response.ok) throw new Error(`Could not embed image from ${source} (${response.status}).`)
    image.setAttribute('href', await blobDataUrl(await response.blob()))
    image.removeAttribute('xlink:href')
  }
  return new XMLSerializer().serializeToString(parsed.documentElement)
}

export async function renderPageSvg(document: TelaDocument, page: TelaPage): Promise<string> {
  const renderer = await createStaticRenderer(document, page)
  try {
    const svg = renderer.toSVG({
      suppressPreamble: false,
      width: `${document.width}px`,
      height: `${document.height}px`,
      viewBox: { x: 0, y: 0, width: document.width, height: document.height },
    })
    return await embedExternalImages(svg)
  } finally {
    await renderer.dispose()
  }
}

export async function downloadPageSvg(document: TelaDocument, page: TelaPage, filename = page.name ?? 'pagina'): Promise<void> {
  const svg = await renderPageSvg(document, page)
  downloadBlob(new Blob([svg], { type: 'image/svg+xml;charset=utf-8' }), sanitizeExportFilename(filename, 'svg'))
}

export async function renderDocumentPdf(document: TelaDocument, scale = 2): Promise<Blob> {
  if (!document.pages.length) throw new TypeError('PDF export requires at least one page.')
  if (!Number.isFinite(scale) || scale < 1 || scale > 3) throw new RangeError('PDF raster scale must be between 1 and 3.')
  const { jsPDF } = await import('jspdf')
  const widthPt = document.width * 72 / 96
  const heightPt = document.height * 72 / 96
  const orientation = widthPt > heightPt ? 'landscape' : 'portrait'
  const pdf = new jsPDF({ orientation, unit: 'pt', format: [widthPt, heightPt], compress: true })

  for (const [index, page] of document.pages.entries()) {
    if (index > 0) pdf.addPage([widthPt, heightPt], orientation)
    const renderer = await createStaticRenderer(document, page)
    let image: string
    try {
      image = renderer.toDataURL({ format: 'png', multiplier: scale as 1 | 2 | 3 })
    } finally {
      await renderer.dispose()
    }
    pdf.addImage(image, 'PNG', 0, 0, widthPt, heightPt, undefined, 'FAST')
  }

  return pdf.output('blob')
}

export async function downloadDocumentPdf(document: TelaDocument, filename = 'documento'): Promise<void> {
  const pdf = await renderDocumentPdf(document)
  downloadBlob(pdf, sanitizeExportFilename(filename, 'pdf'))
}
