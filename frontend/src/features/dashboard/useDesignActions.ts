import { useNavigate } from 'react-router-dom'
import { useBulkDesigns, useDeleteDesignForever, useDuplicateDesign, useRestoreDesign, useTrashDesign, useUpdateDesign } from "@/lib/api/hooks"
import type { DesignSummary } from "@/types/api"
import { useToast } from "@/ui"
import { errorMessage } from "./errorMessage"

type Movable = Pick<DesignSummary, 'id' | 'folder'>

/** Every design mutation the dashboard offers, with consistent toasts and undo. */
export function useDesignActions() {
  const { toast } = useToast()
  const navigate = useNavigate()
  const update = useUpdateDesign()
  const trash = useTrashDesign()
  const restore = useRestoreDesign()
  const duplicate = useDuplicateDesign()
  const forever = useDeleteDesignForever()
  const bulk = useBulkDesigns()

  const fail = (title: string) => (error: unknown) => toast({ title, description: errorMessage(error), variant: 'error' })

  return {
    open: (design: Pick<DesignSummary, 'id'>) => navigate(`/design/${design.id}`),

    rename(design: Pick<DesignSummary, 'id' | 'title'>, title: string) {
      const next = title.trim()
      if (!next || next === design.title) return
      update.mutate({ id: design.id, patch: { title: next } }, { onError: fail("Não foi possível renomear o design") })
    },

    toggleStar(design: Pick<DesignSummary, 'id' | 'starred'>) {
      update.mutate({ id: design.id, patch: { starred: !design.starred } }, { onError: fail("Não foi possível atualizar a estrela") })
    },

    duplicate(design: Pick<DesignSummary, 'id' | 'title'>) {
      duplicate.mutate(design.id, {
        onSuccess: (copy) => toast({ title: "Projeto duplicado", description: copy.title, variant: 'success', action: { label: "Cópia aberta", onClick: () => navigate(`/design/${copy.id}`) } }),
        onError: fail("Não foi possível duplicar o design"),
      })
    },

    trash(design: Pick<DesignSummary, 'id' | 'title'>) {
      trash.mutate(design.id, {
        onSuccess: () => toast({ title: "Movido para a lixeira", description: design.title, action: { label: "Desfazer", onClick: () => restore.mutate(design.id, { onError: fail("Não foi possível restaurar o design") }) } }),
        onError: fail("Não foi possível mover o design para a lixeira"),
      })
    },

    trashMany(designs: Array<Pick<DesignSummary, 'id'>>, done?: () => void) {
      const ids = designs.map((design) => design.id)
      bulk.mutate(
        { ids, action: 'trash' },
        {
          onSuccess: () => {
            done?.()
            toast({ title: ids.length === 1 ? "Movido para a lixeira" : `${ids.length} designs movidos para a lixeira`, action: { label: "Desfazer", onClick: () => bulk.mutate({ ids, action: 'restore' }, { onError: fail("Não foi possível restaurar os designs") }) } })
          },
          onError: fail("Não foi possível mover os designs para a lixeira"),
        },
      )
    },

    starMany(designs: Array<Pick<DesignSummary, 'id'>>, starred: boolean) {
      bulk.mutate({ ids: designs.map((design) => design.id), action: starred ? 'star' : 'unstar' }, { onError: fail("Não foi possível atualizar as estrelas") })
    },

    /** Moves designs into a folder (null = top level) and offers an undo that restores each one's previous folder. */
    moveMany(designs: Movable[], folder: string | null, folderName: string, done?: () => void) {
      const ids = designs.map((design) => design.id)
      const previous = new Map<string | null, string[]>()
      for (const design of designs) previous.set(design.folder, [...(previous.get(design.folder) ?? []), design.id])
      bulk.mutate(
        { ids, action: 'move', folder },
        {
          onSuccess: () => {
            done?.()
            toast({
              title: ids.length === 1 ? `Movido para ${folderName}` : `Projetos ${ids.length} movidos para ${folderName}`,
              variant: 'success',
              action: {
                label: "Desfazer",
                onClick: () => {
                  for (const [from, group] of previous) bulk.mutate({ ids: group, action: 'move', folder: from }, { onError: fail("Não foi possível desfazer a mudança") })
                },
              },
            })
          },
          onError: fail("Não foi possível mover os designs"),
        },
      )
    },

    restore(design: Pick<DesignSummary, 'id' | 'title'>) {
      restore.mutate(design.id, {
        onSuccess: () => toast({ title: "Projeto restaurado", description: design.title, variant: 'success', action: { label: "Abrir", onClick: () => navigate(`/design/${design.id}`) } }),
        onError: fail("Não foi possível restaurar o design"),
      })
    },

    deleteForever(design: Pick<DesignSummary, 'id'>, done?: () => void) {
      forever.mutate(design.id, { onSuccess: () => { done?.(); toast({ title: "Design excluído permanentemente" }) }, onError: fail("Não foi possível excluir o design") })
    },

    busy: update.isPending || trash.isPending || bulk.isPending || duplicate.isPending || restore.isPending || forever.isPending,
  }
}

export type DesignActions = ReturnType<typeof useDesignActions>
