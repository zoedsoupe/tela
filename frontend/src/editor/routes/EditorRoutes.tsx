import { useQuery } from "@tanstack/react-query"
import { ArrowLeft } from "lucide-react"
import { useEffect, useMemo, useRef, useState } from "react"
import { Link, useNavigate, useParams } from "react-router-dom"
import { isApiError, designsApi, sharedApi } from "@/lib/api"
import { localRepository } from "@/lib/local"
import { usePageTitle } from "@/lib/usePageTitle"
import { EmptyState, LinkButton, Logo, Skeleton, useToast } from "@/ui"
import type { EditorHandle, EditorMode } from "@/types/adapter"
import type { DoryDocument } from "@/types/document"
import { EditorApp } from "../EditorApp"
import { migrateDocument } from "../engine/migrations"
import { createLocalAdapter } from "../dev/localAdapter"
import { createSharedAdapter } from "../adapters/sharedAdapter"
import { createWorkspaceAdapter } from "../adapters/workspaceAdapter"
import styles from "./EditorRoutes.module.css"

const DOORY_CREDIT = "Doory by Siam, creator and maintainer of Doory, https://github.com/shaongitbd/doory"

function EditorStart() {
  return (
    <div className={styles.start}>
      <Link to="/" className={styles.back} aria-label="Voltar à biblioteca"><ArrowLeft size={16} aria-hidden="true" /></Link>
      <Link to="/" className={styles.wordmark} aria-label="Biblioteca Tela"><Logo height={22} /></Link>
      <a className={styles.credit} href="https://github.com/shaongitbd/doory" target="_blank" rel="noreferrer">{DOORY_CREDIT}</a>
      <Link to="/configuracoes" className={styles.profile}>Perfil</Link>
    </div>
  )
}

function LoadState({ title, error, retry }: { title: string; error?: string; retry?: () => void }) {
  return (
    <div className={styles.state}>
      {error ? (
        <EmptyState title={title} description={error} role="alert" action={<><LinkButton to="/">Voltar à biblioteca</LinkButton>{retry ? <button className={styles.retry} type="button" onClick={retry}>Tentar novamente</button> : null}</>} />
      ) : <Skeleton height="70vh" radius="var(--raio-lg)" aria-busy="true" aria-label="Carregando design" />}
    </div>
  )
}

function WorkspaceEditorRoute() {
  const { id = '' } = useParams()
  const navigate = useNavigate()
  const { toast } = useToast()
  const ref = useRef<EditorHandle>(null)
  const [mount, setMount] = useState(0)
  const [title, setTitle] = useState('')
  const query = useQuery({ queryKey: ['design', id], queryFn: ({ signal }) => designsApi.get(id, signal), enabled: Boolean(id) })
  usePageTitle(query.data?.title ?? "Design")
  const revision = query.data?.revision
  const adapter = useMemo(() => revision !== undefined ? createWorkspaceAdapter(id, revision) : null, [id, revision])

  if (query.isPending || !query.data || !adapter) return <LoadState title="O design não foi carregado" error={query.isError ? (isApiError(query.error) && query.error.status === 404 ? "Este design não existe ou foi excluído." : "Não foi possível carregar o design. Verifique a conexão e tente novamente.") : undefined} retry={query.isError ? () => void query.refetch() : undefined} />

  const resolveConflict = async (choice: 'reload' | 'save-as-copy'): Promise<void> => {
    if (choice === 'reload') {
      const latest = await query.refetch()
      if (latest.data) {
        setTitle(latest.data.title)
        setMount((value) => value + 1)
      }
      return
    }
    try {
      const copy = await designsApi.create({ title: `${title || query.data.title} — cópia`, document: ref.current?.getDocument() ?? query.data.document })
      navigate(`/design/${copy.id}`)
    } catch {
      toast({ title: "Não foi possível salvar uma cópia", variant: 'error' })
    }
  }

  return (
    <EditorApp
      key={`${id}:${mount}`}
      ref={ref}
      document={migrateDocument(query.data.document)}
      meta={{ id, title: query.data.title, mode: 'workspace' as EditorMode, revision: query.data.revision }}
      adapter={adapter}
      onTitleChange={setTitle}
      onConflictResolve={(choice) => void resolveConflict(choice)}
      topBarStart={<EditorStart />}
    />
  )
}

function LocalEditorRoute() {
  const { id = '' } = useParams()
  const handle = useMemo(() => createLocalAdapter(id), [id])
  const ref = useRef<EditorHandle>(null)
  const [, setTitle] = useState('')
  const query = useQuery({ queryKey: ['local-design', id], queryFn: () => localRepository.getDesign(id), enabled: Boolean(id) })
  usePageTitle(query.data?.title ?? "Design local")
  useEffect(() => {
    handle.bindDocument(() => ref.current?.getDocument() ?? query.data?.document as DoryDocument)
  }, [handle, query.data?.document])
  if (query.isPending || !query.data) return <LoadState title="Design local não encontrado" error={query.isError || query.data === null ? "Este design não está salvo neste navegador." : undefined} />
  return (
    <EditorApp
      ref={ref}
      document={migrateDocument(query.data.document)}
      meta={{ id, title: query.data.title, mode: 'local' }}
      adapter={handle.adapter}
      onTitleChange={setTitle}
      topBarStart={<EditorStart />}
    />
  )
}

function SharedEditorRoute() {
  const { token = '' } = useParams()
  const navigate = useNavigate()
  const { toast } = useToast()
  const ref = useRef<EditorHandle>(null)
  const [mount, setMount] = useState(0)
  const [title, setTitle] = useState('')
  const query = useQuery({ queryKey: ['shared-design', token], queryFn: ({ signal }) => sharedApi.get(token, signal), enabled: Boolean(token), retry: false })
  usePageTitle(query.data?.title ?? "Design compartilhado")
  const shared = query.data
  const adapter = useMemo(() => shared ? createSharedAdapter({ token, designId: shared.design_id, role: shared.role, revision: shared.revision, title: shared.title }) : null, [token, shared])

  if (query.isPending || !query.data || !adapter) return <LoadState title="Este link não está disponível" error={query.isError ? "O link pode ter sido revogado ou não é válido." : undefined} retry={query.isError ? () => void query.refetch() : undefined} />

  const resolveConflict = async (choice: 'reload' | 'save-as-copy'): Promise<void> => {
    if (choice === 'reload') {
      const latest = await query.refetch()
      if (latest.data) {
        setTitle(latest.data.title)
        setMount((value) => value + 1)
      }
      return
    }
    try {
      const copy = await localRepository.createDesign({ title: `${title || query.data.title} — cópia`, document: ref.current?.getDocument() ?? query.data.document })
      navigate(`/local/${copy.id}`)
    } catch {
      toast({ title: "Não foi possível salvar uma cópia local", variant: 'error' })
    }
  }

  const mode: EditorMode = query.data.role === 'edit' ? 'shared-edit' : query.data.role === 'comment' ? 'shared-comment' : 'shared-view'
  return (
    <EditorApp
      key={`${token}:${mount}`}
      ref={ref}
      document={migrateDocument(query.data.document)}
      meta={{ id: query.data.design_id, title: query.data.title, mode, revision: query.data.revision }}
      adapter={adapter}
      onTitleChange={setTitle}
      onConflictResolve={(choice) => void resolveConflict(choice)}
      topBarStart={<EditorStart />}
    />
  )
}

export function WorkspaceEditor() { return <WorkspaceEditorRoute /> }
export function LocalEditor() { return <LocalEditorRoute /> }
export function SharedEditor() { return <SharedEditorRoute /> }
