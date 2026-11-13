import { useSyncExternalStore } from 'react'
import { BUILTIN_PRESET_TREE } from "./builtin"
import { buildCatalogue, type SizePresetCatalogue } from "./catalogue"

export const BUILTIN_CATALOGUE = buildCatalogue(BUILTIN_PRESET_TREE) as SizePresetCatalogue

let current: SizePresetCatalogue = BUILTIN_CATALOGUE
const listeners = new Set<() => void>()

function publish(next: SizePresetCatalogue): void {
  current = next
  for (const listener of listeners) listener()
}

/** The local size preset catalogue. */
export function getSizePresets(): SizePresetCatalogue {
  return current
}

/** Resolves with the bundled catalogue. */
export function loadSizePresets(): Promise<SizePresetCatalogue> {
  return Promise.resolve(current)
}

/** Compatibility for callers that wait before resolving a local preset. */
export function sizePresetsReady(): Promise<SizePresetCatalogue> {
  return loadSizePresets()
}

/** Calls `listener` whenever local preset data changes. */
export function subscribeSizePresets(listener: () => void): () => void {
  listeners.add(listener)
  return () => listeners.delete(listener)
}

/** The size preset catalogue. */
export function useSizePresets(): SizePresetCatalogue {
  return useSyncExternalStore(subscribeSizePresets, getSizePresets, getSizePresets)
}

/** Tests: use `catalogue` (or the built-in one) without network access. */
export function setSizePresetsForTests(catalogue: SizePresetCatalogue | null = null): void {
  publish(catalogue ?? BUILTIN_CATALOGUE)
}

/** Tests: restore the built-in local catalogue. */
export function resetSizePresetsForTests(): void {
  publish(BUILTIN_CATALOGUE)
}
