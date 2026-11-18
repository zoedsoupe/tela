import { Trash2 } from 'lucide-react'
import { useCallback, useEffect, useRef, useState } from 'react'
import type { AssetRef } from "@/types/adapter"
import type { Asset, StockPage, StockPhoto, StockProviderError, StockProviderFilter } from "@/types/api"
import { I } from "../chrome/icons"
import { useEditor, useEditorState, useEditorStateShallow } from "../context"
import { imageFilesFrom } from "../engine/files"
import { useAsyncList } from "../hooks/useAsyncList"
import { useResolvedSrc } from "../hooks/useResolvedSrc"
import type { PanelProps } from "../panels/registry"
import { t } from "../strings"
import { loadable } from "../ui/loadable"
import { Skeleton } from "../ui/Skeleton"
import ed from "../chrome/ed.module.css"
import styles from "./Drawers.module.css"
import { beginImageAssetDrag, endImageAssetDrag } from "./imageAssetDrag"
import { uploadToLibrary } from "./uploads"

function toRef(a: Asset): AssetRef {
  return { id: a.id, url: a.url, thumbUrl: a.thumb_url, width: a.width, height: a.height, name: a.name, kind: a.kind }
}

function Thumb({ asset, onPlace, onDelete }: { asset: AssetRef; onPlace: () => void; onDelete?: () => void }) {
  const url = useResolvedSrc(asset.thumbUrl || asset.url)
  const draggable = asset.kind === 'image' || asset.kind === 'svg'
  return (
    <div className={styles.thumbRow}>
      <button
        type="button"
        className={ed.uploadedThumb}
        data-testid="uploaded-thumb"
        draggable={draggable}
        onClick={onPlace}
        onDragStart={(event) => {
          if (!beginImageAssetDrag(event.dataTransfer, asset)) event.preventDefault()
        }}
        onDragEnd={endImageAssetDrag}
      >
        {url ? <img src={url} alt="" draggable={false} /> : <Skeleton width={40} height={40} radius={5} />}
        <span className={ed.uploadedName}>{asset.name}</span>
      </button>
      {onDelete ? (
        <button type="button" className={styles.thumbDelete} aria-label={t.imageDrawer.remove(asset.name)} title={t.imageDrawer.remove(asset.name)} onClick={onDelete}>
          <Trash2 size={14} aria-hidden="true" />
        </button>
      ) : null}
    </div>
  )
}

