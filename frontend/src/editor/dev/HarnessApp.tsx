/** Browser-only editor harness with IndexedDB storage and in-memory shared services. */
import { Contrast, Moon, Sun } from 'lucide-react'
import { useEffect, useRef, useState } from 'react'
import type { EditorHandle, EditorMode } from "@/types/adapter"
import type { DoryDocument } from "@/types/document"
import "@/styles/tokens.css"
import { initContrast, setSessionContrast } from "@/lib/contrast"
import { localRepository } from "@/lib/local"
import { EditorApp } from "../EditorApp"
import { createAnimatedDemo, createBlankDemo, createDeckDemo, createDemoDocument, createStressDocument } from "./demoDocument"
import { createLocalAdapter } from "./localAdapter"
import { createMemoryAdapter, type MemoryAdapterOptions } from "./memoryAdapter"
import "./Harness.css"

const params = new URLSearchParams(location.search)
const LOCAL_ID = 'tela-harness-design'
const MODES: readonly EditorMode[] = ['local', 'workspace', 'shared-view', 'shared-comment', 'shared-edit']
const requestedMode = params.get('mode') as EditorMode | null
const mode: EditorMode = requestedMode && MODES.includes(requestedMode) ? requestedMode : 'local'

const theme = params.get('theme')
if (theme === 'dark' || theme === 'light') document.documentElement.dataset.theme = theme
initContrast()
const initialContrast = params.get('contrast')
if (initialContrast === 'more' || initialContrast === 'standard') setSessionContrast(initialContrast)

function initialDocument(): DoryDocument {
  const kind = params.get('doc') ?? 'demo'
  if (kind === 'blank') return createBlankDemo(Number(params.get('w') ?? 1080), Number(params.get('h') ?? 1080))
  if (kind === 'deck') return createDeckDemo()
  if (kind === 'animated') return createAnimatedDemo()
  if (kind === 'stress') return createStressDocument(Number(params.get('pages') ?? 30), Number(params.get('objects') ?? 200))
  return createDemoDocument()
}

export function Harness() {
  const ref = useRef<EditorHandle>(null)
  const handle = useState(() => {
    const viewer = params.get('viewer')
    const options: MemoryAdapterOptions = {
      saveDelayMs: Number(params.get('saveDelay') ?? 0),
      commentRole: viewer === 'owner' || viewer === 'commenter' || viewer === 'anonymous' ? viewer : mode === 'shared-comment' ? 'commenter' as const : 'owner' as const,
      commentSeed: params.get('comments'),
    }
    const created = mode === 'local' ? createLocalAdapter(LOCAL_ID, options) : createMemoryAdapter(options)
    created.comments.setLatency(Number(params.get('commentLatency') ?? 0))
    return created
  })[0]
  const [initial, setInitial] = useState<{ document: DoryDocument; title: string } | null>(() => mode === 'local' ? null : { document: initialDocument(), title: "Meu projeto" })
  const [title, setTitle] = useState("Meu projeto")
  const [dark, setDark] = useState(document.documentElement.dataset.theme === 'dark')
  const [highContrast, setHighContrast] = useState(initialContrast === 'more')

  useEffect(() => {
    let active = true
    handle.bindDocument(() => ref.current?.getDocument() as DoryDocument)
    if (mode !== 'local') {
      return () => { active = false }
    }
    void localRepository.getDesign(LOCAL_ID).then(async (stored) => {
      if (!active) return
      if (stored) {
        setTitle(stored.title)
        setInitial({ document: stored.document, title: stored.title })
        return
      }
      const document = initialDocument()
      const initialTitle = "Meu projeto"
      await localRepository.saveDesign({ id: LOCAL_ID, title: initialTitle, document })
      if (active) setInitial({ document, title: initialTitle })
    }).catch(() => {
      if (active) setInitial({ document: initialDocument(), title: "Meu projeto" })
    })
    return () => { active = false }
  }, [handle])

  if (!initial) return <div className="harness-loading" role="status">Carregando seu design…</div>

  return (
    <EditorApp
      ref={ref}
      document={initial.document}
      meta={{ id: mode === 'local' ? LOCAL_ID : 'harness', title, mode }}
      adapter={handle.adapter}
      onTitleChange={setTitle}
      topBarStart={
        <div className="harness-brand">
          <span className="harness-logo"><i aria-hidden="true" /><b>Tela</b></span>
          <a className="harness-credit" href="https://github.com/shaongitbd/doory" target="_blank" rel="noreferrer">
            Doory by Siam, creator and maintainer of Doory, https://github.com/shaongitbd/doory
          </a>
        </div>
      }
      topBarEnd={
        <div className="harness-actions">
          <button type="button" className="harness-btn" aria-label="Alternar alto contraste" aria-pressed={highContrast} title="Alternar alto contraste" onClick={() => {
            const next = !highContrast
            setHighContrast(next)
            setSessionContrast(next ? 'more' : 'standard')
          }}><Contrast size={17} aria-hidden="true" /></button>
          <button type="button" className="harness-btn" aria-label="Tema alternativo" aria-pressed={dark} title="Tema alternativo" onClick={() => {
            const next = !dark
            document.documentElement.dataset.theme = next ? 'dark' : 'light'
            setDark(next)
          }}>{dark ? <Sun size={18} aria-hidden="true" /> : <Moon size={18} aria-hidden="true" />}</button>
        </div>
      }
    />
  )
}
