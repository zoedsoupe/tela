import type { ShareLink, ShareLinkInput } from "@/types/api"
import type { ShareLinkPatch } from "@/types/adapter"
import { http } from "./client"

function shareLink(raw: ShareLink): ShareLink {
  return { ...raw, token: raw.token ?? '', url: raw.url ?? '', is_active: raw.is_active === true }
}

export const sharesApi = {
  list: async (designId: string): Promise<ShareLink[]> => (await http.get<ShareLink[]>(`/designs/${encodeURIComponent(designId)}/share_links`)).map(shareLink),
  create: async (designId: string, input: ShareLinkInput): Promise<ShareLink> => shareLink(await http.post<ShareLink>(`/designs/${encodeURIComponent(designId)}/share_links`, { json: input })),
  update: async (id: string, patch: ShareLinkPatch, current?: ShareLink): Promise<ShareLink> => {
    if (patch.is_active === false) {
      if (!current) throw new Error('O link precisa ser recarregado antes de ser revogado.')
      const link = current
      await http.delete<void>(`/share_links/${encodeURIComponent(id)}`)
      return { ...link, is_active: false }
    }
    if (patch.is_active === true) throw new Error('Links revogados não podem ser reativados; crie um novo link.')
    return shareLink(await http.patch<ShareLink>(`/share_links/${encodeURIComponent(id)}`, { json: patch }))
  },
  revoke: (id: string) => http.delete<void>(`/share_links/${encodeURIComponent(id)}`),
}
