import type { BrandKit, BrandKitInput } from "@/types/api"
import { http } from "./client"

export const brandApi = {
  list: (signal?: AbortSignal): Promise<BrandKit[]> => http.get<BrandKit[]>("/brand_kits", { signal }),
  get: (id: string) => http.get<BrandKit>(`/brand_kits/${encodeURIComponent(id)}`),
  create: (input: BrandKitInput) => http.post<BrandKit>("/brand_kits", { json: input }),
  update: (id: string, input: Partial<BrandKitInput>) => http.patch<BrandKit>(`/brand_kits/${encodeURIComponent(id)}`, { json: input }),
  remove: (id: string) => http.delete<void>(`/brand_kits/${encodeURIComponent(id)}`),
}
