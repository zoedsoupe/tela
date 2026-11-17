
import { FolderInput, Star, Trash2, X } from 'lucide-react'
import { Button } from "@/ui"
import styles from "./BulkBar.module.css"

export interface BulkBarProps {
  count: number
  onStar(): void
  onUnstar(): void
  onMove(): void
  onTrash(): void
  onClear(): void
}

/** Floating action bar shown while designs are selected. */
export function BulkBar({ count, onStar, onUnstar, onMove, onTrash, onClear }: BulkBarProps) {
  if (count === 0) return null
  return (
    <div className={styles.bar} role="region" aria-label={"Designs selecionados"}>
      <p className={styles.count} role="status">
        {count} {count === 1 ? "design selecionado" : "designs selecionados"}
      </p>
      <div className={styles.actions}>
        <Button size="sm" variant="ghost" leftIcon={<Star size={16} />} onClick={onStar}>
          {"Marcar com estrela"}</Button>
        <Button size="sm" variant="ghost" onClick={onUnstar}>
          {"Remover estrela"}</Button>
        <Button size="sm" variant="ghost" leftIcon={<FolderInput size={16} />} onClick={onMove}>
          {"Mover"}</Button>
        <Button size="sm" variant="ghost" leftIcon={<Trash2 size={16} />} onClick={onTrash}>
          {"Mover para a lixeira"}</Button>
      </div>
      <Button size="sm" variant="secondary" leftIcon={<X size={16} />} onClick={onClear}>
        {"Limpar"}</Button>
    </div>
  )
}
