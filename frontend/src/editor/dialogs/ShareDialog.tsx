import { Check, Copy, Trash2 } from 'lucide-react'
import { useCallback, useState } from 'react'
import type { ShareLinkPatch } from "@/types/adapter"
import type { ShareExpiry, ShareLink, ShareRole } from "@/types/api"
import { useEditor } from "../context"
import { useResource } from "../hooks/useResource"
import { t } from "../strings"
import { Button, IconButton } from "../ui/Button"
import { Dialog } from "../ui/Dialog"
import { Select } from "../ui/Select"
import { Skeleton } from "../ui/Skeleton"
import { Switch } from "../ui/Switch"
import { copyText } from "./copyText"
import { SHARE_EXPIRIES, SHARE_ROLES, absoluteUrl, shareLinkStatus } from "./shareOps"
import dlg from "./dialogs.module.css"
import styles from "./Share.module.css"

const when = (iso: string): string => new Intl.DateTimeFormat('pt-BR', { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(iso))

function LinkRow({ link, onChange, onRemove, onCopy }: { link: ShareLink; onChange: (patch: ShareLinkPatch) => Promise<void>; onRemove: () => Promise<void>; onCopy: (url: string) => Promise<void> }) {
  const url = absoluteUrl(link.url, window.location.origin)
  const status = shareLinkStatus(link)
  const [confirm, setConfirm] = useState(false)
  return (
    <li className={styles.link} data-status={status} data-testid="share-link">
      <div className={styles.row}>
        <input className={styles.url} readOnly value={url} aria-label={t.share.linkAddress} onFocus={(event) => event.currentTarget.select()} />
        <Button size="sm" icon={<Copy size={14} aria-hidden="true" />} onClick={() => void onCopy(url)} data-testid="share-copy">{t.share.copy}</Button>
      </div>
      <div className={styles.row}>
        <Select value={link.role} aria-label={t.share.roleOf} disabled={!link.is_active} onChange={(event) => void onChange({ role: event.target.value as ShareRole })}>
          {SHARE_ROLES.map((role) => <option key={role} value={role}>{t.share.roles[role]}</option>)}
        </Select>
        <span className={styles.grow} />
        <Switch label={t.share.enabled} checked={link.is_active} disabled={!link.is_active} onChange={(active) => void onChange({ is_active: active })} />
      </div>
      <div className={styles.row}>
        <span className={`${styles.chip} ${status === 'active' ? '' : styles.chipMuted}`}>{t.share.status[status]}</span>
        <span className={styles.meta}>{link.expires_at ? t.share.expires(when(link.expires_at)) : t.share.neverExpires}</span>
        <span className={styles.grow} />
        {confirm ? (
          <>
            <Button size="sm" variant="danger" onClick={() => void onRemove()} data-testid="share-delete-confirm">{t.share.deleteConfirm}</Button>
            <Button size="sm" variant="ghost" onClick={() => setConfirm(false)}>{t.dialog.cancel}</Button>
          </>
        ) : (
          <IconButton label={t.share.delete} size="sm" onClick={() => setConfirm(true)} data-testid="share-delete"><Trash2 size={16} aria-hidden="true" /></IconButton>
        )}
      </div>
    </li>
  )
}

/** Share links grant view, comment or edit access to this design only. */
export function ShareDialog() {
  const editor = useEditor()
  const sharing = editor.adapter.services.sharing ?? null
  const loadLinks = useCallback(() => sharing ? sharing.list() : Promise.resolve<ShareLink[]>([]), [sharing])
  const resource = useResource(sharing ? loadLinks : null)
  const links = resource.data
  const [failure, setFailure] = useState<string | null>(null)
  const error = failure ?? (resource.failed ? t.share.loadFailed : null)
  const [role, setRole] = useState<ShareRole>('view')
  const [expiry, setExpiry] = useState<ShareExpiry>('7d')
  const [busy, setBusy] = useState(false)
  const [copied, setCopied] = useState(false)

  const copy = async (url: string): Promise<void> => {
    const ok = await copyText(url)
    setCopied(ok)
    editor.toast(ok ? t.share.copied : t.share.copyManually, ok ? 'success' : 'info')
  }

  const create = async (): Promise<void> => {
    if (!sharing || busy) return
    setBusy(true)
    setFailure(null)
    try {
      const made = await sharing.create({ role, expires_in: expiry })
      resource.update((current) => [made, ...current])
      await copy(absoluteUrl(made.url, window.location.origin))
    } catch {
      setFailure(t.share.createFailed)
    } finally {
      setBusy(false)
    }
  }

  const update = (id: string) => async (patch: ShareLinkPatch): Promise<void> => {
    if (!sharing) return
    try {
      const next = await sharing.update(id, patch)
      resource.update((current) => current.map((link) => link.id === id ? next : link))
    } catch {
      setFailure(t.share.updateFailed)
    }
  }

  const remove = (id: string) => async (): Promise<void> => {
    if (!sharing) return
    try {
      await sharing.revoke(id)
      resource.update((current) => current.filter((link) => link.id !== id))
    } catch {
      setFailure(t.share.updateFailed)
    }
  }

  return (
    <Dialog title={t.share.title} description={t.share.description} width={560} onClose={() => editor.closeDialog()} footer={<Button onClick={() => editor.closeDialog()}>{t.dialog.close}</Button>}>
      <div className={dlg.stack} data-testid="share-dialog">
        <div className={styles.create}>
          <label className={styles.field}>
            <span className={dlg.muted}>{t.share.access}</span>
            <Select className={styles.full} value={role} aria-label={t.share.access} data-testid="share-role" onChange={(event) => setRole(event.target.value as ShareRole)}>
              {SHARE_ROLES.map((item) => <option key={item} value={item}>{t.share.roles[item]}</option>)}
            </Select>
          </label>
          <label className={styles.field}>
            <span className={dlg.muted}>{t.share.expiry}</span>
            <Select className={styles.full} value={expiry} aria-label={t.share.expiry} data-testid="share-expiry" onChange={(event) => setExpiry(event.target.value as ShareExpiry)}>
              {SHARE_EXPIRIES.map((item) => <option key={item} value={item}>{t.share.expiries[item]}</option>)}
            </Select>
          </label>
          <Button variant="primary" icon={copied ? <Check size={16} aria-hidden="true" /> : undefined} disabled={busy || !sharing} onClick={() => void create()} data-testid="share-create">
            {busy ? t.share.creating : t.share.create}
          </Button>
        </div>
        {error ? <p className={dlg.error} role="alert">{error}</p> : null}
        {!sharing ? <p className={styles.empty}>{t.share.unavailable}</p> : null}
        {sharing && !links && !error ? <Skeleton height={96} radius={12} aria-busy="true" aria-label={t.share.loading} /> : null}
        {links && links.length === 0 ? <p className={styles.empty}>{t.share.empty}</p> : null}
        {links && links.length > 0 ? (
          <ul className={styles.links} aria-label={t.share.links}>
            {links.map((link) => <LinkRow key={link.id} link={link} onChange={update(link.id)} onRemove={remove(link.id)} onCopy={copy} />)}
          </ul>
        ) : null}
      </div>
    </Dialog>
  )
}
