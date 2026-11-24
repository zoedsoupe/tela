import { Copy, Download, Info } from 'lucide-react'
import { type ReactNode, useMemo, useRef, useState, useSyncExternalStore } from 'react'
import { useSizePresets } from "@/lib/sizePresets"
import { safeGetItem, safeSetItem } from "@/lib/storage"
import { useEditor, useEditorState } from "../context"
import { safeMultiplier } from "../engine/render"
import { DEFAULT_EXPORT_OPTIONS, type ExportOptions, type ExportStage, type QualityPreset, exportFilename, exportFormats, pageFilename, parsePageRange, sanitizeFilename } from "../engine/export/registry"
import { type PageSelection, copyPageAsPng, downloadFiles, pickPages, runExport } from "../engine/export/exporter"
import { designPreset, loadLastExport, saveLastExport } from "../engine/export/choices"
import { type FilenameStyle, unixNow } from "../engine/export/filenames"
import { pageMultiplier } from "../engine/export/formats"
import { type RasterFormat, isLossy } from "../engine/export/raster"
import { parseSize } from "../engine/export/size"
import { formatBytes } from "../engine/export/video/estimate"
import { zipFilename } from "../engine/export/zip"
import { getPageSize, sameSize } from "../engine/pageSizes"
import { t } from "../strings"
import { Button } from "../ui/Button"
import { Dialog } from "../ui/Dialog"
import { Segmented } from "../ui/Segmented"
import { Switch } from "../ui/Switch"
import type { VideoFormat } from "../engine/export/video/options"
import { LazyVideoSection } from "./VideoSectionLoader"
import { ComparePreview, type Zoom } from "./download/ComparePreview"
import { FormatPicker } from "./download/FormatPicker"
import { MoreSettings } from "./download/MoreSettings"
import { PageScope, type PageScope as PageScopeValue } from "./download/PageScope"
import { PageThumbs } from "./download/PageThumbs"
import { type Purpose, purposesFor } from "./download/purposes"
import { PurposeCards } from "./download/PurposeCards"
import { QualityControl } from "./download/QualityControl"
import { SizeField } from "./download/SizeField"
import { usePreview } from "./download/usePreview"
import styles from "./dialogs.module.css"
import dl from "./download/download.module.css"

type Timestamp = 'off' | 'on'
const STAGE_LABELS: Record<ExportStage, string> = { rendering: t.print.stage.rendering }
const RASTER_IDS = new Set(['png', 'jpg', 'webp'])
const rasterFormat = (id: string | undefined): RasterFormat | null => id && RASTER_IDS.has(id) ? id as RasterFormat : null

function startingPoint(editor: ReturnType<typeof useEditor>, asked: unknown, purposes: Purpose[]): { formatId: string; options: ExportOptions; purpose: string | null } {
  const fresh = (): ExportOptions => ({ ...DEFAULT_EXPORT_OPTIONS, size: '1x' })
  const usable = (id: string): boolean => {
    const format = exportFormats.get(id)
    return !!format && (!format.available || format.available(editor))
  }
  if (typeof asked === 'string' && usable(asked)) return { formatId: asked, options: fresh(), purpose: null }
  const own = purposes.find((purpose) => purpose.own && purpose.id === 'preset')
  if (own) return { formatId: own.formatId, options: own.options, purpose: own.id }
  const last = loadLastExport()
  if (last && usable(last.formatId)) return { formatId: last.formatId, options: last.options, purpose: null }
  return { formatId: 'png', options: fresh(), purpose: null }
}

interface PrintOptions {
  bleedMm: number
  cropMarks: boolean
}

