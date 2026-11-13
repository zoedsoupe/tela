import { isApiError } from "@/lib/api"

/** A short, user-presentable description of any thrown error. */
export function errorMessage(error: unknown, fallback = "Por favor, tente novamente."): string {
  if (isApiError(error)) return error.isNetwork ? "Você parece estar off-line." : error.message
  return fallback
}
