/** Local video uploads. The browser verifies playback before the original file is stored. */
import { Trash2 } from 'lucide-react'
import { useRef, useState, useSyncExternalStore } from 'react'
import type { AssetRef, VideoService } from "@/types/adapter"
import { I } from "../chrome/icons"
import { VIDEO_ACCEPT, looksLikeVideo, probeVideo, videoFilesFrom, videoUploads } from "../clips/assets"
import { formatClipTime } from "../clips/strings"
import { useEditor } from "../context"
import { useAsyncList } from "../hooks/useAsyncList"
import { useResolvedSrc } from "../hooks/useResolvedSrc"
import type { PanelProps } from "./registry"
import { t } from "../strings"
import ed from "../chrome/ed.module.css"
import drawer from "../drawers/Drawers.module.css"
import styles from "./Videos.module.css"

const copy = t.clips.uploads

export function ClipTile({ clip, onPick, onRemove, busy }: { clip: AssetRef; onPick: () => void; onRemove?: () => void; busy?: boolean }) {
  const thumb = useResolvedSrc(clip.video?.posterUrl || clip.thumbUrl)
  return (
    <div className={styles.tile}>
      <button type="button" className={styles.clip} data-testid="video-upload" aria-label={copy.add(clip.name)} title={clip.name} disabled={busy} onClick={onPick}>
        {thumb ? <img src={thumb} alt="" loading="lazy" draggable={false} /> : null}
        {clip.video ? <span className={styles.length}>{formatClipTime(clip.video.durationMs)}</span> : null}
      </button>
      <span className={styles.name}>{clip.name}</span>
      {onRemove ? (
        <button type="button" className={styles.remove} aria-label={copy.remove(clip.name)} title={copy.remove(clip.name)} onClick={onRemove}>
          <Trash2 size={14} aria-hidden="true" />
        </button>
      ) : null}
    </div>
  )
}

export function VideoUploadsTab({ close, service }: PanelProps & { service: VideoService }) {
  const editor = useEditor()
  const library = useAsyncList<AssetRef>((page) => service.list(page), 'local-videos')
  const [added, setAdded] = useState<AssetRef[]>([])
  const [removed, setRemoved] = useState<ReadonlySet<string>>(new Set())
  const uploads = videoUploads(service)
  const sending = useSyncExternalStore(uploads.subscribe, uploads.getSnapshot)
  const [over, setOver] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const input = useRef<HTMLInputElement>(null)

  const ids = new Set(added.map((item) => item.id))
  const clips = [...added, ...library.items.filter((item) => !ids.has(item.id))].filter((item) => !removed.has(item.id))

  const place = (clip: AssetRef): void => {
    void editor.videos.use(clip)
    close()
  }

  const upload = async (files: readonly File[]): Promise<void> => {
    setError(null)
    for (const file of files) {
      if (!looksLikeVideo(file)) {
        setError(copy.notVideo(file.name))
        continue
      }
      try {
        const metadata = await probeVideo(file)
        const asset = await uploads.send(file, metadata)
        setAdded((current) => [asset, ...current.filter((item) => item.id !== asset.id)])
        await editor.videos.use(asset)
      } catch (reason) {
        setError(reason instanceof Error ? reason.message : copy.uploadFailed(file.name))
      }
    }
  }

  const remove = async (clip: AssetRef): Promise<void> => {
    setError(null)
    try {
      await editor.adapter.services.assets.remove(clip.id)
      setRemoved((current) => new Set(current).add(clip.id))
    } catch {
      setError(copy.removeFailed)
    }
  }

  return (
    <>
      <input
        ref={input}
        type="file"
        accept={VIDEO_ACCEPT}
        multiple
        hidden
        data-testid="video-file-input"
        onChange={(event) => {
          const files = [...(event.target.files ?? [])]
          event.target.value = ''
          void upload(files)
        }}
      />
      <button
        type="button"
        className={ed.uploadZone}
        data-testid="video-upload-zone"
        data-over={over || undefined}
        onClick={() => input.current?.click()}
        onDragOver={(event) => {
          if (!event.dataTransfer.types.includes('Files')) return
          event.preventDefault()
          setOver(true)
        }}
        onDragLeave={() => setOver(false)}
        onDrop={(event) => {
          setOver(false)
          const files = videoFilesFrom(event.dataTransfer)
          if (files.length === 0) return
          event.preventDefault()
          void upload(files)
        }}
      >
        {I.upload}
        <div>{copy.zone}</div>
        <small>{copy.browserOnly}</small>
      </button>
      {sending.map((item) => (
        <div key={item.key} className={styles.progress} role="status">
          <span>{copy.uploading(item.name, Math.round(item.fraction * 100))}</span>
          <span className={styles.bar} aria-hidden="true"><span style={{ width: `${Math.round(item.fraction * 100)}%` }} /></span>
        </div>
      ))}
      {error ? <p className={drawer.error} role="alert">{error}</p> : null}
      {clips.length > 0 ? (
        <>
          <p className={ed.sectionTitle} style={{ marginTop: 16 }}>{copy.yours}</p>
          <div className={styles.grid}>
            {clips.map((clip) => <ClipTile key={clip.id} clip={clip} onPick={() => place(clip)} onRemove={() => void remove(clip)} />)}
          </div>
        </>
      ) : library.loading ? (
        <p className={drawer.note} role="status">{copy.loading}</p>
      ) : library.error ? (
        <p className={drawer.error} role="alert">{copy.listFailed}</p>
      ) : (
        <p className={drawer.note} data-testid="videos-empty">{copy.none}</p>
      )}
      {library.hasMore ? <button type="button" className={ed.btn} disabled={library.loading} onClick={library.loadMore}>{copy.loadMore}</button> : null}
    </>
  )
}
