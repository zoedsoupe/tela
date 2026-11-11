import type { TelaDocument, TelaPage } from '../document/types'
import { pageDurationMs } from './model'

export interface TimelineSegment {
  kind: 'page' | 'transition'
  startMs: number
  endMs: number
  durationMs: number
  pageIndex: number
  pageId: string
}

export interface Timeline {
  segments: TimelineSegment[]
  totalMs: number
}

function pageSegment(page: TelaPage, pageIndex: number, startMs: number): TimelineSegment {
  const durationMs = pageDurationMs(page)
  return {
    kind: 'page',
    startMs,
    endMs: startMs + durationMs,
    durationMs,
    pageIndex,
    pageId: page.id,
  }
}

export function buildTimeline(document: TelaDocument): Timeline {
  const segments: TimelineSegment[] = []
  let totalMs = 0

  document.pages.forEach((page, pageIndex) => {
    if (pageIndex > 0 && page.transition) {
      const durationMs = Math.max(0, Math.round(page.transition.durationMs))
      if (durationMs > 0) {
        segments.push({
          kind: 'transition',
          startMs: totalMs,
          endMs: totalMs + durationMs,
          durationMs,
          pageIndex,
          pageId: page.id,
        })
        totalMs += durationMs
      }
    }

    const segment = pageSegment(page, pageIndex, totalMs)
    segments.push(segment)
    totalMs = segment.endMs
  })

  return { segments, totalMs }
}

export function frameCount(durationMs: number, fps: number): number {
  if (!Number.isSafeInteger(durationMs) || durationMs <= 0 || !Number.isSafeInteger(fps) || fps <= 0) return 0
  return Math.ceil((durationMs * fps) / 1000)
}

function roundedRatio(numerator: number, denominator: number): number {
  return Math.floor((2 * numerator + denominator) / (2 * denominator))
}

export function gifDelayCs(frameIndex: number, fps: number, durationMs: number): number {
  if (
    !Number.isSafeInteger(frameIndex) || frameIndex < 0 ||
    !Number.isSafeInteger(fps) || fps <= 0 ||
    !Number.isSafeInteger(durationMs) || durationMs <= 0
  ) return 0

  const frameTotal = frameCount(durationMs, fps)
  if (frameIndex >= frameTotal) return 0

  const denominator = fps * 10
  const boundary = (index: number): number => {
    const elapsedNumerator = Math.min(index * 1000, durationMs * fps)
    return roundedRatio(elapsedNumerator, denominator)
  }

  return Math.max(0, boundary(frameIndex + 1) - boundary(frameIndex))
}
