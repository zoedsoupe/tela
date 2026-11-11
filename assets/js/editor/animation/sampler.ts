import type { Animation } from '../document/types'
import { normalizeObjectAnimation } from './model'
import { emphasisPresets, inOutPresets, type AnimationPreset, type VisualEffect } from './presets'

export interface SampledTransform extends VisualEffect {}

const RESTING: SampledTransform = {
  opacity: 1,
  tx: 0,
  ty: 0,
  scaleX: 1,
  scaleY: 1,
  rotate: 0,
}

function ease(progress: number, easing: Animation['easing']): number {
  const p = Math.min(1, Math.max(0, progress))
  switch (easing) {
    case 'ease-in': return p * p
    case 'ease-out': return 1 - (1 - p) * (1 - p)
    case 'ease-in-out': return p < 0.5 ? 2 * p * p : 1 - 2 * (1 - p) * (1 - p)
    case 'spring': {
      const damped = 1 - Math.exp(-6 * p) * Math.cos(10 * p)
      return Math.min(1, Math.max(0, damped))
    }
    case 'linear':
    default: return p
  }
}

function effectAt(
  preset: AnimationPreset | undefined,
  animation: Animation,
  progress: number,
): SampledTransform | null {
  if (!preset) return null
  return preset.effect(ease(progress, animation.easing), {
    direction: animation.direction,
    intensity: animation.intensity,
  })
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value)
}

/** Sample an object's animation at an absolute timeline time, without retaining playback state. */
export function sampleObject(object: unknown, timeMs: number): SampledTransform {
  if (!isRecord(object)) return { ...RESTING }

  const animations = normalizeObjectAnimation(object.animation)
  if (!animations) return { ...RESTING }

  const time = Number.isFinite(timeMs) ? Math.max(0, timeMs) : 0
  const enter = animations.enter
  const exit = animations.exit
  const emphasis = animations.emphasis

  const exitPreset = exit ? inOutPresets.get(exit.preset) : undefined
  const exitStart = exit?.delayMs ?? Number.POSITIVE_INFINITY
  if (exit && exitPreset && time >= exitStart) {
    const progress = 1 - Math.min(1, (time - exitStart) / exit.durationMs)
    return effectAt(exitPreset, exit, progress) ?? { ...RESTING }
  }

  const enterPreset = enter ? inOutPresets.get(enter.preset) : undefined
  if (enter && enterPreset && time < enter.delayMs + enter.durationMs) {
    const progress = time <= enter.delayMs ? 0 : (time - enter.delayMs) / enter.durationMs
    return effectAt(enterPreset, enter, progress) ?? { ...RESTING }
  }

  const emphasisPreset = emphasis ? emphasisPresets.get(emphasis.preset) : undefined
  if (emphasis && emphasisPreset) {
    const emphasisStart = emphasis.delayMs
    const emphasisEnd = exitPreset ? exitStart : Number.POSITIVE_INFINITY
    if (time >= emphasisStart && time < emphasisEnd) {
      const elapsed = time - emphasisStart
      if (emphasis.loop) {
        const phase = (elapsed % emphasis.durationMs) / emphasis.durationMs
        return effectAt(emphasisPreset, emphasis, phase) ?? { ...RESTING }
      }

      if (elapsed < emphasis.durationMs) {
        return effectAt(emphasisPreset, emphasis, elapsed / emphasis.durationMs) ?? { ...RESTING }
      }
    }
  }

  return { ...RESTING }
}