/** Uploads tab: the "Upload photo" zone and the list of images, plus drag and drop and delete. */
function UploadsTab({ close }: PanelProps) {
  const editor = useEditor()
  const session = useEditorStateShallow((s) => s.uploads)
  const uploading = useEditorState((s) => s.uploading)
  const library = useAsyncList<Asset>((page) => editor.adapter.services.assets.list({ page, page_size: 20 }), 'library')
  const [removed, setRemoved] = useState<ReadonlySet<string>>(new Set())
  const [over, setOver] = useState(false)
  const [failed, setFailed] = useState(false)

  const sessionIds = new Set(session.map((u) => u.id))
  const images: AssetRef[] = [...session, ...library.items.filter((a) => !sessionIds.has(a.id)).map(toRef)].filter((a) => !removed.has(a.id))

  const place = (asset: AssetRef): void => {
    void editor.insert.imageFromAsset(asset)
    close()
  }
  const remove = async (asset: AssetRef): Promise<void> => {
    setFailed(false)
    try {
      await editor.adapter.services.assets.remove(asset.id)
      setRemoved((cur) => new Set(cur).add(asset.id))
      editor.toast(t.imageDrawer.removed, 'info')
    } catch {
      setFailed(true)
    }
  }
  const onDrop = (e: React.DragEvent): void => {
    setOver(false)
    const files = imageFilesFrom(e.dataTransfer)
    if (files.length === 0) return
    e.preventDefault()
    void uploadToLibrary(editor, files)
  }

  return (
    <>
      <p className={ed.sectionTitle}>{t.drawers.uploadPhoto}</p>
      <button
        type="button"
        className={ed.uploadZone}
        data-testid="upload-zone"
        data-over={over || undefined}
        onClick={() => void editor.insert.pickAndUpload()}
        onDragOver={(e) => {
          if (!e.dataTransfer.types.includes("Arquivos")) return
          e.preventDefault()
          setOver(true)
        }}
        onDragLeave={() => setOver(false)}
        onDrop={onDrop}
      >
        {I.upload}
        <div>{t.drawers.clickToUpload}</div>
        <small>{t.imageDrawer.dropHere}</small>
      </button>
      {uploading > 0 ? (
        <div className={styles.status} role="status">
          <span className={styles.spinner} aria-hidden="true" />
          {t.imageDrawer.uploading(uploading)}
        </div>
      ) : null}
      {failed ? (
        <p className={styles.error} role="alert">
          {t.imageDrawer.removeFailed}
        </p>
      ) : null}
      {images.length > 0 ? (
        <>
          <p className={ed.sectionTitle} style={{ marginTop: 16 }}>
            {t.drawers.yourImages}
          </p>
          {images.map((img) => (
            <Thumb key={img.id} asset={img} onPlace={() => place(img)} onDelete={library.items.some((a) => a.id === img.id) || sessionIds.has(img.id) ? () => void remove(img) : undefined} />
          ))}
        </>
      ) : null}
      {library.error && images.length === 0 ? (
        <p className={styles.error} role="alert">
          {t.imageDrawer.libraryFailed}
        </p>
      ) : null}
      {library.hasMore && library.items.length > 0 ? (
        <button type="button" className={`${ed.btn} ${ed.ghost}`} style={{ width: '100%', marginTop: 8 }} onClick={library.loadMore} disabled={library.loading}>
          {t.imageDrawer.loadMore}
        </button>
      ) : null}
      {!library.loading && !library.error && images.length === 0 ? <p className={styles.note}>{t.imageDrawer.noImages}</p> : null}
    </>
  )
}

const STOCK_FILTERS: ReadonlyArray<{ id: StockProviderFilter; label: string }> = [
  { id: 'all', label: t.imageDrawer.all },
  { id: 'pixabay', label: t.imageDrawer.providers.pixabay },
  { id: 'wikimedia', label: t.imageDrawer.providers.wikimedia },
  { id: 'pexels', label: t.imageDrawer.providers.pexels },
  { id: 'unsplash', label: t.imageDrawer.providers.unsplash },
]

function providerLabel(provider: string): string {
  if (provider === 'pixabay' || provider === 'wikimedia' || provider === 'pexels' || provider === 'unsplash') {
    return t.imageDrawer.providers[provider]
  }
  return provider
}

function providerError(error: StockProviderError): string {
  const name = providerLabel(error.provider)
  if (error.code === 'busy') return t.imageDrawer.skippedReason.busy(name)
  if (error.code === 'timeout') return t.imageDrawer.skippedReason.timeout(name)
  return t.imageDrawer.skippedReason.unavailable(name)
}

function mergeErrors(current: StockProviderError[], incoming: StockProviderError[]): StockProviderError[] {
  const merged = new Map(current.map((error) => [`${error.provider}:${error.code}`, error]))
  for (const error of incoming) merged.set(`${error.provider}:${error.code}`, error)
  return [...merged.values()]
}

function nextPageOf(page: StockPage): number | null {
  if (page.next === null) return null
  const next = Number(page.next)
  return Number.isInteger(next) && next > 0 ? next : null
}

