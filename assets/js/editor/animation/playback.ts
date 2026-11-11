export const PLAYBACK_SPEEDS = [0.5, 1, 1.5, 2] as const

export type PlaybackSpeed = (typeof PLAYBACK_SPEEDS)[number]

export interface PlaybackState {
  readonly active: boolean
  readonly playing: boolean
  readonly timeMs: number
  readonly speed: PlaybackSpeed
  readonly loop: boolean
}

const MAX_FRAME_DELTA_MS = 100

function duration(value: number): number {
  return Number.isFinite(value) ? Math.max(0, value) : 0
}

function initialState(): PlaybackState {
  return Object.freeze({
    active: false,
    playing: false,
    timeMs: 0,
    speed: 1,
    loop: false,
  })
}

export class Playback {
  private currentState: PlaybackState = initialState()

  get state(): PlaybackState {
    return this.currentState
  }

  play(lengthMs: number): void {
    const length = duration(lengthMs)

    if (length === 0) {
      this.update({ active: false, playing: false, timeMs: 0 })
      return
    }

    const timeMs = this.currentState.timeMs >= length ? 0 : this.currentState.timeMs
    this.update({ active: true, playing: true, timeMs })
  }

  pause(): void {
    this.update({ playing: false })
  }

  stop(): void {
    this.update({ active: false, playing: false, timeMs: 0 })
  }

  seek(ms: number, lengthMs: number): void {
    const length = duration(lengthMs)
    const timeMs = Number.isFinite(ms) ? Math.min(length, Math.max(0, ms)) : 0
    this.update({ active: true, playing: false, timeMs })
  }

  setSpeed(speed: number): void {
    if (PLAYBACK_SPEEDS.includes(speed as PlaybackSpeed)) {
      this.update({ speed: speed as PlaybackSpeed })
    }
  }

  setLoop(loop: boolean): void {
    if (typeof loop === 'boolean') this.update({ loop })
  }

  advance(dtMs: number, lengthMs: number): void {
    if (!this.currentState.playing) return

    const length = duration(lengthMs)
    if (length === 0) {
      this.update({ active: false, playing: false, timeMs: 0 })
      return
    }

    const requestedDelta = Number.isFinite(dtMs) ? Math.max(0, dtMs) : 0
    const delta = Math.min(MAX_FRAME_DELTA_MS, requestedDelta)
    const nextTime = this.currentState.timeMs + delta * this.currentState.speed

    if (this.currentState.loop) {
      this.update({ timeMs: nextTime % length })
    } else if (nextTime >= length) {
      this.update({ active: false, playing: false, timeMs: 0 })
    } else {
      this.update({ timeMs: nextTime })
    }
  }

  private update(changes: Partial<PlaybackState>): void {
    this.currentState = Object.freeze({ ...this.currentState, ...changes })
  }
}
