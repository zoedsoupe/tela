
import { useState, type KeyboardEvent } from 'react'
import { useNavigate } from 'react-router-dom'
import { createUrl } from "@/features/presets"
import { type SizePreset } from "@/lib/sizePresets"
import { noteUsedSize } from "@/lib/sizePresets/choices"
import { presetSizeText } from "@/lib/sizePresets/picker"
import { PresetShape } from "@/lib/sizePresets/PresetShape"
import { SizePicker } from "@/lib/sizePresets/SizePicker"
import { Button, Dialog } from "@/ui"
import { CustomSizeForm } from "./CustomSizeForm"
import styles from "./CreateDesignDialog.module.css"

export interface CreateDesignDialogProps {
  open: boolean
  onClose(): void
  /** Open on the custom size instead of the popular sizes. */
  initialTab?: 'sizes' | 'custom'
}

/** Pick a size from the catalogue (by format or platform, filtered or searched) or enter a custom size. */
export function CreateDesignDialog({ open, onClose, initialTab = 'sizes' }: CreateDesignDialogProps) {
  const navigate = useNavigate()
  const [chosen, setChosen] = useState<SizePreset | null>(null)
  // The custom size form has its own Create button.
  const [custom, setCustom] = useState(initialTab === 'custom')

  // The pages keep the dialog mounted while it is closed: it opens again with nothing chosen.
  function close() {
    setChosen(null)
    onClose()
  }
  function go(url: string) {
    close()
    navigate(url)
  }
  const create = (preset: SizePreset): void => {
    noteUsedSize(preset.id)
    go(createUrl({ presetId: preset.id }))
  }

  const moveBetweenCards = (event: KeyboardEvent<HTMLDivElement>): void => {
    if (event.defaultPrevented || !['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown'].includes(event.key)) return
    const active = (event.target as HTMLElement).closest<HTMLButtonElement>('[data-card]')
    if (!active) return
    const cards = Array.from(event.currentTarget.querySelectorAll<HTMLButtonElement>('[data-card]'))
    const index = cards.indexOf(active)
    if (index < 0) return

    let nextIndex = index + (event.key === 'ArrowRight' ? 1 : event.key === 'ArrowLeft' ? -1 : 0)
    if (event.key === 'ArrowUp' || event.key === 'ArrowDown') {
      const rect = active.getBoundingClientRect()
      const down = event.key === 'ArrowDown'
      const row = cards
        .filter((card) => (down ? card.getBoundingClientRect().top > rect.top + 1 : card.getBoundingClientRect().top < rect.top - 1))
        .sort((a, b) => (down ? a.getBoundingClientRect().top - b.getBoundingClientRect().top : b.getBoundingClientRect().top - a.getBoundingClientRect().top))
      const rowTop = row[0]?.getBoundingClientRect().top
      const target = row
        .filter((card) => card.getBoundingClientRect().top === rowTop)
        .sort((a, b) => Math.abs(a.getBoundingClientRect().left - rect.left) - Math.abs(b.getBoundingClientRect().left - rect.left))[0]
      nextIndex = target ? cards.indexOf(target) : index
    }

    const next = cards[nextIndex]
    if (!next || next === active) return
    event.preventDefault()
    next.focus()
  }

  return (
    <Dialog
      open={open}
      onClose={close}
      title={"Crie um projeto"}
      description={"Escolha um tamanho para começar. Você pode alterá-lo a qualquer momento."}
      size="xl"
      footer={
        <>
          <div className={styles.chosen} aria-live="polite">
            {chosen ? (
              <>
                <PresetShape preset={chosen} size={28} />
                <span>
                  <strong>{chosen.label}</strong>
                  <small>
                    {chosen.path.at(-1)?.label} · {presetSizeText(chosen)}
                  </small>
                </span>
              </>
            ) : custom ? null : (
              <small>{"Escolha um tamanho e crie. Um clique duplo cria-o de uma só vez."}</small>
            )}
          </div>
          <Button variant="ghost" onClick={close}>
            {"Cancelar"}</Button>
          {custom ? null : (
            <Button disabled={!chosen} onClick={() => chosen && create(chosen)}>
              {"Criar projeto"}</Button>
          )}
        </>
      }
    >
      <div onKeyDown={moveBetweenCards}>
        <SizePicker selectedId={chosen?.id} onSelect={setChosen} onConfirm={create} startWithCustom={initialTab === 'custom'} onCustomChange={setCustom} custom={<CustomSizeForm onSubmit={(size) => go(createUrl(size))} />} />
      </div>
    </Dialog>
  )
}
