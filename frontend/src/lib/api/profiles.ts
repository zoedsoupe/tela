import { http } from "./client"

export interface Profile {
  id: string
  name: string
  created_at: string
  updated_at: string
}

export interface ProfilesResponse {
  profiles: Profile[]
  current_profile: Profile | null
}

export const profilesApi = {
  list: (signal?: AbortSignal) => http.get<ProfilesResponse>("/profiles", { signal }),
  create: async (name: string): Promise<Profile> => (await http.post<{ profile: Profile }>("/profiles", { json: { name } })).profile,
  select: (profileId: string): Promise<Profile | null> => http.post<{ current_profile: Profile | null }>("/profiles/select", { json: { profile_id: profileId } }).then((response) => response.current_profile),
  clear: async (): Promise<void> => { await http.delete<{ current_profile: null }>("/profiles/select") },
}
