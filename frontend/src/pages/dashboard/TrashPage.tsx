
import { RotateCcw, Trash2 } from 'lucide-react'
import { useState } from 'react'
import { daysUntilPurge, TRASH_RETENTION_DAYS } from '@/features/dashboard/trash'
import { useDesignActions } from '@/features/dashboard/useDesignActions'
import { errorMessage } from '@/features/dashboard/errorMessage'
import { flattenPages, useDesignsList, useEmptyTrash } from '@/lib/api/hooks'
import { formatRelative } from '@/lib/time'
import { usePageTitle } from '@/lib/usePageTitle'
import type { DesignSummary } from '@/types/api'
import { Button, ConfirmDialog, EmptyState, IconButton, Skeleton, Thumbnail, Tooltip, useToast } from '@/ui'
import styles from './pageStyles.module.css'
import trashStyles from './TrashPage.module.css'

export default function TrashPage() {
  usePageTitle("Lixeira")
  const { toast } = useToast()
  const list = useDesignsList({ trashed: true, ordering: '-updated_at' })
  const designs = flattenPages(list.data)
  const actions = useDesignActions()
  const emptyTrash = useEmptyTrash()
  const [confirmEmpty, setConfirmEmpty] = useState(false)
  const [toDelete, setToDelete] = useState<DesignSummary | null>(null)

  return (
    <div className={styles.page}>
      <header className={styles.header}>
        <div className={styles.heading}>
          <h1 className={styles.title}>{"Lixeira"}</h1>
          <p className={styles.lead}>{"Os designs na lixeira são excluídos automaticamente após "}{TRASH_RETENTION_DAYS} {"dias."}</p>
        </div>
        <Button variant="secondary" leftIcon={<Trash2 size={16} />} disabled={designs.length === 0} onClick={() => setConfirmEmpty(true)}>
          {"Esvaziar lixeira"}</Button>
      </header>

      <div aria-live="polite" aria-busy={list.isPending}>
        {list.isPending ? (
            <ul className={styles.list} aria-label={"Carregando lixeira"}>
            {Array.from({ length: 4 }, (_, index) => (
              <li key={index}>
                <Skeleton height="4.5rem" radius="var(--radius-lg)" />
              </li>
            ))}
          </ul>
        ) : list.isError ? (
          <EmptyState title={"A lixeira não foi carregada"} description={errorMessage(list.error, 'Verifique sua conexão e tente novamente.')} role="alert" action={<Button onClick={() => void list.refetch()}>{"Tentar novamente"}</Button>} />
        ) : designs.length === 0 ? (
          <EmptyState icon={<Trash2 size={28} />} title={"A lixeira está vazia"} description={"Os designs excluídos ficam aqui por 30 dias, para que nada seja perdido por engano."} />
        ) : (
          <ul className={styles.list}>
            {designs.map((design) => {
              const days = design.trashed_at ? daysUntilPurge(design.trashed_at) : TRASH_RETENTION_DAYS
              const title = design.title || 'Design sem título'
              return (
                <li key={design.id} className={trashStyles.row}>
                  <Thumbnail src={design.thumbnail_url} alt="" aspect={1.4} className={trashStyles.thumb} />
                  <div className={trashStyles.info}>
                    <p className={trashStyles.title}>{title}</p>
                    <p className={trashStyles.meta}>
                      {"Excluído "}{design.trashed_at ? formatRelative(design.trashed_at) : 'recentemente'} · {days === 0 ? 'removido hoje' : `restam ${days} ${days === 1 ? 'dia' : 'dias'}`}
                    </p>
                  </div>
                  <div className={trashStyles.actions}>
                    <Button size="sm" variant="secondary" leftIcon={<RotateCcw size={14} />} onClick={() => actions.restore(design)}>
                      {"Restaurar"}</Button>
                    <Tooltip content="Excluir permanentemente">
                      <IconButton size="sm" variant="danger" label={`Excluir ${title} permanentemente`} icon={<Trash2 size={16} />} onClick={() => setToDelete(design)} />
                    </Tooltip>
                  </div>
                </li>
              )
            })}
          </ul>
        )}
        {list.hasNextPage ? (
          <div className={styles.more}>
            <Button variant="secondary" loading={list.isFetchingNextPage} onClick={() => void list.fetchNextPage()}>
              {"Carregar mais"}</Button>
          </div>
        ) : null}
      </div>

      <ConfirmDialog
        open={confirmEmpty}
        title={"Esvaziar a lixeira?"}
        description={"Todos os designs na lixeira serão excluídos permanentemente. Esta ação não pode ser desfeita."}
        confirmLabel="Esvaziar lixeira"
        tone="danger"
        loading={emptyTrash.isPending}
        onCancel={() => setConfirmEmpty(false)}
        onConfirm={() =>
          emptyTrash.mutate(undefined, {
            onSuccess: () => {
              setConfirmEmpty(false)
              toast({ title: "Lixeira esvaziada", variant: 'success' })
            },
            onError: (error) => toast({ title: "Não foi possível esvaziar a lixeira", description: errorMessage(error), variant: 'error' }),
          })
        }
      />
      <ConfirmDialog
        open={toDelete !== null}
        title={`Excluir “${toDelete?.title || 'Design sem título'}” permanentemente?`}
        description={"Esta ação exclui o design permanentemente e não pode ser desfeita."}
        confirmLabel="Excluir permanentemente"
        tone="danger"
        onCancel={() => setToDelete(null)}
        onConfirm={() => {
          if (toDelete) actions.deleteForever(toDelete, () => setToDelete(null))
        }}
      />
    </div>
  )
}
