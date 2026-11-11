import { newId } from './factory'
import { MAX_DIMENSION_PX, MAX_PAGES, SCHEMA_VERSION, type AnimDirection, type AnimEasing, type PageBackground, type PageTransition, type TelaDocument, type TelaPage } from './types'
import { normalizeObjectAnimation } from '../animation/model'

const EASINGS = new Set<AnimEasing>(['linear', 'ease-in', 'ease-out', 'ease-in-out', 'spring'])
const DIRECTIONS = new Set<AnimDirection>(['left', 'right', 'up', 'down', 'in', 'out'])
const PRESET_ID = /^[a-z0-9-]{1,40}$/

type RecordValue = Record<string, unknown>

function record(value: unknown): value is RecordValue {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

function boundedDimension(value: unknown): number {
  if (typeof value !== 'number' || !Number.isFinite(value)) return 1080
  return Math.min(MAX_DIMENSION_PX, Math.max(1, Math.round(value)))
}

function normalizeBackground(value: unknown): PageBackground {
  if (record(value) && value.type === 'image' && typeof value.src === 'string' && value.src.length > 0) {
    const background: PageBackground = {
      type: 'image',
      src: value.src,
      fit: value.fit === 'contain' || value.fit === 'tile' ? value.fit : 'cover',
    }
    if (typeof value.opacity === 'number' && Number.isFinite(value.opacity)) {
      background.opacity = Math.min(1, Math.max(0, value.opacity))
    }
    return background
  }

  if (record(value) && value.type === 'solid' && typeof value.color === 'string' && value.color.length > 0) {
    return { type: 'solid', color: value.color }
  }

  return { type: 'solid', color: '#ffffff' }
}

function normalizeTransition(value: unknown): PageTransition | undefined {
  if (!record(value) || typeof value.preset !== 'string' || !PRESET_ID.test(value.preset)) return undefined

  const duration = value.durationMs
  const durationMs = typeof duration === 'number' && Number.isFinite(duration)
    ? Math.min(3_000, Math.max(200, Math.round(duration)))
    : 300
  const transition: PageTransition = {
    preset: value.preset,
    durationMs,
    easing: typeof value.easing === 'string' && EASINGS.has(value.easing as AnimEasing)
      ? value.easing as AnimEasing
      : 'ease-out',
  }

  if (typeof value.direction === 'string' && DIRECTIONS.has(value.direction as AnimDirection)) {
    transition.direction = value.direction as AnimDirection
  }

  return transition
}

function normalizeObject(value: unknown, usedIds: Set<string>): TelaPage['objects'][number] | undefined {
  if (!record(value)) return undefined

  const object = structuredClone(value) as RecordValue
  const id = typeof object.id === 'string' && object.id.length > 0 && !usedIds.has(object.id)
    ? object.id
    : newId()
  usedIds.add(id)

  const normalized: RecordValue = {
    ...object,
    id,
    type: typeof object.type === 'string' && object.type.length > 0 ? object.type : 'unknown',
  }

  if (typeof normalized.name !== 'string') delete normalized.name
  if (typeof normalized.locked !== 'boolean') delete normalized.locked
  if (typeof normalized.visible !== 'boolean') delete normalized.visible

  const animation = normalizeObjectAnimation(normalized.animation)
  if (animation) normalized.animation = animation
  else delete normalized.animation

  return normalized as TelaPage['objects'][number]
}

function normalizePage(value: unknown, usedIds: Set<string>, usedObjectIds: Set<string>): TelaPage | undefined {
  if (!record(value)) return undefined

  const id = typeof value.id === 'string' && value.id.length > 0 && !usedIds.has(value.id)
    ? value.id
    : newId()
  usedIds.add(id)

  const objects = Array.isArray(value.objects)
    ? value.objects
      .map((object) => normalizeObject(object, usedObjectIds))
      .filter((object): object is NonNullable<typeof object> => object !== undefined)
    : []

  const page: TelaPage = {
    id,
    background: normalizeBackground(value.background),
    objects,
  }

  if (typeof value.name === 'string') page.name = value.name
  if (typeof value.durationSec === 'number' && Number.isFinite(value.durationSec)) {
    page.durationSec = Math.min(60, Math.max(1, value.durationSec))
  }

  const transition = normalizeTransition(value.transition)
  if (transition) page.transition = transition

  return page
}

export class DocumentError extends Error {
  constructor(message: string) {
    super(message)
    this.name = 'DocumentError'
  }
}

export function migrateDocument(input: unknown): TelaDocument {
  if (!record(input)) throw new DocumentError('Document must be an object')

  if (typeof input.schemaVersion === 'number' && input.schemaVersion > SCHEMA_VERSION) {
    throw new DocumentError('Document is from a newer version')
  }
  if (input.schemaVersion !== undefined && input.schemaVersion !== SCHEMA_VERSION) {
    throw new DocumentError('Unsupported document version')
  }

  const usedPageIds = new Set<string>()
  const usedObjectIds = new Set<string>()
  const pages = Array.isArray(input.pages)
    ? input.pages
      .slice(0, MAX_PAGES)
      .map((page) => normalizePage(page, usedPageIds, usedObjectIds))
      .filter((page): page is TelaPage => page !== undefined)
    : []

  const document: TelaDocument = {
    schemaVersion: SCHEMA_VERSION,
    width: boundedDimension(input.width),
    height: boundedDimension(input.height),
    pages: pages.length > 0 ? pages : [{ id: newId(), background: { type: 'solid', color: '#ffffff' }, objects: [] }],
  }

  if (record(input.meta)) {
    const meta: NonNullable<TelaDocument['meta']> = {}
    if (typeof input.meta.presetId === 'string') meta.presetId = input.meta.presetId
    if (typeof input.meta.brandKitId === 'string') meta.brandKitId = input.meta.brandKitId
    if (Object.keys(meta).length > 0) document.meta = meta
  }

  return document
}
