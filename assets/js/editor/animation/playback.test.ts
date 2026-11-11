import { describe, expect, it } from 'vitest'
import { Playback } from './playback'

describe('animation playback', () => {
  it('plays, pauses, seeks, and stops without changing document state', () => {
    const playback = new Playback()
    playback.play(1000)
    for (let index = 0; index < 4; index++) playback.advance(100, 1000)
    expect(playback.state).toMatchObject({ active: true, playing: true, timeMs: 400 })
    playback.pause()
    playback.advance(200, 1000)
    expect(playback.state.timeMs).toBe(400)
    playback.seek(800, 1000)
    expect(playback.state).toMatchObject({ active: true, playing: false, timeMs: 800 })
    playback.stop()
    expect(playback.state).toMatchObject({ active: false, playing: false, timeMs: 0 })
  })

  it('stops at the end or wraps when looping', () => {
    const playback = new Playback()
    playback.play(1000)
    for (let index = 0; index < 11; index++) playback.advance(100, 1000)
    expect(playback.state).toMatchObject({ active: false, timeMs: 0 })
    playback.setLoop(true)
    playback.play(1000)
    for (let index = 0; index < 11; index++) playback.advance(100, 1000)
    expect(playback.state).toMatchObject({ active: true, playing: true, timeMs: 100 })
  })

  it('clamps seeks and limits large clock jumps', () => {
    const playback = new Playback()
    playback.seek(2000, 1000)
    expect(playback.state.timeMs).toBe(1000)
    playback.play(1000)
    playback.advance(10_000, 1000)
    expect(playback.state.timeMs).toBe(100)
  })
})
