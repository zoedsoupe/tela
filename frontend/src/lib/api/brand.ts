import type { BrandKit, BrandKitInput, Page } from "@/types/api"
import { http } from "./client"
import { toList } from "./pagination"

export const brandApi = {
  list: async (signal?: AbortSignal): Promise<BrandKit[]> => toList(await http.get<Page<BrandKit> | BrandKit[]>("/brand-kits/", { signal })),
  get: (id: string) => http.get<BrandKit>(`/kits-de-marca/${id}/`),
  create: (input: BrandKitInput) => http.post<BrandKit>("/brand-kits/", { json: input }),
  update: (id: string, input: Partial<BrandKitInput>) => http.patch<BrandKit>(`/kits-de-marca/${id}/`, { json: input }),
  remove: (id: string) => http.delete<void>(`/kits-de-marca/${id}/`),
}
