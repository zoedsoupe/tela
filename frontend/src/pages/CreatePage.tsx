import { useEffect, useRef } from "react"
import { useLocation, useNavigate } from "react-router-dom"
import { templatesApi, designsApi } from "@/lib/api"
import { LazyCreateDesignDialog } from "@/features/create/LazyCreateDesignDialog"
import { resolveCreateSpec } from "@/features/presets"
import { createBlankDocument } from "@/lib/document"
import { usePageTitle } from "@/lib/usePageTitle"
import { EmptyState, LinkButton, Skeleton, useToast } from "@/ui"
import styles from "./CreatePage.module.css"

export default function CreatePage() {
  const location = useLocation()
  const navigate = useNavigate()
  const { toast } = useToast()
  const started = useRef(false)
  const hasTarget = Boolean(location.search)
  usePageTitle("Criar design")

  useEffect(() => {
    if (!hasTarget || started.current) return
    started.current = true
    const spec = resolveCreateSpec(new URLSearchParams(location.search))
    const create = spec.kind === 'template'
      ? templatesApi.use(spec.slug)
      : designsApi.create({
          title: spec.title,
          document: createBlankDocument(spec.width, spec.height, { unit: spec.unit, presetId: spec.presetId }),
        })
    void create.then(
      (design) => navigate(`/design/${design.id}`, { replace: true }),
      () => {
        toast({ title: "Não foi possível criar o design", description: "Confira o tamanho e tente novamente.", variant: 'error' })
        started.current = false
      },
    )
  }, [hasTarget, location.search, navigate, toast])

  if (hasTarget) {
    return (
      <div className={styles.loading}>
        <Skeleton height="70vh" radius="var(--raio-lg)" aria-busy="true" aria-label="Criando design" />
      </div>
    )
  }

  return (
    <div className={styles.create}>
      <EmptyState title="Escolha o tamanho do design" description="O novo design será salvo na biblioteca compartilhada desta instância." action={<LinkButton to="/">Voltar à biblioteca</LinkButton>} />
      <LazyCreateDesignDialog open onClose={() => navigate("/")} />
    </div>
  )
}
