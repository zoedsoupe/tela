
import { Copy, ExternalLink, FolderInput, MoreHorizontal, Pencil, Star, Trash2 } from 'lucide-react'
import { useState } from 'react'
import { Link } from 'react-router-dom'
import { designKind, getPreset } from "@/features/presets"
import { useSizePresets } from "@/lib/sizePresets"
import { formatRelative } from "@/lib/time"
import type { DesignSummary } from "@/types/api"
import { Checkbox, IconButton, Menu, MenuItem, MenuSeparator, Thumbnail } from "@/ui"
import type { DesignActions } from "./useDesignActions"
import { setDraggedDesigns } from "./dragDrop"
import { InlineRename } from "./InlineRename"
import styles from "./DesignCard.module.css"

export interface DesignCardProps {
  design: DesignSummary
  layout: 'grid' | 'list'
  selected: boolean
  selectionActive: boolean
  /** Ids that move together when this card is dragged (the selection when it contains this card). */
  dragIds(): string[]
  onSelectChange(selected: boolean): void
  actions: DesignActions
  onMoveRequest(design: DesignSummary): void
}

export function DesignCard({ design, layout, selected, selectionActive, dragIds, onSelectChange, actions, onMoveRequest }: DesignCardProps) {
  const [renaming, setRenaming] = useState(false)
  const catalogue = useSizePresets()
  const title = design.title || "Design sem título"

  return (
    <article className={styles.card} data-layout={layout} data-selected={selected || undefined} data-selecting={selectionActive || undefined} draggable={!renaming} onDragStart={(event) => setDraggedDesigns(event, dragIds())}>
      <div className={styles.thumbWrap}>
        <Link to={`/design/${design.id}`} className={styles.thumbLink} aria-hidden="true" tabIndex={-1}>
          <Thumbnail src={design.thumbnail_url} alt="" aspect={layout === 'list' ? 1.4 : 4 / 3} fit="contain" page={design} className={styles.thumb} />
        </Link>
        <div className={styles.select}>
          <Checkbox aria-label={`Selecione ${title}`} checked={selected} onChange={(event) => onSelectChange(event.target.checked)} />
        </div>
        <div className={styles.quick}>
          <IconButton
            size="sm"
            variant="secondary"
            label={design.starred ? `Remover ${title} dos favoritos` : `Estrela ${title}`}
            pressed={design.starred}
            icon={<Star size={16} fill={design.starred ? 'currentColor' : 'none'} />}
            className={styles.star}
            onClick={() => actions.toggleStar(design)}
          />
        </div>
      </div>
      <div className={styles.info}>
        {renaming ? (
          <InlineRename
            value={design.title}
            label={`Renomear ${title}`}
            onCommit={(next) => {
              setRenaming(false)
              actions.rename(design, next)
            }}
            onCancel={() => setRenaming(false)}
          />
        ) : (
          <Link to={`/design/${design.id}`} className={styles.title} title={title}>
            {title}
          </Link>
        )}
        <p className={styles.meta}>
          {designKind(design, catalogue)} · {formatRelative(design.updated_at)}
          <span className={styles.extra}>
            {getPreset(design.preset, catalogue) ? ` · ${design.width} × ${design.height}` : ''}
            {design.page_count > 1 ? ` · ${design.page_count} páginas` : ''}
          </span>
        </p>
      </div>
      <div className={styles.menu}>
        <Menu label={`Ações para ${title}`} placement="bottom-end" trigger={<IconButton size="sm" label={`Mais ações para ${title}`} icon={<MoreHorizontal size={18} />} />}>
          <MenuItem icon={<ExternalLink size={16} />} onSelect={() => actions.open(design)}>
            {"Abrir"}</MenuItem>
          <MenuItem icon={<Pencil size={16} />} onSelect={() => setRenaming(true)}>
            {"Renomear"}</MenuItem>
          <MenuItem icon={<Copy size={16} />} onSelect={() => actions.duplicate(design)}>
            {"Duplicar"}</MenuItem>
          <MenuItem icon={<Star size={16} />} onSelect={() => actions.toggleStar(design)}>
            {design.starred ? "Remover estrela" : "Estrela"}
          </MenuItem>
          <MenuItem icon={<FolderInput size={16} />} onSelect={() => onMoveRequest(design)}>
            {"Mover para a pasta…"}</MenuItem>
          <MenuSeparator />
          <MenuItem icon={<Trash2 size={16} />} danger onSelect={() => actions.trash(design)}>
            {"Mover para a lixeira"}</MenuItem>
        </Menu>
      </div>
    </article>
  )
}
