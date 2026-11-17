import { AlertTriangle, Check, CloudOff, Eye, Loader2, RotateCcw } from 'lucide-react'
import { useEditor, useEditorState } from "./context"
import { t } from "./strings"
import styles from "./SaveStatus.module.css"

/** The editor's save state, with a read-only indicator for view-only links. */
export function SaveStatus() {
  const editor = useEditor()
  const save = useEditorState((s) => s.save)
  const readOnly = useEditorState((s) => s.readOnly)
  const mode = useEditorState((s) => s.mode)

  if (readOnly) {
    return (
      <span className={`${styles.pill} ${styles.neutral}`} role="status" aria-label={t.save.readOnly}>
        <Eye size={14} aria-hidden="true" />
        <span className={styles.text}>{t.save.readOnly}</span>
      </span>
    )
  }

  switch (save.status) {
    case 'saving':
      return (
        <span className={`${styles.pill} ${styles.neutral}`} role="status" aria-label={t.save.saving}>
          <Loader2 size={14} className={styles.spin} aria-hidden="true" />
          <span className={styles.text}>{t.save.saving}</span>
        </span>
      )
    case 'dirty':
      return (
        <span className={`${styles.pill} ${styles.neutral}`} role="status" aria-label={t.save.unsaved}>
          <span className={styles.dot} aria-hidden="true" />
          <span className={styles.text}>{t.save.unsaved}</span>
        </span>
      )
    case 'conflict':
      return (
        <span className={`${styles.pill} ${styles.warn}`} role="status" aria-label={t.save.conflict}>
          <AlertTriangle size={14} aria-hidden="true" />
          <span className={styles.text}>{t.save.conflict}</span>
        </span>
      )
    case 'error':
      return (
        <span className={`${styles.pill} ${styles.error}`} role="alert" aria-label={t.save.error} title={save.message}>
          <CloudOff size={14} aria-hidden="true" />
          <span className={styles.text}>{t.save.error}</span>
          <button type="button" className={styles.retry} aria-label={t.save.retry} title={t.save.retry} onClick={() => void editor.persistence.saveNow()}>
            <RotateCcw size={13} aria-hidden="true" />
            <span className={styles.retryLabel}>{t.save.retry}</span>
          </button>
        </span>
      )
    case 'local':
      return (
        <span className={`${styles.pill} ${styles.ok}`} role="status" aria-label={t.save.local} title={t.save.localHint}>
          <Check size={14} aria-hidden="true" />
          <span className={styles.text}>{t.save.local}</span>
        </span>
      )
    case 'saved':
      return (
        <span className={`${styles.pill} ${styles.ok}`} role="status" aria-label={t.save.saved}>
          <Check size={14} aria-hidden="true" />
          <span className={styles.text}>{t.save.saved}</span>
        </span>
      )
    default:
      return (
        <span className={`${styles.pill} ${styles.ok}`} role="status" aria-label={mode === 'local' ? t.save.local : t.save.ready} title={mode === 'local' ? t.save.localHint : undefined}>
          <Check size={14} aria-hidden="true" />
          <span className={styles.text}>{mode === 'local' ? t.save.local : t.save.ready}</span>
        </span>
      )
  }
}
