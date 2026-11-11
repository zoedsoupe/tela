export interface VisualEffect {
  opacity: number
  tx: number
  ty: number
  scaleX: number
  scaleY: number
  rotate: number
  clipProgress?: number
}

export interface EffectOptions {
  direction?: string
  intensity?: number
}

export interface AnimationPreset {
  effect(progress: number, options?: EffectOptions): VisualEffect
}

const clamp = (value: number): number => Math.min(1, Math.max(0, value))
const intensityOf = (options?: EffectOptions): number =>
  typeof options?.intensity === 'number' && Number.isFinite(options.intensity)
    ? Math.min(1, Math.max(0, options.intensity))
    : 1

const resting = (): VisualEffect => ({
  opacity: 1,
  tx: 0,
  ty: 0,
  scaleX: 1,
  scaleY: 1,
  rotate: 0,
})

function directionVector(direction: string | undefined): { x: number; y: number } {
  switch (direction) {
    case 'left': return { x: -1, y: 0 }
    case 'up': return { x: 0, y: -1 }
    case 'down': return { x: 0, y: 1 }
    case 'in': return { x: 1, y: 0 }
    case 'out': return { x: -1, y: 0 }
    case 'right':
    default: return { x: 1, y: 0 }
  }
}

function normalized(progress: number): number {
  return Number.isFinite(progress) ? clamp(progress) : 0
}

function inOutEffect(preset: string, progress: number, options?: EffectOptions): VisualEffect {
  const p = normalized(progress)
  const remaining = 1 - p
  const strength = intensityOf(options)
  const vector = directionVector(options?.direction)
  const effect = resting()

  effect.opacity = p

  switch (preset) {
    case 'rise':
      effect.ty = 24 * strength * remaining
      break
    case 'slide':
      effect.tx = 32 * strength * vector.x * remaining
      effect.ty = 32 * strength * vector.y * remaining
      break
    case 'pop':
      effect.scaleX = 0.8 + 0.2 * p
      effect.scaleY = 0.8 + 0.2 * p
      break
    case 'wipe':
      effect.clipProgress = p
      break
    case 'spin':
      effect.rotate = 360 * strength * remaining
      break
    case 'fade':
    default:
      break
  }

  return effect
}

export const inOutPresets = new Map<string, AnimationPreset>(
  ['fade', 'rise', 'slide', 'pop', 'wipe', 'spin'].map((preset) => [
    preset,
    { effect: (progress, options) => inOutEffect(preset, progress, options) },
  ]),
)

function emphasisEffect(preset: string, progress: number, options?: EffectOptions): VisualEffect {
  const p = normalized(progress)
  const strength = intensityOf(options)
  const effect = resting()

  switch (preset) {
    case 'pulse': {
      const pulse = Math.sin(Math.PI * p) * 0.12 * strength
      effect.scaleX = 1 + pulse
      effect.scaleY = 1 + pulse
      break
    }
    case 'sway':
      effect.rotate = Math.sin(2 * Math.PI * p) * 8 * strength
      break
    case 'shake':
      effect.tx = Math.sin(4 * Math.PI * p) * 8 * strength
      break
    default:
      break
  }

  return effect
}

export const emphasisPresets = new Map<string, AnimationPreset>(
  ['pulse', 'shake', 'sway'].map((preset) => [
    preset,
    { effect: (progress, options) => emphasisEffect(preset, progress, options) },
  ]),
)

export const transitionPresets = new Map<string, AnimationPreset>(
  ['fade', 'slide', 'wipe'].map((preset) => [
    preset,
    { effect: (progress, options) => inOutEffect(preset, progress, options) },
  ]),
)
