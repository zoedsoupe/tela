/** The language a browser-generated PDF declares for its text. */
export function documentLanguage(): string {
  const lang = typeof document === 'undefined' ? '' : document.documentElement.lang
  return /^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8}){0,3}$/.test(lang) ? lang : 'pt-BR'
}
