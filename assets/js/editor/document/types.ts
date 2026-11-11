export const SCHEMA_VERSION = 1 as const
export const MAX_DIMENSION_PX = 20_000
export const MAX_PAGES = 100

export type AnimEasing = 'linear' | 'ease-in' | 'ease-out' | 'ease-in-out' | 'spring'
export type AnimDirection = 'left' | 'right' | 'up' | 'down' | 'in' | 'out'
export type AnimSlot = 'enter' | 'emphasis' | 'exit'

export interface Animation {
  preset: string
  durationMs: number
  delayMs: number
  easing: AnimEasing
  direction?: AnimDirection
  intensity?: number
  loop?: boolean
}

export interface ObjectAnimation {
  enter?: Animation
  emphasis?: Animation
  exit?: Animation
}

export interface PageTransition {
  preset: string
  durationMs: number
  easing: AnimEasing
  direction?: AnimDirection
}

export type PageBackground =
  | { type: 'solid'; color: string }
  | { type: 'image'; src: string; fit: 'cover' | 'contain' | 'tile'; opacity?: number }

export interface DocObject {
  id: string
  type: string
  name?: string
  locked?: boolean
  visible?: boolean
  animation?: ObjectAnimation
  [property: string]: unknown
}

export interface TelaPage {
  id: string
  name?: string
  background: PageBackground
  objects: DocObject[]
  durationSec?: number
  transition?: PageTransition
}

export interface TelaDocument {
  schemaVersion: typeof SCHEMA_VERSION
  width: number
  height: number
  pages: TelaPage[]
  meta?: {
    presetId?: string
    brandKitId?: string
  }
}
