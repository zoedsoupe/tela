/** What can go wrong when a video is made, as codes the dialog turns into words (`dialogs/video/failure.ts`). */

export type VideoErrorCode =
  /** The options are not ones the format offers. */
  | 'invalid-options'
  /** No page is chosen. */
  | 'no-pages'
  /** The video would be longer than the format's limit. */
  | 'too-long'
  /** The browser has no encoder for the format. */
  | 'unsupported'
  /** The browser ran out of memory or refused a large allocation. */
  | 'memory'
  /** A GIF grew past what the browser can build. */
  | 'gif-too-large'
  /** The encoder reported an error part-way. */
  | 'encoder'
  /** A page could not be drawn (a font or a picture would not load). */
  | 'render'
  /** A video clip could not be read or decoded. */
  | 'clip'
  /** A video clip's file refused to be drawn into the video (its storage does not allow it: CORS). */
  | 'tainted'

export class VideoExportError extends Error {
  constructor(
    readonly code: VideoErrorCode,
    message: string,
    readonly detail?: string,
    options?: ErrorOptions,
  ) {
    super(message, options)
    this.name = "VideoExportError"
  }
}

export const isAbort = (error: unknown): boolean => error instanceof DOMException && error.name === "AbortError"

export function throwIfAborted(signal: AbortSignal | undefined): void {
  if (signal?.aborted) throw new DOMException("Exportação cancelada", "AbortError")
}

/** The errors a browser raises when it has no more memory to give. */
const MEMORY = /memory|allocation|quota|too large|out of range/i

/** Turns whatever was thrown into an error the dialog can name; an abort stays an abort. */
export function describeFailure(error: unknown): unknown {
  if (error instanceof VideoExportError || isAbort(error)) return error
  const name = error instanceof Error ? error.name : ''
  const message = error instanceof Error ? error.message : String(error)
  if (name === "ClipDecodeError") return new VideoExportError('clip', "Não foi possível ler um videoclipe.", message, { cause: error })
  if (name === 'SecurityError') return new VideoExportError('tainted', 'O clipe de vídeo não pôde ser lido pelo navegador.', message, { cause: error })
  if (name === 'RangeError' || name === 'QuotaExceededError' || MEMORY.test(message)) return new VideoExportError('memory', 'O navegador ficou sem memória.', message, { cause: error })
  if (name === 'NotSupportedError') return new VideoExportError('unsupported', 'O navegador não consegue codificar este vídeo.', message, { cause: error })
  if (name === 'EncodingError' || name === 'InvalidStateError' || name === 'OperationError') return new VideoExportError('encoder', 'O codificador de vídeo parou.', message, { cause: error })
  return new VideoExportError('render', "O vídeo não pôde ser feito.", message, { cause: error })
}
