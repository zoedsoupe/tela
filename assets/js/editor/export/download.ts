export function sanitizeExportFilename(name: string, extension: string): string {
  const safeName = name.normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-zA-Z0-9_-]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 80) || 'tela-exportacao'
  const safeExtension = extension.replace(/^\.+/, '').replace(/[^a-zA-Z0-9]/g, '').toLowerCase()
  return safeExtension ? `${safeName}.${safeExtension}` : safeName
}

export function downloadBlob(blob: Blob, filename: string): void {
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  link.href = url
  link.download = filename
  link.click()
  window.setTimeout(() => URL.revokeObjectURL(url), 0)
}
