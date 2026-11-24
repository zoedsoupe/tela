import { t } from "../../strings"
import { Segmented } from "../../ui/Segmented"
import styles from "../dialogs.module.css"

export type PageScope = 'all' | 'current' | 'range'

interface PageScopeProps {
  total: number
  value: PageScope
  range: string
  rangeInvalid: boolean
  zipped: boolean
  onChange: (scope: PageScope) => void
  onRangeChange: (range: string) => void
}

export function PageScope({ total, value, range, rangeInvalid, zipped, onChange, onRangeChange }: PageScopeProps) {
  return (
    <div className={styles.field}>
      <span>{t.dialog.downloadPages}</span>
      <Segmented label={t.dialog.downloadPages} value={value} onChange={onChange} options={[{ value: 'all', label: `${t.dialog.downloadAllPages} (${total})` }, { value: 'current', label: t.dialog.downloadCurrentPage }, { value: 'range', label: t.dialog.downloadRange }]} />
      {value === 'range' ? <input className={styles.input} value={range} placeholder={t.dialog.downloadRangeHint} aria-label={t.dialog.downloadRange} aria-invalid={rangeInvalid} onChange={(event) => onRangeChange(event.target.value)} /> : null}
      {rangeInvalid && range ? <small className={styles.error} role="alert">{t.dialog.downloadRangeInvalid}</small> : null}
      {zipped ? <small className={styles.muted}>{t.dialog.downloadZip}</small> : null}
    </div>
  )
}
