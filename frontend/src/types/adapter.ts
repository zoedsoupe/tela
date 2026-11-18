/** The only boundary between the editor and an application shell. */
import type { ReactNode } from 'react'
import type {
  Asset,
  AssetQuery,
  BrandKit,
  CommentInput,
  CommentMove,
  CommentT,
  ElementItem,
  ElementPack,
  ElementQuery,
  FontFamily,
  FontQuery,
  Page,
  ShareLink,
  ShareLinkInput,
  ShareRole,
  StockPage,
  StockProvider,
  StockProviderFilter,
  TemplateCategory,
  TemplateDetail,
  TemplateQuery,
  TemplateSummary,
  UserFontUploadInput,
  UserFontUploadOptions,
  VersionSummary,
} from "./api"
import type { DoryDocument } from "./document"

export type EditorMode = 'local' | 'workspace' | 'shared-view' | 'shared-comment' | 'shared-edit'

export interface EditorMeta {
  id: string
  title: string
  mode: EditorMode
  revision?: number
}

export interface AssetRef {
  id: string
  url: string
  thumbUrl: string
  width: number
  height: number
  name: string
  kind: 'image' | 'svg' | 'audio' | 'video'
  video?: VideoAssetInfo
}

/** Browser-probed metadata for an original video file. */
export interface VideoAssetInfo {
  posterUrl: string
  durationMs: number
  fps: number
  hasAudio: boolean
  width: number
  height: number
}

export interface SaveInput {
  document: DoryDocument
  title: string
  thumbnail?: Blob
}

export interface SaveResult {
  savedAt: number
  revision?: number
}

export type SaveState =
  | { status: 'idle' }
  | { status: 'dirty' }
  | { status: 'saving' }
  | { status: 'saved'; savedAt: number }
  | { status: 'local'; savedAt: number }
  | { status: 'conflict' }
  | { status: 'error'; message: string }

export interface UserFontsService {
  list(): Promise<FontFamily[]>
  upload(input: UserFontUploadInput, options?: UserFontUploadOptions): Promise<FontFamily>
  remove(id: string): Promise<void>
}

export interface VideoService {
  list(page: number): Promise<Page<AssetRef>>
  upload(file: File, metadata: VideoAssetInfo, options?: VideoUploadOptions): Promise<AssetRef>
}

export interface StockAssetsService {
  search(query: { q: string; provider: StockProviderFilter; page: number }): Promise<StockPage>
  import(provider: StockProvider, externalId: string): Promise<Asset>
}

export interface CommentViewer {
  id: string
  owner: boolean
}

export interface ShareLinkPatch {
  role?: ShareRole
  is_active?: boolean
}

export interface EditorServices {
  fonts: {
    list(q: FontQuery): Promise<Page<FontFamily>>
    mine?: UserFontsService | null
    provided?: readonly FontFamily[]
  }
  elements: {
    packs(): Promise<ElementPack[]>
    list(q: ElementQuery): Promise<Page<ElementItem>>
  }
  templates: {
    categories(): Promise<TemplateCategory[]>
    list(q: TemplateQuery): Promise<Page<TemplateSummary>>
    get(slug: string): Promise<TemplateDetail>
  }
  assets: {
    list(q: AssetQuery): Promise<Page<Asset>>
    remove(id: string): Promise<void>
    stock?: StockAssetsService
  }
  brand: {
    list(): Promise<BrandKit[]>
    save(kit: BrandKit): Promise<BrandKit>
    remove(id: string): Promise<void>
  } | null
  versions: {
    list(): Promise<VersionSummary[]>
    create(label: string): Promise<VersionSummary>
    restore(id: string): Promise<DoryDocument>
  } | null
  sharing: {
    list(): Promise<ShareLink[]>
    create(input: ShareLinkInput): Promise<ShareLink>
    update(id: string, patch: { role?: ShareRole; is_active?: boolean }): Promise<ShareLink>
    revoke(id: string): Promise<void>
  } | null
  comments: {
    list(): Promise<CommentT[]>
    create(input: CommentInput): Promise<CommentT>
    resolve?(id: string, resolved: boolean): Promise<CommentT>
    remove?(id: string): Promise<void>
    move?(id: string, to: CommentMove): Promise<CommentT>
    viewer?(): Promise<CommentViewer | null>
  } | null
  video?: VideoService | null
}

export interface EditorAdapter {
  save(input: SaveInput): Promise<SaveResult>
  uploadAsset(file: File | Blob, opts?: { name?: string }): Promise<AssetRef>
  resolveSrc(src: string): Promise<string>
  services: EditorServices
  exportFilenames?: { style: 'simple' | 'structured'; timestamp: boolean }
}

export interface EditorHandle {
  saveNow(): Promise<void>
  getDocument(): DoryDocument
  isDirty(): boolean
}

export interface EditorAppProps {
  document: DoryDocument
  meta: EditorMeta
  adapter: EditorAdapter
  onTitleChange?: (title: string) => void
  onSaveStateChange?: (state: SaveState) => void
  onConflictResolve?: (choice: 'reload' | 'save-as-copy') => void
  topBarStart?: ReactNode
  topBarEnd?: ReactNode
}

export interface VideoUploadOptions {
  signal?: AbortSignal
  onProgress?: (fraction: number) => void
}
