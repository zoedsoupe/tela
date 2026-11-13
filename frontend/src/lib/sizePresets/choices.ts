import { useEffect, useSyncExternalStore } from 'react'
import { safeGetItem, safeSetItem } from "@/lib/storage"
import { quickPresets, type SizePreset, type SizePresetCatalogue } from "./catalogue"

/** Sizes saved in this browser, recent choices and collapsed picker sections. */
export interface SizeChoices {
  pinned: string[] | null
  recent: string[]
  collapsed: string[]
}

const KEY = "tela.sizeChoices"
export const MAX_PINNED = 24
const MAX_RECENT = 8
const EMPTY: SizeChoices = { pinned: null, recent: [], collapsed: [] }

let current: SizeChoices = EMPTY
let loaded = false
const listeners = new Set<() => void>()

const strings = (value: unknown): string[] => (Array.isArray(value) ? value.filter((item): item is string => typeof item === 'string') : [])

function readLocal(): SizeChoices {
  try {
    const value = JSON.parse(safeGetItem(KEY) ?? 'null') as Partial<Record<keyof SizeChoices, unknown>> | null
    if (!value || typeof value !== 'object') return EMPTY
    return { pinned: value.pinned === null || value.pinned === undefined ? null : strings(value.pinned), recent: strings(value.recent), collapsed: strings(value.collapsed) }
  } catch {
    return EMPTY
  }
}

function publish(next: SizeChoices): void {
  current = next
  loaded = true
  safeSetItem(KEY, JSON.stringify(next))
  for (const listener of listeners) listener()
}

export function loadSizeChoices(refresh = false): Promise<void> {
  if (!loaded || refresh) {
    current = readLocal()
    loaded = true
    for (const listener of listeners) listener()
  }
  return Promise.resolve()
}

export function getSizeChoices(): SizeChoices {
  return current
}

export function subscribeSizeChoices(listener: () => void): () => void {
  listeners.add(listener)
  return () => listeners.delete(listener)
}

export function useSizeChoices(): SizeChoices {
  useEffect(() => {
    void loadSizeChoices()
  }, [])
  return useSyncExternalStore(subscribeSizeChoices, getSizeChoices, getSizeChoices)
}

export function togglePinned(id: string, shown: readonly string[]): boolean {
  const list = current.pinned ?? [...shown]
  if (list.includes(id)) {
    publish({ ...current, pinned: list.filter((item) => item !== id) })
    return true
  }
  if (list.length >= MAX_PINNED) return false
  publish({ ...current, pinned: [...list, id] })
  return true
}

export function setCollapsed(collapsed: string[]): void {
  publish({ ...current, collapsed })
}

export function noteUsedSize(id: string): void {
  publish({ ...current, recent: [id, ...current.recent.filter((item) => item !== id)].slice(0, MAX_RECENT) })
}

export function setSizeChoicesForTests(choices: Partial<SizeChoices> = {}): void {
  publish({ ...EMPTY, ...choices })
}

export function knownPresets(catalogue: SizePresetCatalogue, ids: readonly string[]): SizePreset[] {
  const out: SizePreset[] = []
  for (const id of ids) {
    const preset = catalogue.byId.get(id)
    if (preset && !out.includes(preset)) out.push(preset)
  }
  return out
}

export function yourSizes(catalogue: SizePresetCatalogue, choices: SizeChoices): SizePreset[] {
  return choices.pinned === null ? quickPresets(catalogue) : knownPresets(catalogue, choices.pinned)
}
