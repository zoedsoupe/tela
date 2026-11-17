import type { FolderT, Page } from "@/types/api"
import { http } from "./client"
import { toList } from "./pagination"

type FolderEnvelope = { folder: Record<string, unknown> }

function folder(raw: Record<string, unknown>): FolderT {
  const parent = typeof raw.parent_id === 'string' ? raw.parent_id : typeof raw.parent === 'string' ? raw.parent : null
  return {
    id: String(raw.id ?? ''),
    name: typeof raw.name === 'string' ? raw.name : '',
    parent,
    parent_id: parent,
    design_count: Number(raw.design_count ?? 0),
    created_at: typeof raw.created_at === 'string' ? raw.created_at : '',
  }
}

export const foldersApi = {
  list: async (signal?: AbortSignal): Promise<FolderT[]> => {
    const response = await http.get<{ folders: Array<Record<string, unknown>> } | Page<FolderT> | FolderT[]>("/folders", { signal })
    return (Array.isArray(response) || 'results' in response ? toList(response as Page<FolderT> | FolderT[]) : response.folders).map((item) => folder(item as unknown as Record<string, unknown>))
  },
  create: async (input: { name: string; parent?: string | null; parent_id?: string | null }) => folder((await http.post<FolderEnvelope>("/folders", { json: { name: input.name, parent_id: input.parent_id ?? input.parent ?? null } })).folder),
  rename: async (id: string, name: string) => folder((await http.patch<FolderEnvelope>(`/folders/${encodeURIComponent(id)}`, { json: { name } })).folder),
  move: async (id: string, parent: string | null) => folder((await http.patch<FolderEnvelope>(`/folders/${encodeURIComponent(id)}`, { json: { parent_id: parent } })).folder),
  remove: (id: string) => http.delete<void>(`/folders/${encodeURIComponent(id)}`),
}