/** Stock tab: external URLs are previews; inserted images use the imported asset, which may stay hotlinked. */
function StockTab({ close }: PanelProps) {
  const editor = useEditor()
  const service = editor.adapter.services.assets.stock
  const [query, setQuery] = useState('')
  const [provider, setProvider] = useState<StockProviderFilter>('all')
  const [items, setItems] = useState<StockPhoto[]>([])
  const [errors, setErrors] = useState<StockProviderError[]>([])
  const [nextPage, setNextPage] = useState<number | null>(null)
  const [loading, setLoading] = useState(false)
  const [failed, setFailed] = useState(false)
  const [loadingMore, setLoadingMore] = useState(false)
  const [moreFailed, setMoreFailed] = useState(false)
  const [retry, setRetry] = useState(0)
  const [importing, setImporting] = useState<ReadonlySet<string>>(new Set())
  const [failedImports, setFailedImports] = useState<ReadonlySet<string>>(new Set())
  const latestSearch = useRef(0)
  const currentSearch = useRef({ query: '', provider: 'all' as StockProviderFilter })

  const fetchPage = useCallback(async (
    searchQuery: string,
    selectedProvider: StockProviderFilter,
    pageNumber: number,
    append: boolean,
    searchId: number,
  ): Promise<void> => {
    if (!service) return
    if (append) {
      setLoadingMore(true)
      setMoreFailed(false)
    } else {
      setLoading(true)
    }
    try {
      const result = await service.search({ q: searchQuery, provider: selectedProvider, page: pageNumber })
      if (
        latestSearch.current !== searchId
        || currentSearch.current.query.trim() !== searchQuery
        || currentSearch.current.provider !== selectedProvider
      ) return
      setItems((current) => append ? [...current, ...result.results] : result.results)
      setErrors((current) => append ? mergeErrors(current, result.errors) : result.errors)
      setNextPage(nextPageOf(result))
      setFailed(false)
      setMoreFailed(false)
    } catch {
      if (
        latestSearch.current !== searchId
        || currentSearch.current.query.trim() !== searchQuery
        || currentSearch.current.provider !== selectedProvider
      ) return
      if (append) setMoreFailed(true)
      else setFailed(true)
    } finally {
      if (
        latestSearch.current === searchId
        && currentSearch.current.query.trim() === searchQuery
        && currentSearch.current.provider === selectedProvider
      ) {
        setLoading(false)
        setLoadingMore(false)
      }
    }
  }, [service])

  useEffect(() => {
    const searchId = ++latestSearch.current
    const searchQuery = query.trim()

    if (!service || searchQuery.length < 2) {
      return () => {
        if (latestSearch.current === searchId) latestSearch.current += 1
      }
    }

    const timer = window.setTimeout(() => {
      void fetchPage(searchQuery, provider, 1, false, searchId)
    }, 300)
    return () => {
      window.clearTimeout(timer)
      if (latestSearch.current === searchId) latestSearch.current += 1
    }
  }, [fetchPage, provider, query, retry, service])

  const resetSearchState = (searchQuery: string): void => {
    setItems([])
    setErrors([])
    setNextPage(null)
    setLoading(searchQuery.trim().length >= 2)
    setFailed(false)
    setLoadingMore(false)
    setMoreFailed(false)
  }
  const changeQuery = (value: string): void => {
    currentSearch.current = { query: value, provider: currentSearch.current.provider }
    latestSearch.current += 1
    resetSearchState(value)
    setQuery(value)
  }
  const changeProvider = (value: StockProviderFilter): void => {
    currentSearch.current = { query: currentSearch.current.query, provider: value }
    latestSearch.current += 1
    resetSearchState(currentSearch.current.query)
    setProvider(value)
  }
  const loadMore = (): void => {
    if (nextPage === null || loadingMore) return
    void fetchPage(query.trim(), provider, nextPage, true, latestSearch.current)
  }
  const retryMore = (): void => {
    if (nextPage === null) return
    void fetchPage(query.trim(), provider, nextPage, true, latestSearch.current)
  }
  const retrySearch = (): void => {
    resetSearchState(query)
    setRetry((current) => current + 1)
  }
  const importPhoto = async (photo: StockPhoto): Promise<void> => {
    const id = `${photo.provider}:${photo.external_id}`
    setFailedImports((current) => {
      const next = new Set(current)
      next.delete(id)
      return next
    })
    setImporting((current) => new Set(current).add(id))
    try {
      const asset = await service?.import(photo.provider, photo.external_id)
      if (!asset) return
      await editor.insert.imageFromAsset(toRef(asset))
      close()
    } catch {
      setFailedImports((current) => new Set(current).add(id))
    } finally {
      setImporting((current) => {
        const next = new Set(current)
        next.delete(id)
        return next
      })
    }
  }

  const normalizedQuery = query.trim()
  const providerErrors = errors.map(providerError)

  return (
    <>
      <div className={styles.search}>
        <span aria-hidden="true">{I.search}</span>
        <input
          type="text"
          value={query}
          onChange={(event) => changeQuery(event.target.value)}
          placeholder={t.imageDrawer.searchStock}
          aria-label={t.imageDrawer.searchStock}
          data-testid="stock-search"
        />
      </div>
      <div className={styles.sources} role="group" aria-label={t.imageDrawer.sources}>
        {STOCK_FILTERS.map((filter) => (
          <button
            key={filter.id}
            type="button"
            className={styles.source}
            aria-pressed={provider === filter.id}
            data-testid={`stock-provider-${filter.id}`}
            onClick={() => changeProvider(filter.id)}
          >
            {filter.label}
          </button>
        ))}
      </div>
      {loading && items.length === 0 ? (
        <div className={styles.status} role="status">
          <span className={styles.spinner} aria-hidden="true" />
          {t.imageDrawer.stockLoading}
        </div>
      ) : null}
      {failed ? (
        <div className={styles.error} role="alert">
          {t.imageDrawer.stockFailed}
          <button type="button" className={`${ed.btn} ${ed.ghost}`} onClick={retrySearch}>
            {t.lazy.retry}
          </button>
        </div>
      ) : null}
      {providerErrors.length > 0 ? (
        <p className={styles.note} role="status">
          {t.imageDrawer.stockPartial(t.imageDrawer.listNames(providerErrors))}
        </p>
      ) : null}
      {items.length > 0 ? (
        <div className={styles.photos}>
          {items.map((photo) => {
            const id = `${photo.provider}:${photo.external_id}`
            const name = providerLabel(photo.provider)
            const author = photo.author ?? ''
            const isUnsplash = photo.provider === 'unsplash'
            const altText = isUnsplash ? t.imageDrawer.unsplashCredit(author) : t.imageDrawer.photoByOn(author, name)
            return (
              <div className={styles.stockTile} key={id}>
                <button
                  type="button"
                  className={styles.photo}
                  aria-label={altText}
                  title={altText}
                  data-testid={`stock-photo-${photo.external_id}`}
                  disabled={importing.has(id)}
                  onClick={() => void importPhoto(photo)}
                >
                  <img src={photo.thumb_url} alt="" draggable={false} />
                  {!isUnsplash ? <span className={styles.credit}>{altText}</span> : null}
                  {importing.has(id) ? <span className={styles.badge}>{t.imageDrawer.importing}</span> : null}
                </button>
                {isUnsplash ? (
                  <p className={styles.stockCredit}>
                    {author ? (
                      <>
                        <span>{t.imageDrawer.unsplashPhotoBy} </span>
                        {photo.author_url ? <a href={photo.author_url} target="_blank" rel="noreferrer">{author}</a> : <span>{author}</span>}
                        <span> {t.imageDrawer.unsplashOn} </span>
                      </>
                    ) : <span>{t.imageDrawer.unsplashPhoto} {t.imageDrawer.unsplashOn} </span>}
                    {photo.source_url ? <a href={photo.source_url} target="_blank" rel="noreferrer">{t.imageDrawer.providers.unsplash}</a> : <span>{t.imageDrawer.providers.unsplash}</span>}
                  </p>
                ) : null}
                {failedImports.has(id) ? <p className={styles.error} role="alert">{t.imageDrawer.importFailed}</p> : null}
              </div>
            )
          })}
        </div>
      ) : null}
      {loadingMore ? (
        <div className={styles.status} role="status">
          <span className={styles.spinner} aria-hidden="true" />
          {t.imageDrawer.stockLoading}
        </div>
      ) : null}
      {moreFailed ? (
        <div className={styles.error} role="alert">
          {t.imageDrawer.stockFailed}
          <button type="button" className={`${ed.btn} ${ed.ghost}`} onClick={retryMore}>
            {t.lazy.retry}
          </button>
        </div>
      ) : null}
      {nextPage !== null ? (
        <button type="button" className={`${ed.btn} ${ed.ghost}`} style={{ width: '100%', marginTop: 8 }} onClick={loadMore} disabled={loadingMore}>
          {t.imageDrawer.loadMore}
        </button>
      ) : null}
      {!loading && !failed && normalizedQuery.length < 2 ? <p className={styles.note}>{t.imageDrawer.stockHint}</p> : null}
      {!loading && !failed && normalizedQuery.length >= 2 && items.length === 0 ? <p className={styles.note}>{t.imageDrawer.stockEmpty}</p> : null}
    </>
  )
}

