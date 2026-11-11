import type { Animation, ObjectAnimation, TelaPage } from '../document/types'

export const DURATION_RANGE = { min: 100, max: 10_000 } as const
export const DELAY_RANGE = { min: 0, max: 60_000 } as const
export const TRANSITION_RANGE = { min: 200, max: 3_000 } as const
export const TIME_STEP_MS = 100

const PRESET_ID = /^[a-z0-9-]{1,40}$/
const EASINGS = new Set(['linear', 'ease-in', 'ease-out', 'ease-in-out', 'spring'])
const DIRECTIONS = new Set(['left', 'right', 'up', 'down', 'in', 'out'])

const record = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null && !Array.isArray(value)

const finite = (value: unknown): value is number => typeof value === 'number' && Number.isFinite(value)
const bounded = (value: unknown, min: number, max: number, fallback: number): number =>
  finite(value) ? Math.min(max, Math.max(min, Math.round(value))) : fallback

export function normalizeAnimation(raw: unknown): Animation | null {
  if (!record(raw) || typeof raw.preset !== 'string' || !PRESET_ID.test(raw.preset)) return null
  const animation: Animation = {
    preset: raw.preset,
    durationMs: bounded(raw.durationMs, DURATION_RANGE.min, DURATION_RANGE.max, 600),
    delayMs: bounded(raw.delayMs, DELAY_RANGE.min, DELAY_RANGE.max, 0),
    easing: typeof raw.easing === 'string' && EASINGS.has(raw.easing) ? raw.easing as Animation['easing'] : 'ease-out',
  }
  if (typeof raw.direction === 'string' && DIRECTIONS.has(raw.direction)) {
    animation.direction = raw.direction as Animation['direction']
  }
  if (finite(raw.intensity)) animation.intensity = Math.min(1, Math.max(0, raw.intensity))
  if (raw.loop === true) animation.loop = true
  return animation
}

export function normalizeObjectAnimation(raw: unknown): ObjectAnimation | null {
  if (!record(raw)) return null
  const output: ObjectAnimation = {}
  for (const slot of ['enter', 'emphasis', 'exit'] as const) {
    const animation = normalizeAnimation(raw[slot])
    if (animation) output[slot] = animation
  }
  return output.enter || output.emphasis || output.exit ? output : null
}

export function pageDurationMs(page: Pick<TelaPage, 'objects' | 'durationSec'>): number {
  let animationsEnd = 0
  for (const object of page.objects) {
    const animation = normalizeObjectAnimation(object.animation)
    if (!animation) continue
    for (const slot of ['enter', 'emphasis', 'exit'] as const) {
      const current = animation[slot]
      if (current && !(slot === 'emphasis' && current.loop)) {
        animationsEnd = Math.max(animationsEnd, current.delayMs + current.durationMs)
      }
    }
  }
  const requested = finite(page.durationSec) ? Math.round(Math.min(60, Math.max(1, page.durationSec)) * 1000) : 0
  return Math.max(1000, animationsEnd, requested)
}
