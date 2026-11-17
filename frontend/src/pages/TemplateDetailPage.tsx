
import { ArrowLeft, Sparkles } from 'lucide-react'
import { useNavigate, useParams, Link } from 'react-router-dom'
import { TemplateCard } from "@/features/templates/TemplateCard"
import { isApiError, templatesApi } from "@/lib/api"
import { useTemplate, useTemplatesList } from "@/lib/api/hooks"
import { usePageMeta } from "@/lib/usePageMeta"
import { useState } from 'react'
import { Badge, Button, EmptyState, LinkButton, Skeleton, Thumbnail, useToast } from "@/ui"
import styles from "./TemplateDetailPage.module.css"

export default function TemplateDetailPage() {
  const { slug = '' } = useParams()
  const navigate = useNavigate()
  const { toast } = useToast()
  const [creating, setCreating] = useState(false)
  const query = useTemplate(slug)
  const template = query.data
  usePageMeta({
    title: template?.title ?? "Modelo",
    description: template ? (template.description || `Um modelo ${template.width} × ${template.height} px ${template.title} gratuito e editável. Abra-o no seu navegador e personalize-o.`) : undefined,
    canonical: template ? `/templates/${template.slug}` : undefined,
    image: template?.thumbnail_url || undefined,
  })

  const related = useTemplatesList({ category: template?.category?.slug, page_size: 6, ordering: "-use_count" }, Boolean(template?.category))
  const relatedItems = (related.data?.pages[0]?.results ?? []).filter((item) => item.slug !== slug).slice(0, 4)


  if (query.isPending) {
    return (
      <div className={styles.page} aria-busy="true">
        <div className={styles.layout}>
          <Skeleton height="28rem" radius="var(--raio-xl)" />
          <div className={styles.skeletonSide}>
            <Skeleton width="70%" height={36} />
            <Skeleton width="40%" height={20} />
            <Skeleton height={80} />
          </div>
        </div>
      </div>
    )
  }

  if (query.isError || !template) {
    const notFound = isApiError(query.error) && query.error.status === 404
    return (
      <EmptyState
        title={notFound ? "Não conseguimos encontrar esse modelo" : "Este modelo não foi carregado"}
        description={notFound ? "Pode ter sido não publicado ou o link foi digitado incorretamente." : "Verifique sua conexão e tente novamente."}
        role="alert"
        action={
          <>
            {notFound ? null : <Button onClick={() => void query.refetch()}>{"Tente novamente"}</Button>}
            <LinkButton to="/templates" variant="secondary">
              {"Procure modelos"}</LinkButton>
          </>
        }
      />
    )
  }

  const aspect = template.width > 0 && template.height > 0 ? template.width / template.height : 1

  async function startFromTemplate() {
    if (!template || creating) return
    setCreating(true)
    try {
      const design = await templatesApi.use(template.slug)
      navigate(`/design/${encodeURIComponent(design.id)}`)
    } catch (error) {
      toast({ title: "Não foi possível usar este modelo", description: isApiError(error) ? error.message : "Tente novamente.", variant: 'error' })
    } finally {
      setCreating(false)
    }
  }

  return (
    <div className={styles.page}>
      <Link to="/templates" className={styles.back}>
        <ArrowLeft size={16} aria-hidden="true" /> {"Todos os modelos"}</Link>
      <div className={styles.layout}>
        <div className={styles.preview}>
          <Thumbnail src={template.thumbnail_url} alt={`Visualização do modelo ${template.title}`} aspect={Math.min(Math.max(aspect, 0.45), 2.2)} fit="contain" className={styles.previewImage} />
        </div>
        <div className={styles.side}>
          {template.category ? <Badge tone="brand">{template.category.name}</Badge> : null}
          <h1 className={styles.title}>{template.title}</h1>
          <p className={styles.facts}>
            {template.width} × {template.height} {"px · "}{template.page_count} {template.page_count === 1 ? 'página' : 'páginas'}
          </p>
          {template.description ? <p className={styles.description}>{template.description}</p> : null}
          {template.tags.length > 0 ? (
            <ul className={styles.tags} aria-label={"Etiquetas"}>
              {template.tags.map((tag) => (
                <li key={tag}>
                  <Link to={`/templates?q=${encodeURIComponent(tag)}`} className={styles.tag}>
                    {tag}
                  </Link>
                </li>
              ))}
            </ul>
          ) : null}
          <div className={styles.actions}>
            <Button size="lg" leftIcon={<Sparkles size={18} />} loading={creating} onClick={() => void startFromTemplate()}>
              {"Use este modelo"}</Button>
            <p className={styles.hint}>Uma cópia será salva na biblioteca compartilhada.</p>
          </div>
        </div>
      </div>

      {relatedItems.length > 0 ? (
        <section className={styles.related} aria-labelledby="related-title">
          <h2 id="related-title" className={styles.relatedTitle}>
            {"Mais como este"}</h2>
          <ul className={styles.relatedGrid}>
            {relatedItems.map((item) => (
              <li key={item.id}>
                <TemplateCard template={item} />
              </li>
            ))}
          </ul>
        </section>
      ) : null}
    </div>
  )
}