const GridTab = loadable(() => import("./GridTab").then((m) => m.GridTab))

/** Image drawer: local uploads, optional stock photography, and image-grid layouts. */
export function ImageDrawer(props: PanelProps) {
  const editor = useEditor()
  const hasStock = editor.adapter.services.assets.stock !== undefined
  const [tab, setTab] = useState<'uploads' | 'stock' | 'grids'>('uploads')
  const moveBetweenTabs = (e: React.KeyboardEvent<HTMLDivElement>): void => {
    if (e.key !== "ArrowLeft" && e.key !== "ArrowRight") return
    const tabs = [...e.currentTarget.querySelectorAll<HTMLButtonElement>("[role=\"tab\"]")]
    const current = tabs.indexOf(document.activeElement as HTMLButtonElement)
    if (current < 0) return
    e.preventDefault()
    const offset = e.key === "ArrowRight" ? 1 : -1
    const next = tabs[(current + offset + tabs.length) % tabs.length]
    next?.focus()
    next?.click()
  }
  return (
    <>
      <div className={styles.tabs} role="tablist" aria-label={t.imageDrawer.tabs} onKeyDown={moveBetweenTabs}>
        <button
          type="button"
          id="image-tab-uploads"
          role="tab"
          className={styles.tab}
          aria-controls="image-panel-uploads"
          aria-selected={tab === 'uploads'}
          tabIndex={tab === 'uploads' ? 0 : -1}
          data-testid="image-tab-uploads"
          onClick={() => setTab('uploads')}
        >
          {t.imageDrawer.uploads}
        </button>
        {hasStock ? (
          <button
            type="button"
            id="image-tab-stock"
            role="tab"
            className={styles.tab}
            aria-controls="image-panel-stock"
            aria-selected={tab === 'stock'}
            tabIndex={tab === 'stock' ? 0 : -1}
            data-testid="image-tab-stock"
            onClick={() => setTab('stock')}
          >
            {t.imageDrawer.stock}
          </button>
        ) : null}
        <button
          type="button"
          id="image-tab-grids"
          role="tab"
          className={styles.tab}
          aria-controls="image-panel-grids"
          aria-selected={tab === 'grids'}
          tabIndex={tab === 'grids' ? 0 : -1}
          data-testid="image-tab-grids"
          onClick={() => setTab('grids')}
        >
          {t.imageDrawer.grids}
        </button>
      </div>
      {tab === 'uploads' ? (
        <div id="image-panel-uploads" role="tabpanel" aria-labelledby="image-tab-uploads">
          <UploadsTab {...props} />
        </div>
      ) : null}
      {tab === 'stock' && hasStock ? (
        <div id="image-panel-stock" role="tabpanel" aria-labelledby="image-tab-stock">
          <StockTab {...props} />
        </div>
      ) : null}
      {tab === 'grids' ? (
        <div id="image-panel-grids" role="tabpanel" aria-labelledby="image-tab-grids">
          <GridTab {...props} />
        </div>
      ) : null}
    </>
  )
}
