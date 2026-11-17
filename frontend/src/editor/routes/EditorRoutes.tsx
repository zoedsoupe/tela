import { useQuery } from "@tanstack/react-query"
import { ArrowLeft } from "lucide-react"
import { useEffect, useMemo, useRef, useState } from "react"
import { Link, useLocation, useNavigate, useParams } from "react-router-dom"
import { isApiError, designsApi, profilesApi, sharedApi } from "@/lib/api"
import { localRepository } from "@/lib/local"
import { usePageTitle } from "@/lib/usePageTitle"
import { EmptyState, LinkButton, Logo, Skeleton, useToast } from "@/ui"
import type { EditorHandle, EditorMode } from "@/types/adapter"
import type { DoryDocument } from "@/types/document"
import { ProfileButton } from "@/features/profiles/ProfileButton"
import { ProfileDialog } from "@/features/profiles/ProfileDialog"
import { EditorApp } from "../EditorApp"
import { migrateDocument } from "../engine/migrations"
import { createLocalAdapter } from "../dev/localAdapter"
import { createSharedAdapter } from "../adapters/sharedAdapter"
import { createWorkspaceAdapter } from "../adapters/workspaceAdapter"
import { GuestNameDialog } from "./GuestNameDialog"
import { readGuestName, saveGuestName } from "./sharedIdentity"
import styles from "./EditorRoutes.module.css"

function EditorStart() {
  return (
    <div className={styles.start}>
      <Link to="/" className={styles.back} aria-label="Voltar à biblioteca"><ArrowLeft size={16} aria-hidden="true" /></Link>
      <Link to="/" className={styles.wordmark} aria-label="Biblioteca Tela">
        <span className={styles.fullLogo} aria-hidden="true"><Logo height={22} /></span>
        <span className={styles.markLogo} aria-hidden="true"><Logo variant="mark" height={22} /></span>
      </Link>
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
  const location = useLocation()
  const navigate = useNavigate()
  const { toast } = useToast()
  const ref = useRef<EditorHandle>(null)
  const [mount, setMount] = useState(0)
  const [title, setTitle] = useState('')
  const [manualProfileDialogOpen, setManualProfileDialogOpen] = useState(false)
  const openedFromCreate = location.state !== null && typeof location.state === 'object' && 'newDesign' in location.state && location.state.newDesign === true
  const initialProfilePrompt = location.state !== null && typeof location.state === 'object' && 'initialProfileDialog' in location.state && location.state.initialProfileDialog === true
  const query = useQuery({ queryKey: ['design', id], queryFn: ({ signal }) => designsApi.get(id, signal), enabled: Boolean(id) })
  const profiles = useQuery({ queryKey: ['profiles'], queryFn: ({ signal }) => profilesApi.list(signal), enabled: Boolean(id) })
  const profileDialogOpen = manualProfileDialogOpen || initialProfilePrompt || (
    openedFromCreate && profiles.isSuccess && profiles.data.current_profile === null
  )
  usePageTitle(query.data?.title ?? "Design")
  const revision = query.data?.revision
  const adapter = useMemo(() => revision !== undefined ? createWorkspaceAdapter(id, revision) : null, [id, revision])

  useEffect(() => {
    if (!openedFromCreate || profiles.isPending) return
    const state = profiles.isSuccess && profiles.data.current_profile === null
      ? { initialProfileDialog: true }
      : null
    navigate(`${location.pathname}${location.search}${location.hash}`, { replace: true, state })
  }, [location.hash, location.pathname, location.search, navigate, openedFromCreate, profiles.data, profiles.isPending, profiles.isSuccess])

  if (query.isPending || !query.data || !adapter) return <LoadState title="O design não foi carregado" error={query.isError ? (isApiError(query.error) && query.error.status === 404 ? "Este design não existe ou foi excluído." : "Não foi possível carregar o design. Verifique a conexão e tente novamente.") : undefined} retry={query.isError ? () => void query.refetch() : undefined} />

  const closeProfileDialog = (): void => {
    setManualProfileDialogOpen(false)
    if (openedFromCreate || initialProfilePrompt) navigate(`${location.pathname}${location.search}${location.hash}`, { replace: true, state: null })
  }

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
      topBarEnd={
        <>
          <ProfileButton profile={profiles.data?.current_profile} onClick={() => setManualProfileDialogOpen(true)} />
          <ProfileDialog open={profileDialogOpen} onClose={closeProfileDialog} />
        </>
      }
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
  const [guestIdentity, setGuestIdentity] = useState<{ token: string; name: string | null }>(() => ({ token, name: readGuestName(token) }))
  const guestName = guestIdentity.token === token ? guestIdentity.name : readGuestName(token)
  const query = useQuery({ queryKey: ['shared-design', token], queryFn: ({ signal }) => sharedApi.get(token, signal), enabled: Boolean(token), retry: false })
  usePageTitle(query.data?.title ?? "Design compartilhado")
  const shared = query.data
  const adapter = useMemo(() => shared && (shared.role === 'view' || guestName) ? createSharedAdapter({ token, designId: shared.design_id, role: shared.role, revision: shared.revision, title: shared.title, authorName: guestName ?? undefined }) : null, [token, shared, guestName])

  if (query.isPending || !query.data) return <LoadState title="Este link não está disponível" error={query.isError ? "O link pode ter sido revogado ou não é válido." : undefined} retry={query.isError ? () => void query.refetch() : undefined} />
  if (query.data.role !== 'view' && !guestName) {
    return <GuestNameDialog onSubmit={(value) => {
      const name = saveGuestName(token, value)
      if (name) setGuestIdentity({ token, name })
    }} />
  }
  if (!adapter) return <LoadState title="Este link não está disponível" />

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
