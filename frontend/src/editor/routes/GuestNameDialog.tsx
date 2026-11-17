import { useState, type FormEvent } from "react"
import { Button, Dialog, Input } from "@/ui"
import { t } from "../strings"
import { normalizeGuestName } from "./sharedIdentity"

interface GuestNameDialogProps {
  onSubmit(name: string): void
}

/** Display-name attribution only: no account, password or workspace profile is involved. */
export function GuestNameDialog({ onSubmit }: GuestNameDialogProps) {
  const [name, setName] = useState('')
  const [error, setError] = useState<string | null>(null)

  const submit = (event: FormEvent<HTMLFormElement>): void => {
    event.preventDefault()
    const normalized = normalizeGuestName(name)
    if (!normalized) {
      setError(t.comments.gateNameRequired)
      return
    }
    onSubmit(normalized)
  }

  return (
    <Dialog
      open
      size="sm"
      dismissible={false}
      onClose={() => undefined}
      title={t.comments.gateTitle}
      description={t.comments.gateBody}
      footer={<Button type="submit" form="shared-guest-name" data-testid="shared-guest-name-submit">{t.comments.gateAction}</Button>}
    >
      <form id="shared-guest-name" onSubmit={submit}>
        <Input
          label={t.comments.gateName}
          placeholder={t.comments.gateNamePlaceholder}
          value={name}
          error={error}
          required
          maxLength={120}
          autoComplete="name"
          data-testid="shared-guest-name"
          onChange={(event) => {
            setName(event.target.value)
            setError(null)
          }}
        />
      </form>
    </Dialog>
  )
}
