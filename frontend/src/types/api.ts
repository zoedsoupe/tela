/** Shared shapes used by the editor adapters. These are not tied to a transport. */
import type { DoryDocument } from "./document"

export interface Page<T> {
  count: number
  next: string | null
  previous: string | null
  results: T[]
}

export interface DesignSummary {
  id: string
  title: string
  width: number
  height: number
  preset: string
  category?: string
  /** Phoenix field names retained at the transport boundary. */
  preset_id?: string | null
  page_count: number
  thumbnail_url: string | null
  folder: string | null
  folder_id?: string | null
  starred: boolean
  revision: number
  created_at: string
  updated_at: string
  trashed_at: string | null
}

export interface Design extends DesignSummary {
  document: DoryDocument
}

export interface DesignQuery {
  q?: string
  folder?: string | 'root'
  starred?: boolean
  trashed?: boolean
  ordering?: '-updated_at' | 'updated_at' | 'title' | '-title' | '-created_at'
  page?: number
  page_size?: number
}

export interface DesignCreateInput {
  title?: string
  width?: number
  height?: number
  preset?: string
  preset_id?: string
  document?: DoryDocument
  folder?: string | null
  folder_id?: string | null
  template?: string
}

export interface DesignPatchInput {
  title?: string
  document?: DoryDocument
  base_revision?: number
  expected_revision?: number
  folder?: string | null
  folder_id?: string | null
  starred?: boolean
}

export type BulkAction = 'trash' | 'restore' | 'delete' | 'star' | 'unstar' | 'move'

export interface FolderT {
  id: string
  name: string
  parent: string | null
  parent_id?: string | null
  design_count: number
  created_at: string
}

export interface VersionDetail extends VersionSummary {
  document: DoryDocument
}

export type AssetKind = 'image' | 'svg' | 'audio' | 'video'

export interface Asset {
  id: string
  kind: AssetKind
  name: string
  url: string
  thumb_url: string
  width: number
  height: number
  size: number
  mime: string
  tags: string[]
  attribution: null
  duration_ms?: number | null
  video?: {
    posterUrl?: string
    durationMs?: number
    fps?: number
    hasAudio?: boolean
    width?: number
    height?: number
  } | null
  created_at: string
}

export type AssetQuery = { kind?: AssetKind; q?: string; page?: number; page_size?: number }

export interface BrandColor {
  id: string
  name: string
  hex: string
}

export interface BrandFont {
  role: 'heading' | 'subheading' | 'body'
  family: string
}

export interface BrandKit {
  id: string
  name: string
  is_default: boolean
  colors: BrandColor[]
  fonts: BrandFont[]
  logos: Asset[]
  created_at: string
  updated_at: string
}

export interface BrandKitInput {
  name: string
  is_default?: boolean
  colors: BrandColor[]
  fonts: BrandFont[]
  logo_ids: string[]
}

export type ElementKind = 'shape' | 'line' | 'icon' | 'sticker' | 'illustration' | 'frame' | 'graphic'
export type ElementStyle = '' | 'outline' | 'filled' | 'duotone' | 'colour'

export interface ElementPack {
  id: string
  slug: string
  name: string
  kind: ElementKind
  thumbnail_url: string | null
  element_count: number
  license: string
  license_url: string
  attribution: string
  source_url: string
}

export interface ElementItem {
  id: string
  name: string
  kind: ElementKind
  style: ElementStyle
  pack: { id: string; slug: string; name: string }
  tags: string[]
  svg_url: string
  width: number
  height: number
  colors: string[]
  is_recolorable: boolean
}

export interface ElementQuery {
  pack?: string
  kind?: ElementKind
  style?: Exclude<ElementStyle, ''>
  q?: string
  ordering?: 'relevance' | 'name' | '-name' | 'created_at' | '-created_at' | 'sort_order' | '-sort_order'
  page?: number
  page_size?: number
}

export type FontCategory = 'sans-serif' | 'serif' | 'display' | 'handwriting' | 'monospace'

export interface FontVariant {
  weight: number
  style: 'normal' | 'italic'
  url: string
  subsets?: Array<{ subset: string; url: string }>
}

export interface FontFamily {
  id: string
  family: string
  category: FontCategory
  scripts: string[]
  is_variable: boolean
  is_user_font: boolean
  variants: FontVariant[]
  popularity: number
  unicode_ranges?: Record<string, string>
}

export interface FontQuery {
  q?: string
  category?: FontCategory
  script?: string
  ordering?: 'popularity' | '-popularity' | 'family' | '-family' | 'created_at' | '-created_at'
  page?: number
  page_size?: number
}

export interface UserFontUploadInput {
  files: File[]
  family?: string
  category?: FontCategory
}

export interface UserFontUploadOptions {
  signal?: AbortSignal
  onProgress?: (fraction: number) => void
}

export type UserFontErrorCode = 'variant_exists' | 'font_name_taken' | 'font_limit_reached' | 'font_storage_limit'

export type ShareRole = 'view' | 'comment' | 'edit'

export type ShareExpiry = 'never' | '1d' | '7d' | '30d'

export interface ShareLink {
  id: string
  token: string
  role: ShareRole
  url: string
  is_active: boolean
  expires_at: string | null
  revoked_at: string | null
  created_at: string
}

export interface ShareLinkInput {
  role: ShareRole
  expires_in: ShareExpiry
}

export interface CommentT {
  id: string
  author: { id: string; name: string; avatar_url: string | null }
  body: string
  page_id: string | null
  x: number | null
  y: number | null
  parent: string | null
  resolved: boolean
  created_at: string
}

export interface CommentInput {
  body: string
  page_id?: string | null
  x?: number | null
  y?: number | null
  parent?: string | null
  parent_id?: string | null
  author_name?: string
}

export interface CommentMove {
  page_id: string
  x: number
  y: number
}

export interface VersionSummary {
  id: string
  label: string
  is_auto: boolean
  page_count: number
  thumbnail_url: string | null
  created_at: string
}

export interface TemplateCategory {
  id: string
  slug: string
  name: string
  icon: string
  template_count: number
  sort_order: number
}

export interface TemplateSummary {
  id: string
  slug: string
  title: string
  category: { id: string; slug: string; name: string } | null
  tags: string[]
  width: number
  height: number
  orientation: 'landscape' | 'portrait' | 'square'
  preset: string
  page_count: number
  thumbnail_url: string | null
  is_featured: boolean
  use_count: number
  created_at: string
}

export interface TemplateDetail extends TemplateSummary {
  description: string
  document: DoryDocument
}

export interface TemplateQuery {
  category?: string
  q?: string
  orientation?: 'landscape' | 'portrait' | 'square'
  preset?: string
  featured?: boolean
  ordering?: 'use_count' | '-use_count' | 'created_at' | '-created_at' | 'title' | '-title'
  page?: number
  page_size?: number
}
