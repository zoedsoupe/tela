/**
 * The Videos tool (a drawer like Images): the person's local clips and the upload zone.
 */
import { useSyncExternalStore } from 'react'
import { useEditor } from "../context"
import type { PanelProps } from "./registry"
import { t } from "../strings"
import ed from "../chrome/ed.module.css"
import { VideoUploadsTab } from "./VideoUploadsTab"
import styles from "./Videos.module.css"

/** While "Replace video" waits for a pick: what the next pick does, and the way out. */
function ReplacingNote() {
  const editor = useEditor()
  const replacing = useSyncExternalStore(editor.videos.subscribeReplacing, () => editor.videos.replacing)
  if (!replacing) return null
  return (
    <p className={styles.replacing} role="status" data-testid="videos-replacing">
      <span>{t.clips.replacing.title}</span>
      <button type="button" className={`${ed.btn} ${ed.ghost}`} onClick={() => editor.videos.cancelReplace()}>
        {t.clips.replacing.cancel}
      </button>
    </p>
  )
}

export function VideosPanel(props: PanelProps) {
  const editor = useEditor()
  const service = editor.adapter.services.video
  if (!service) return null
  return (
    <div data-testid="videos-panel">
      <ReplacingNote />
      <VideoUploadsTab {...props} service={service} />
    </div>
  )
}
