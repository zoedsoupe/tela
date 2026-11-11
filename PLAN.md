# Tela implementation plan

## 1. Product and constraints

Tela is a self-hosted graphic editor for social posts, stories, invitations, print pieces, thumbnails, and simple presentations. The UI and user-facing copy are in Brazilian Portuguese. The initial instance serves two private users, but every design, upload, and brand kit belongs to its owner.

The MVP includes:

- Multiple pages per design, all sharing the same dimensions.
- Text, geometric shapes, local images, SVG assets, layers, locking, visibility, zoom, pan, undo, and redo.
- Blank designs and reusable templates.
- Local catalog search in Portuguese with SQLite FTS5.
- User uploads and on-demand stock photos from Pexels, Pixabay, and Wikimedia Commons.
- Brand kits with colors, fonts, and logos.
- Object enter, emphasis, and exit animations, page transitions, preview, and fullscreen presentation.
- Client-side PNG, JPG, SVG, PDF, and animated GIF export.
- A semantic design system with reusable Phoenix components.

The MVP excludes:

- Real-time collaboration, Presence, comments, public sharing, Yjs, and remote cursors.
- Version history.
- Audio, video clips, MP4, WebM, and server-side export.
- Per-line, per-word, and per-letter animation.
- Multi-track timeline editing.
- Presentation notes, a second presenter window, and remote presentation control.
- Background removal, upscaling, MCP, and a public API.
- Vector PDF output and a full mobile editor.

## 2. Stack and boundaries

- Elixir, Phoenix LiveView, Tailwind CSS v4, SQLite, and `ecto_sqlite3`.
- `:httpc` for external HTTP calls, following the repository convention.
- Vanilla TypeScript and Fabric.js 7.2 in a LiveView-owned island.
- `jsPDF` for rasterized multipage PDF export.
- `gifenc` and a Web Worker for animated GIF encoding.
- Vitest for pure TypeScript contracts and ExUnit/LiveViewTest for the Elixir application.

Doory is an architectural reference, not a stack to port wholesale. Selected concepts and modules may be adapted from its document migrations, serialization, persistence, animation model, frame rendering, timeline, and GIF writer. Doory uses the Attribution Assurance License. Any copied code, templates, or assets require its LICENSE, NOTICE, and visible application credit.

## 3. Elixir contexts

Use cases are public functions inside contexts. There is no generic `Tela.UseCase` behaviour and no one-module-per-action structure. LiveViews call contexts, never `Tela.Repo` directly. Every public operation has a `@spec` and returns `{:ok, value}` or `{:error, reason}`.

```text
lib/tela/
  accounts.ex
  accounts/
    user.ex
    user_token.ex
    user_notifier.ex

  designs.ex
  designs/
    design.ex
    document.ex
    preset.ex

  catalog.ex
  catalog/
    asset.ex
    seed.ex

  media.ex
  media/
    media_upload.ex
    external_photo.ex
    storage.ex
    storage/local.ex
    stock_provider.ex
    stock_provider/pexels.ex
    stock_provider/pixabay.ex
    stock_provider/wikimedia.ex

  brands.ex
  brands/
    kit.ex
```

### Tela.Designs

Public operations:

```elixir
create(attrs)
get_for_user(design_id, user_id)
get_template(template_id)
list_for_user(user_id, filters \\ %{})
list_templates(filters \\ %{})
save_document(input)
rename(design_id, user_id, title)
duplicate(design_id, user_id)
delete(design_id, user_id)
```

`create/1` accepts a preset or a public template. A preset creates a blank document. A template copy is independent and starts at revision 1.

`save_document/1` accepts `design_id`, `user_id`, `document`, `expected_revision`, and an optional thumbnail. It checks ownership, validates the document envelope and limits, updates only when the revision matches, increments `revision`, and recalculates `page_count`. A stale save returns `{:error, :revision_conflict}` without overwriting data. Thumbnail failure does not invalidate a saved document.

### Tela.Catalog

- `search(query, filters \\ %{})`
- Seed and indexing helpers stay internal or in `Tela.Catalog.Seed`.
- FTS input is normalized and parameterized. Result limits are bounded.

### Tela.Media

- `upload(user_id, upload)`
- `list_uploads(user_id)`
- `search_external(query, provider, page \\ 1)`
- `import_external(user_id, provider, external_id)`

External import accepts only provider and external ID. The provider resolves the download URL server-side. Downloads require HTTPS, allowed hosts, supported MIME signatures, and bounded file sizes. Results are cached per user with a unique `(owner_id, source, external_id)` constraint. Provider failures can return partial search results.

