import type { DoryDocument } from "@/types/document"
import type { ShareRole, VersionSummary } from "@/types/api"
import { http } from "./client"

export interface SharedDesign {
  design_id: string
  role: ShareRole
  title: string
  revision: number
  document: DoryDocument
  width: number
  height: number
  page_count: number
  fonts: unknown[]
}

export interface SharedSaveResult {
  design_id: string
  revision: number
  title: string
  updated_at: string
}

export const sharedApi = {
  get: (token: string, signal?: AbortSignal) => http.get<SharedDesign>(`/shared/${encodeURIComponent(token)}`, { signal }),
  patch: (token: string, input: { document: DoryDocument; expected_revision: number }) => http.patch<SharedSaveResult>(`/shared/${encodeURIComponent(token)}`, { json: input }),
  rename: (token: string, input: { title: string; expected_revision: number }) => http.patch<SharedSaveResult>(`/shared/${encodeURIComponent(token)}`, { json: input }),
  versions: {
    list: async (token: string) => (await http.get<{ versions: VersionSummary[] }>(`/shared/${encodeURIComponent(token)}/versions`)).versions,
    create: async (token: string, label: string) => (await http.post<{ version: VersionSummary }>(`/shared/${encodeURIComponent(token)}/versions`, { json: { label } })).version,
  },
  restoreVersion: (token: string, versionId: string, expectedRevision: number) => http.post<SharedSaveResult>(`/shared/${encodeURIComponent(token)}/versions/${encodeURIComponent(versionId)}/restore`, { json: { expected_revision: expectedRevision } }),
}
