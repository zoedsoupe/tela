import { usePageMeta } from "./usePageMeta"

/** Sets `document.title` to "<title> · Tela" while the component is mounted. */
export function usePageTitle(title: string | null | undefined): void {
  usePageMeta({ title })
}
