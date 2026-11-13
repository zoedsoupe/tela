
import { CircleAlert, CircleCheck, ImagePlus, RotateCw, X } from 'lucide-react'
import { useRef, useState, type ChangeEvent, type DragEvent } from 'react'
import { formatBytes } from "@/lib/time"
import { Button, IconButton, Spinner } from "@/ui"
import { ACCEPT_ATTRIBUTE, type UploadItem, type UploadQueue } from "./uploadQueue"
import styles from "./UploadDropzone.module.css"

export interface UploadDropzoneProps {
  queue: UploadQueue
  items: UploadItem[]
  maxBytes: number
}

export function UploadDropzone({ queue, items, maxBytes }: UploadDropzoneProps) {
  const input = useRef<HTMLInputElement>(null)
  const [over, setOver] = useState(false)

  function onDrop(event: DragEvent<HTMLDivElement>) {
    event.preventDefault()
    setOver(false)
    queue.add(Array.from(event.dataTransfer.files))
  }

  function onChange(event: ChangeEvent<HTMLInputElement>) {
    queue.add(Array.from(event.target.files ?? []))
    event.target.value = ''
  }

  const finished = items.filter((item) => item.status === 'done' || item.status === 'error')

  return (
    <div className={styles.root}>
      <div
        className={styles.zone}
        data-over={over || undefined}
        onDragOver={(event) => {
          event.preventDefault()
          setOver(true)
        }}
        onDragLeave={() => setOver(false)}
        onDrop={onDrop}
      >
        <span className={styles.icon} aria-hidden="true">
          <ImagePlus size={26} />
        </span>
        <p className={styles.title}>{"Arraste e solte imagens aqui"}</p>
        <p className={styles.hint}>{"PNG, JPG, WebP, GIF, AVIF ou SVG · até "}{formatBytes(maxBytes)} {"each"}</p>
        <Button variant="secondary" onClick={() => input.current?.click()}>
          {"Escolha os arquivos"}</Button>
        <input ref={input} type="file" multiple accept={ACCEPT_ATTRIBUTE} className={styles.input} onChange={onChange} aria-label={"Escolha imagens para enviar"} tabIndex={-1} />
      </div>

      {items.length > 0 ? (
        <div className={styles.queue}>
          <ul aria-label={"Envios"} className={styles.list}>
            {items.map((item) => (
              <li key={item.id} className={styles.item} data-status={item.status}>
                <span className={styles.status} aria-hidden="true">
                  {item.status === 'done' ? <CircleCheck size={18} /> : item.status === 'error' ? <CircleAlert size={18} /> : <Spinner size={16} />}
                </span>
                <div className={styles.details}>
                  <p className={styles.name}>{item.name}</p>
                  {item.status === 'error' ? (
                    <p className={styles.error} role="alert">
                      {item.error}
                    </p>
                  ) : item.status === 'done' ? (
                    <p className={styles.meta}>{"Carregado · "}{formatBytes(item.size)}</p>
                  ) : (
                    <progress className={styles.progress} max={100} value={Math.round(item.progress * 100)} aria-label={`Enviando ${item.name}`} />
                  )}
                </div>
                {item.status === 'error' ? <IconButton size="sm" label={`Tente novamente ${item.name}`} icon={<RotateCw size={16} />} onClick={() => queue.retry(item.id)} /> : null}
                <IconButton size="sm" label={item.status === 'uploading' || item.status === 'queued' ? `Cancelar ${item.name}` : `Dispensar ${item.name}`} icon={<X size={16} />} onClick={() => queue.remove(item.id)} />
              </li>
            ))}
          </ul>
          {finished.length > 1 ? (
            <Button variant="ghost" size="sm" onClick={() => queue.clearFinished()}>
              {"Limpar concluído"}</Button>
          ) : null}
        </div>
      ) : null}
    </div>
  )
}