### Tela.Brands

- `create_kit(user_id, attrs)`
- `update_kit(kit_id, user_id, attrs)`
- `delete_kit(kit_id, user_id)`
- `list_kits(user_id)`

All operations enforce ownership.

## 4. Persistence

### users

Generated with `mix phx.gen.auth`, plus `name`. No presence-specific avatar color.

### designs

```text
id              binary_id
owner_id        users, null only for public templates
title           string
document        map
width           integer
height          integer
page_count      integer
preset_id       string, nullable
category        string
is_template     boolean
revision        integer
thumbnail_path  string, nullable
inserted_at     utc_datetime
updated_at      utc_datetime
```

Indexes cover `(owner_id, updated_at)`, `(is_template, category)`, and `(owner_id, is_template)`.

### brand_kits

```text
id         binary_id
owner_id   users, required
name       string
colors     map containing hex values
fonts      map with heading and body families
logos      map containing upload references
timestamps
```

### media_uploads

```text
id            binary_id
owner_id      users, required
filename      string
storage_path  string
content_type  string
byte_size     integer
source        upload | pexels | pixabay | wikimedia
external_id   string, nullable
attribution   string, nullable
width         integer
height        integer
timestamps
```

Uploads and thumbnails live in a configurable data directory outside `priv/static`, suitable for releases and backups.

### catalog_assets and catalog_assets_fts

The base table uses integer IDs for FTS rowids. The FTS5 table uses `unicode61 remove_diacritics 2` and external content. Insert, update, and delete triggers keep it synchronized. Seeds pin package versions and retain source and license metadata.

SQLite runs with WAL, foreign keys, and a busy timeout. Tests use the SQL sandbox.

## 5. TypeScript document and editor

```text
assets/js/
  hooks/fabric_canvas.ts
  editor/
    document/types.ts
    document/factory.ts
    document/migrations.ts
    document/operations.ts
    engine/editor.ts
    engine/page_canvas.ts
    engine/commands.ts
    engine/history.ts
    engine/persistence.ts
    engine/serialization.ts
    engine/render.ts
    engine/export.ts
    animation/model.ts
    animation/operations.ts
    animation/easing.ts
    animation/presets.ts
    animation/sampler.ts
    animation/frame_renderer.ts
    animation/transition_renderer.ts
    animation/playback.ts
    animation/timeline.ts
    animation/schedule.ts
    presenter/player.ts
    export/gif.ts
    export/gif_pixels.ts
    export/gif_protocol.ts
    export/gif_sink.ts
    export/gif_worker.ts
```

The document is versioned and independent of editor playback state:

```ts
interface TelaDocument {
  schemaVersion: 1
  width: number
  height: number
  pages: TelaPage[]
  meta?: { presetId?: string; brandKitId?: string }
}

interface TelaPage {
  id: string
  name?: string
  background: PageBackground
  objects: DocObject[]
  durationSec?: number
  transition?: PageTransition
}
```

Fabric object serialization may use `toObject(EXTRA_PROPS)`, wrapped in this document envelope. Initial extra properties are `id`, `name`, `locked`, `visible`, `assetId`, `catalogAssetId`, `effects`, `origFill`, `origStroke`, `docSrc`, and `animation`.

Only the active page has an interactive Fabric canvas. Page switching serializes the current page and loads the next. Pure document operations stay separate from Fabric side effects.

MVP page operations are select, add, duplicate, delete, and reorder. A document always retains at least one page. Undo and redo cover page, object, and animation edits.

## 6. Animation and presentation

Each object may contain `enter`, `emphasis`, and `exit` animations. Each animation stores preset, duration, delay, easing, optional direction, intensity, and loop. Pages may store `durationSec` and a transition.

Initial limits:

- Object duration: 100 ms to 10 seconds.
- Delay: 0 to 60 seconds.
- Transition duration: 200 ms to 3 seconds.
- Page duration: 1 to 60 seconds.

Initial enter/exit presets: `fade`, `rise`, `slide`, `pop`, `wipe`, and `spin`. Initial emphasis presets: `pulse`, `sway`, and `shake`. Initial page transitions: `fade`, `slide`, and `wipe`.

Animations act on whole objects. Unknown preset IDs survive persistence but play as `none`.

The animation panel supports preset selection, duration, delay, direction, easing, intensity, emphasis looping, and removal. Without an object selected it edits page duration and transitions. Timeline controls are play, pause, restart, seek, speed, and page loop; there is no multi-track editor.