export function DownloadDialog({ props }: { props?: Record<string, unknown> } = {}) {
  const editor = useEditor()
  const allFormats = useSyncExternalStore(exportFormats.subscribe, exportFormats.getSnapshot)
  const formats = allFormats.filter((format) => !format.available || format.available(editor))
  const doc = useEditorState((state) => state.doc)
  const catalogue = useSizePresets()
  const preset = useMemo(() => designPreset(editor), [editor, catalogue, doc]) // eslint-disable-line react-hooks/exhaustive-deps
  const purposes = useMemo(() => purposesFor(editor, preset), [editor, preset])
  const [start] = useState(() => startingPoint(editor, props?.format, purposes))
  const [formatId, setFormatId] = useState(() => formats.some((format) => format.id === start.formatId) ? start.formatId : formats[0]?.id ?? 'png')
  const [options, setOptions] = useState<ExportOptions>(() => start.options)
  const [purpose, setPurpose] = useState<string | null>(start.purpose)
  const [printOptions, setPrintOptions] = useState<PrintOptions>(() => ({ bleedMm: 0, cropMarks: false }))
  const [scope, setScope] = useState<PageScopeValue>('all')
  const [range, setRange] = useState('')
  const [progress, setProgress] = useState<number | null>(null)
  const [stage, setStage] = useState<ExportStage | undefined>()
  const [failure, setFailure] = useState<string | null>(null)
  const [zoom, setZoom] = useState<Zoom>('fit')
  const [moreOpen, setMoreOpen] = useState(false)
  const [footerSlot, setFooterSlot] = useState<HTMLElement | null>(null)
  const [videoLocked, setVideoLocked] = useState(false)
  const [nameStyle, setNameStyle] = useState<FilenameStyle>(() => safeGetItem('tela-export-filenames') === 'structured' ? 'structured' : 'simple')
  const [stamp, setStamp] = useState<Timestamp>(() => safeGetItem('tela-export-filename-timestamp') === 'on' ? 'on' : 'off')
  const [exampleUnix] = useState(unixNow)
  const abort = useRef<AbortController | null>(null)

  const format = formats.find((item) => item.id === formatId) ?? formats[0]
  const raster = rasterFormat(format?.id)
  const total = doc.pages.length
  const pageRange = useMemo(() => scope === 'range' ? parsePageRange(range, total) : null, [scope, range, total])
  const rangeInvalid = scope === 'range' && pageRange === null
  const busy = progress !== null
  const selected = useMemo<PageSelection>(() => scope === 'all' ? { kind: 'all' } : scope === 'current' ? { kind: 'current' } : { kind: 'pages', pages: pageRange ?? [] }, [scope, pageRange])
  const activePageId = useEditorState((state) => state.activePageId)
  const chosenPages = useMemo(() => rangeInvalid ? [] : pickPages(doc, activePageId, selected), [doc, activePageId, selected, rangeInvalid])
  const chosen = chosenPages.map(({ page }) => getPageSize(doc, page.id))
  const size = chosen[0] ?? editor.pageSizeOf(editor.state.activePageId)
  const mixed = chosen.some((current) => !sameSize(current, size))
  const video = format?.controls.video === true
  const pdf = format?.mime === 'application/pdf'
  const printing = format?.controls.print === true
  const files = chosen.length
  const zipped = files > 1 && !pdf && !video
  const sizeText = options.size ?? `${options.scale}x`
  const typed = parseSize(sizeText, size.width, size.height)
  const sizeValid = !raster || (typed !== null && chosen.every((current) => parseSize(sizeText, current.width, current.height) !== null))
  const wanted = typed ?? options.scale
  const clamped = !!raster && chosen.some((current) => safeMultiplier(current.width, current.height, pageMultiplier(options, current)) < pageMultiplier(options, current) - 1e-6)
  const multiplier = safeMultiplier(size.width, size.height, wanted)
  const pixels = sizeValid ? { width: Math.round(size.width * multiplier), height: Math.round(size.height * multiplier) } : null
  const [shown, setShown] = useState(() => Math.max(0, doc.pages.findIndex((page) => page.id === activePageId)))
  const shownIndex = Math.min(shown, total - 1)
  const shownPage = doc.pages[shownIndex] ?? null
  const shownSize = shownPage ? getPageSize(doc, shownPage.id) : size
  const rasterFormats = formats.filter((item) => RASTER_IDS.has(item.id)).map((item) => item.id as RasterFormat)
  const preview = usePreview({ engine: editor, page: shownPage, size: shownSize, format: raster, options, formats: rasterFormats })
  const quality = Math.round(options.quality * 100)
  const perPage = raster ? preview.sizes[raster] : undefined
  const totalBytes = perPage !== undefined ? perPage * Math.max(1, files) : undefined

  const exampleName = (): string => {
    if (!format) return ''
    const naming = { style: nameStyle, unix: stamp === 'on' ? exampleUnix : null }
    const title = editor.state.title
    if (zipped) return zipFilename(title, naming)
    const first = chosenPages[0]
    const ctx = { document: doc, title, naming }
    const simple = pdf || video
      ? `${sanitizeFilename(title) || 'design'}.${format.extension}`
      : pageFilename(title, format.extension, (first?.index ?? 0) + 1, chosenPages.length, total)
    const perPageFile = !pdf && !video
    return exportFilename(ctx, simple, format.extension, size, perPageFile ? first?.index ?? 0 : null)
  }

  const patch = (next: Partial<ExportOptions>): void => setOptions((current) => ({ ...current, ...next }))
  const changeScope = (next: PageScopeValue): void => {
    setScope(next)
    if (next === 'current') setShown(Math.max(0, doc.pages.findIndex((page) => page.id === activePageId)))
    if (next === 'range') {
      const first = parsePageRange(range, total)?.[0]
      if (first !== undefined) setShown(first - 1)
    }
  }
  const changeRange = (text: string): void => {
    setRange(text)
    const first = parsePageRange(text, total)?.[0]
    if (first !== undefined) setShown(first - 1)
  }
  const pickFormat = (id: string): void => {
    setFormatId(id)
    setPurpose(null)
    if (id === 'jpg') patch({ transparent: false })
  }
  const pickPurpose = (choice: Purpose): void => {
    setPurpose(choice.id)
    setFormatId(choice.formatId)
    setOptions(choice.options)
    if (choice.print) setPrintOptions(choice.print === 'standard' ? { bleedMm: 3, cropMarks: true } : { bleedMm: 0, cropMarks: false })
  }

  const download = async (): Promise<void> => {
    if (!format || rangeInvalid || chosenPages.length === 0 || !sizeValid) return
    setFailure(null)
    setProgress(0)
    setStage(undefined)
    const controller = new AbortController()
    abort.current = controller
    const effective: ExportOptions = printing ? { ...options, ...printOptions } : { ...options, size: raster ? sizeText : options.size }
    try {
      const output = await runExport(editor, {
        formatId: format.id,
        pages: selected,
        options: effective,
        onProgress: (fraction, next) => {
          setProgress(fraction)
          setStage(next)
        },
        signal: controller.signal,
        filenames: { style: nameStyle, timestamp: stamp === 'on' },
      })
      downloadFiles(output)
      saveLastExport({ formatId: format.id, options: effective })
      editor.toast(t.dialog.downloadDone, 'success')
      editor.closeDialog()
    } catch (error) {
      if (error instanceof DOMException && error.name === 'AbortError') editor.toast(t.print.cancelled)
      else setFailure(error instanceof Error ? error.message : t.dialog.downloadFailed)
      setProgress(null)
    }
  }

  const copy = async (): Promise<void> => {
    setFailure(null)
    try {
      await copyPageAsPng(editor)
      editor.toast(t.dialog.downloadCopied, 'success')
    } catch (error) {
      setFailure(error instanceof Error ? error.message : t.dialog.downloadFailed)
    }
  }

  const close = (): void => {
    abort.current?.abort()
    editor.closeDialog()
  }

  const formatHint = (): ReactNode => {
    if (!format) return null
    if (video) return <small className={dl.hint}>{t.dialog.downloadVideoNext}</small>
    if (raster && preset?.formats && !preset.formats.some((item) => (item === 'jpeg' ? 'jpg' : item) === raster)) {
      return <small className={`${dl.hint} ${dl.warn}`}><Info size={14} aria-hidden="true" />{t.dialog.downloadNotAccepted(preset.label, preset.formats.map((item) => item.toUpperCase()).join(', '))}</small>
    }
    return format.description ? <small className={dl.hint}>{format.description}</small> : null
  }

  const tag = raster && format ? `${format.label}${isLossy(raster) ? ` ${quality}` : ''}${perPage !== undefined ? ` · ${formatBytes(perPage)}` : ''}` : null
  const summary = (): ReactNode => {
    if (!format) return null
    if (raster) return <><b>{t.dialog.downloadFiles(files, format.label)}</b>{zipped ? ` ${t.dialog.downloadInZip}` : ''}{pixels && !mixed ? ` · ${pixels.width} × ${pixels.height}` : ''}{totalBytes !== undefined ? <> · <b>≈ {formatBytes(totalBytes)}</b></> : null}</>
    if (pdf) return <><b>1 PDF</b> · {t.dialog.downloadPdfSummary(files, printing && (printOptions.bleedMm > 0 || printOptions.cropMarks))}</>
    return <><b>{t.dialog.downloadFiles(files, format.label)}</b>{zipped ? ` ${t.dialog.downloadInZip}` : ''}</>
  }

  const chosenIndexes = useMemo(() => new Set(chosenPages.map((page) => page.index)), [chosenPages])
  const aside = (
    <section className={dl.preview} aria-label={t.dialog.downloadPreview}>
      <div className={dl.previewBar}>
        <span className={dl.pill}>{t.dialog.downloadPageOf(shownIndex + 1, total)}</span>
        <span className={dl.spacer} />
        {raster ? <div className={dl.zoom} role="group" aria-label={t.dialog.downloadZoom}>{(['fit', 'detail'] as const).map((item) => <button key={item} type="button" className={zoom === item ? dl.on : ''} aria-pressed={zoom === item} onClick={() => setZoom(item)}>{item === 'fit' ? t.dialog.downloadFit : t.dialog.downloadDetail}</button>)}</div> : null}
      </div>
      {preview.failed ? <p className={dl.previewFailed}>{t.dialog.downloadPreviewFailed}</p> : <ComparePreview before={preview.original} after={raster ? preview.after : null} size={shownSize} zoom={raster ? zoom : 'fit'} tag={tag} />}
      <PageThumbs pages={doc.pages} shown={shownIndex} chosen={chosenIndexes} onShow={setShown} hint={raster ? (zoom === 'detail' ? t.dialog.downloadDetailHint : t.dialog.downloadDragHint) : ''} />
    </section>
  )

  const pictures = formats.filter((item) => RASTER_IDS.has(item.id))
  const otherFormats = formats.filter((item) => !RASTER_IDS.has(item.id))
  const downloadLabel = busy ? t.dialog.downloadWorking : zipped ? t.dialog.downloadNFiles(files) : t.dialog.downloadButton

  return (
    <Dialog title={t.dialog.downloadTitle} onClose={close} width={1080} aside={aside} footer={
      video
        ? <div ref={setFooterSlot} style={{ display: 'flex', flex: 1, alignItems: 'center', gap: "var(--espaço-2)", minWidth: 0 }} />
        : <><p className={dl.summary} data-testid="download-summary">{summary()}</p>{busy ? <Button onClick={() => abort.current?.abort()}>{t.print.cancel}</Button> : <Button icon={<Copy size={16} />} onClick={() => void copy()}>{t.dialog.downloadCopy}</Button>}<Button variant="primary" icon={<Download size={16} />} onClick={() => void download()} disabled={busy || rangeInvalid || chosenPages.length === 0 || !format || !sizeValid}>{downloadLabel}</Button></>
    }>
      <div className={dl.side}>
        <fieldset className={dl.plain} disabled={videoLocked}><PurposeCards purposes={purposes} value={purpose} onPick={pickPurpose} /></fieldset>
        <FormatPicker pictures={pictures} others={otherFormats} value={format?.id ?? ''} onChange={pickFormat} sizes={preview.sizes} approximate={preview.approximate} transparent={options.transparent} hint={formatHint()} disabled={videoLocked} />
        {raster && isLossy(raster) ? <QualityControl value={quality} preset={options.qualityPreset} onChange={(value: number, stop?: QualityPreset) => patch({ quality: value / 100, qualityPreset: stop, maxBytes: undefined })} maxBytes={options.maxBytes} onMaxBytes={(bytes) => patch({ maxBytes: bytes })} estimate={perPage !== undefined ? t.dialog.downloadPerPageSize(formatBytes(perPage)) : null} /> : null}
        {raster ? <SizeField value={options.size ?? `${options.scale}x`} onChange={(value) => patch({ size: value })} pixels={pixels} mixed={mixed} clamped={clamped} extra={preset ? [`${preset.width}w`] : []} /> : null}
        {printing ? (
          <section className={dl.section}>
            <h3 className={dl.label}>{t.print.section}</h3>
            <label className={styles.field}><span>{t.print.bleed}</span><input className={styles.input} type="number" min="0" max="10" step="0.5" value={printOptions.bleedMm} aria-label={t.print.bleed} onChange={(event) => setPrintOptions((current) => ({ ...current, bleedMm: Math.min(10, Math.max(0, Number(event.target.value) || 0)) }))} /></label>
            <Switch label={t.print.cropMarks} checked={printOptions.cropMarks} onChange={(cropMarks) => setPrintOptions((current) => ({ ...current, cropMarks }))} />
            <small className={dl.hint}>{t.print.colour}</small>
          </section>
        ) : null}
        {video && format ? <LazyVideoSection format={format.id as VideoFormat} pages={chosenPages} rangeInvalid={rangeInvalid} footer={footerSlot} onLockChange={setVideoLocked} /> : null}
        <div inert={videoLocked} style={videoLocked ? { opacity: 0.6 } : undefined}>
          <PageScope total={total} value={scope} range={range} rangeInvalid={rangeInvalid} zipped={zipped} onChange={changeScope} onRangeChange={changeRange} />
          <MoreSettings open={moreOpen} onToggle={() => setMoreOpen((open) => !open)} summary={(nameStyle === 'simple' ? t.dialog.downloadNamesSimple : t.dialog.downloadNamesStructured).toLowerCase()}>
            <div className={styles.field}>
              <span>{t.dialog.downloadNames}</span>
              <Segmented label={t.dialog.downloadNames} value={nameStyle} onChange={(next) => { setNameStyle(next); safeSetItem('tela-export-filenames', next) }} options={[{ value: 'simple', label: t.dialog.downloadNamesSimple }, { value: 'structured', label: t.dialog.downloadNamesStructured }]} />
              {nameStyle === 'structured' ? <Switch label={t.dialog.downloadNamesTimestamp} checked={stamp === 'on'} onChange={(enabled) => { const next = enabled ? 'on' : 'off'; setStamp(next); safeSetItem('tela-export-filename-timestamp', next) }} /> : null}
              <small className={styles.muted} data-testid="download-filename">{t.dialog.downloadNamesExample(exampleName())}</small>
            </div>
            {format?.controls.transparent ? <Switch label={t.dialog.downloadTransparent} hint={t.dialog.downloadTransparentHint} checked={options.transparent} onChange={(transparent) => patch({ transparent })} /> : null}
          </MoreSettings>
        </div>
        {busy ? <div className={styles.field}><div role="progressbar" aria-valuemin={0} aria-valuemax={100} aria-valuenow={Math.round((progress ?? 0) * 100)} aria-label={t.dialog.downloadWorking} className={styles.progress}><div style={{ width: `${Math.max(4, (progress ?? 0) * 100)}%` }} /></div>{stage ? <p className={dl.hint} role="status" data-testid="export-stage">{STAGE_LABELS[stage]}</p> : null}</div> : null}
        {failure ? <p className={styles.error} role="alert">{failure}</p> : null}
      </div>
    </Dialog>
  )
}
