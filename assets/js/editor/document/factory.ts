import { MAX_DIMENSION_PX, SCHEMA_VERSION, type TelaDocument, type TelaPage } from './types'

export function newId(): string {
  return crypto.randomUUID()
}

export function dimension(value: number): number {
  if (!Number.isFinite(value)) throw new RangeError('Document dimensions must be finite numbers')
  return Math.min(MAX_DIMENSION_PX, Math.max(1, Math.round(value)))
}

export function createPage(objects: TelaPage['objects'] = []): TelaPage {
  return {
    id: newId(),
    background: { type: 'solid', color: '#ffffff' },
    objects: structuredClone(objects),
  }
}

export function createDocument(input: { width: number; height: number; presetId?: string }): TelaDocument {
  return {
    schemaVersion: SCHEMA_VERSION,
    width: dimension(input.width),
    height: dimension(input.height),
    pages: [createPage()],
    ...(input.presetId ? { meta: { presetId: input.presetId } } : {}),
  }
}
