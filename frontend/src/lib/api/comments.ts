import type { CommentInput, CommentMove, CommentT } from "@/types/api"
import { http } from "./client"

const designPath = (designId: string) => `/designs/${encodeURIComponent(designId)}/comments`
const sharedPath = (token: string) => `/shared/${encodeURIComponent(token)}/comments`

export const commentsApi = {
  listShared: (token: string): Promise<CommentT[]> => http.get(sharedPath(token)),
  createShared: (token: string, input: CommentInput) => http.post<CommentT>(sharedPath(token), { json: input }),
  list: (designId: string): Promise<CommentT[]> => http.get(designPath(designId)),
  create: (designId: string, input: CommentInput) => http.post<CommentT>(designPath(designId), { json: input }),
  resolve: (_designId: string, commentId: string, resolved: boolean) => http.patch<CommentT>(`/comments/${encodeURIComponent(commentId)}`, { json: { resolved } }),
  move: (_designId: string, commentId: string, to: CommentMove) => http.patch<CommentT>(`/comments/${encodeURIComponent(commentId)}`, { json: to }),
  remove: (_designId: string, commentId: string) => http.delete<void>(`/comments/${encodeURIComponent(commentId)}`),
}