Playback uses `requestAnimationFrame` and a separate preview canvas. It never sends per-frame LiveView events, writes the document, creates history entries, or triggers autosave. Static layers are cached. Presentation supports next, previous, autoplay, fullscreen, keyboard controls, and transitions. Reduced-motion defaults disable autoplay and animated preset thumbnails while allowing manual playback.

## 7. LiveView and hook protocol

Client to LiveView:

| Event | Purpose |
| --- | --- |
| `editor:ready` | Hook mounted and ready for initial data |
| `editor:selection_changed` | Contextual property summary |
| `editor:layers_updated` | Layer names, ordering, visibility, and locks |
| `editor:pages_updated` | Page summary |
| `editor:dirty` | Unsaved changes exist |
| `design:save` | Document, expected revision, and optional thumbnail |

`design:save` uses `pushEvent` replies containing the new revision and save time, or an error such as `revision_conflict`.

LiveView to client:

| Event | Purpose |
| --- | --- |
| `canvas:init` | Initial document and active page |
| `canvas:add_element` | Insert text, shape, SVG, or image |
| `canvas:update_active` | Update selected object properties |
| `canvas:layer_action` | Arrange, duplicate, lock, hide, or delete |
| `canvas:page_action` | Add, duplicate, delete, select, or reorder |
| `canvas:history_action` | Undo or redo |
| `canvas:apply_brand` | Apply brand colors or fonts |
| `canvas:export` | Start a client-side export |

There is no `canvas:remote_sync`. Mouse movement and scaling do not emit LiveView traffic. Commits happen on `object:modified`. Thumbnails use a separate debounce. The complete document is not retained as a long-lived LiveView assign.

## 8. Static and animated export

PNG and JPG support 1x, 2x, and 3x multipliers. SVG embeds external images where necessary. PDF uses a rasterized page per document page to preserve appearance and fonts. Static exports show the resting state, excluding editor controls.

GIF export is deterministic, not a screen recording:

```text
TelaDocument -> timeline -> FrameCursor -> frame renderer
             -> RGBA pixels -> Web Worker -> gifenc -> Blob -> download
```

The timeline covers pages and transitions. Non-looping animations determine a minimum page duration. Looping emphasis does not make a page infinite. Frame time derives from the integer frame index to avoid cumulative rounding errors.

Initial GIF options:

- Current page or all pages.
- Longest side: 240, 360, 480, or 720 px; default 480.
- 10 or 15 fps; default 15.
- Infinite loop or one playback.
- Dithering disabled by default.
- Maximum duration 30 seconds.
- Warning above an estimated 25 MB and hard stop at 100 MB.
- Progress and cancellation in the UI.

GIF encoding loads `gifenc` only when needed. Quantization and LZW run in a Web Worker bundled by esbuild. Repeated frames extend the previous frame delay. Export cancellation disposes renderer and worker resources without changing the document or save state.

## 9. Semantic design system

### Token layers

```text
assets/css/
  app.css
  tokens/primitives.css
  tokens/semantic.css
  tokens/tailwind.css
  components/*.css
```

Primitive tokens hold palette and scales. Components consume only semantic roles such as page, surface, workspace, ink, muted, line, accent, focus, selection, success, warning, and danger. Hex values and primitive color utilities do not appear in component templates.

Tailwind v4 exposes semantic variables through `@theme inline`. The Phoenix-generated Tailwind import syntax is preserved and `@apply` is not used.

Themes remap semantic tokens through `data-theme`. The MVP ships the default theme, with a structure that supports dark and high-contrast themes later. User document colors and Brand Kits are content, not UI tokens. Theme changes never alter designs, thumbnails, or exports.

Fabric selection, guides, hover, rulers, and grid read computed semantic tokens through a canvas theme adapter. The navigation topbar also reads its color from CSS instead of a hard-coded hex value.

### Phoenix components

```text
lib/tela_web/components/
  actions.ex
  forms.ex
  feedback.ex
  navigation.ex
  data_display.ex
  overlays.ex
  editor.ex
  helpers.ex
```

The generated `CoreComponents` module and daisyUI classes are replaced. `TelaWeb.html_helpers` imports shared component modules. Editor-specific components are used explicitly by editor screens. Icons use the installed `Lucideicons.<icon_name>/1` function components directly in HEEx, with semantic sizing and `currentColor`; there is no Heroicons wrapper.

Component groups:

- Actions: button, icon button, and button group.
- Forms: input, field, label, hint, error, select, checkbox, radio, switch, and input group.
- Feedback: flash, alert, badge, spinner, skeleton, progress, empty state, and save status.
- Navigation: tabs, breadcrumbs, nav item, segmented control, and pagination if needed.
- Data display: header, stream-aware table, list, description list, thumbnail, aspect ratio, and asset grid.
- Overlays: dialog, drawer, dropdown, menu, popover, and non-interactive tooltip.
- Editor: tool rail, tool button, panel, property group, number field, slider field, color controls, font picker, layer row, page thumbnail, zoom, playback, animation preset, and export options.

Variants use semantic names such as `primary`, `secondary`, `outline`, `ghost`, and `danger`. States use attributes such as `data-state`, `data-selected`, `aria-invalid`, and `aria-disabled`. Classes supplied by callers extend the base style rather than accidentally removing it.

Accessibility includes associated labels and errors, focus visibility, keyboard navigation, dialog focus trapping and restoration, Escape handling, reduced motion, and semantic native controls wherever possible. `flash_group` remains in `Layouts`. All LiveView templates use `Layouts.app` and `current_scope` where required.

A development-only `/dev/styleguide` documents foundations, all component states, and product compositions. New shared components require declared attrs/slots, documentation, semantic tokens, accessibility behavior, styleguide coverage, and contract tests. Product-specific compositions stay near their features.

## 10. Visual direction

The direction is a contemporary graphic atelier: expressive dashboard, quiet editor.

- Warm paper, near-black ink, coral actions, cobalt selection/focus, and restrained pear-green accents.
- DM Sans for interface and Instrument Serif for brand and short editorial headings.
- Moderate radii, visible borders, no decorative gradients, and shadows concentrated on artboards and overlays.
- Crop marks, framing corners, and small offset outlines as graphic motifs.
- Dashboard with real aspect-ratio presets, large design thumbnails, color blocking, and concise personal copy.
- Editor with neutral chrome, compact panels, coral primary actions, and cobalt selection.
- Motion between 120 and 180 ms, minimal displacement, and reduced-motion support.

## 11. Delivery phases

### Phase 0: contracts and base

- Write this plan and the initial architecture.
- Define document, animation, context, event, token, and component contracts.
- Add unit and contract tests before delegating implementation.
- Commit the base and tests as the reference point. Implementers must not change those tests.

### Phase 1: foundation and projects

- Authentication and owner scoping.
- SQLite configuration and migrations.
- Design context and dashboard CRUD.
- Semantic tokens, base components, and development styleguide.

Acceptance: users can manage only their own projects, and the base component contracts pass.

### Phase 2: vertical editor

- Document operations, Fabric projection, objects, selection, pages, layers, history, autosave, and thumbnails.

Acceptance: a multipage design survives reload without changes and stale saves cannot overwrite newer work.

### Phase 3: animation

- Presets, animation panel, playback, presentation, frame rendering, and transitions.

Acceptance: deterministic preview and presentation, with animation edits covered by undo/redo and no persistence side effects during playback.

### Phase 4: catalog and uploads

- FTS5, pinned catalog seeds, local upload validation, and asset insertion.

Acceptance: local search works offline and accent-insensitive queries return equivalent assets.

### Phase 5: brand and export

- Brand Kits and PNG, JPG, SVG, PDF, and animated GIF export.

Acceptance: static exports match the resting page and GIF structure, timing, looping, cancellation, and size limits pass tests.

### Phase 6: external photos

- Provider behaviours, concurrent search, partial failures, secure imports, and local caching.

Acceptance: one failed provider does not block local or remaining remote results.

### Phase 7: hardening

- Accessibility, browser smoke tests, payload limits, backups, release checks, and visual review with Tidewave.
- Finish with `mix precommit`, TypeScript checks, and browser verification.

## 12. Test and orchestration contract

- Contract tests are written before implementation agents start.
- Implementation agents use `opencode-go/gpt-6-luna` and follow this plan exactly.
- Agents do not modify existing tests. Any suspected incorrect test is reported to the orchestrator instead of edited.
- Each agent receives a bounded scope and owned file set. Parallel work must not share files.
- The orchestrator reviews diffs, checks the committed test baseline, runs verification, and integrates changes.
- Elixir tests cover ownership, revisions, document limits, FTS behavior, MIME validation, providers, and component contracts.
- TypeScript tests cover migrations, page invariants, history, animation timing, deterministic frames, GIF scheduling, looping, and cancellation.
- LiveView tests assert elements and attributes through LiveViewTest/LazyHTML, not raw HTML strings.
- Browser checks cover the main design flow, keyboard interactions, responsive panels, export, and visual states.
