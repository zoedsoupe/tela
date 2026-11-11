defmodule TelaWeb.EditorLive do
  use TelaWeb, :live_view

  alias Tela.Designs
  alias Tela.Profiles
  alias TelaWeb.Components.Editor, as: EditorComponents

  @impl true
  def mount(%{"id" => design_id}, session, socket) do
    case Designs.get(design_id) do
      {:ok, design} ->
        current_profile = load_current_profile(session["profile_id"])

        socket =
          socket
          |> assign(:design, design)
          |> assign(:current_profile, current_profile)
          |> assign(:save_status, :saved)
          |> assign(:animation_open?, false)
          |> assign(:layers, [])
          |> assign(:selection, nil)
          |> assign(:export_notice, nil)
          |> assign(:pages, page_summaries(design.document))
          |> assign(:active_page_id, first_page_id(design.document))

        {:ok, socket}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Esse projeto não foi encontrado.")
         |> push_navigate(to: "/")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <main class="-mx-4 -my-8 flex min-h-[calc(100vh-4rem)] flex-col bg-workspace sm:-mx-8 sm:-my-12">
        <header class="flex min-h-14 flex-wrap items-center justify-between gap-3 border-b border-line bg-surface px-4 py-2 sm:px-6">
          <div class="flex min-w-0 items-center gap-3">
            <.link
              navigate="/"
              aria-label="Voltar aos projetos"
              class="grid size-9 place-items-center rounded-md text-muted hover:bg-surface-secondary hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus"
            >
              <Lucideicons.arrow_left class="size-4" />
            </.link>
            <div class="min-w-0">
              <h1 id="editor-title" class="truncate text-sm font-semibold text-ink">
                {@design.title}
              </h1>
              <p class="text-[11px] text-muted">{@design.width} × {@design.height} px</p>
            </div>
            <span id="editor-save-status" class="ml-2 hidden sm:inline-flex">
              <.save_status status={@save_status} />
            </span>
          </div>

          <nav aria-label="Ações do editor" class="flex items-center gap-1.5">
            <.button
              id="editor-undo"
              variant={:ghost}
              size={:sm}
              phx-click="canvas:history_action"
              phx-value-action="undo"
            >
              <Lucideicons.undo_2 class="size-4" /><span class="hidden md:inline">Desfazer</span>
            </.button>
            <.button
              id="editor-redo"
              variant={:ghost}
              size={:sm}
              phx-click="canvas:history_action"
              phx-value-action="redo"
            >
              <Lucideicons.redo_2 class="size-4" /><span class="hidden md:inline">Refazer</span>
            </.button>
            <.button
              id="editor-animate"
              variant={:outline}
              size={:sm}
              phx-click="editor:toggle-animation"
              aria-expanded={to_string(@animation_open?)}
            >
              <Lucideicons.sparkles class="size-4" /> Animação
            </.button>
            <.button
              id="editor-export"
              variant={:secondary}
              size={:sm}
              phx-click="canvas:export"
              phx-value-format="png"
              phx-value-multiplier="1"
            >
              <Lucideicons.download class="size-4" /> Exportar
            </.button>
          </nav>
        </header>

        <div class="grid min-h-0 flex-1 grid-cols-[minmax(15rem,18rem)_minmax(0,1fr)_minmax(15rem,18rem)]">
          <aside
            aria-label="Ferramentas e páginas"
            class="flex min-h-0 flex-col border-r border-line bg-surface"
          >
            <EditorComponents.panel id="editor-tools" title="Inserir" class="border-b-0">
              <div class="grid grid-cols-4 gap-2">
                <EditorComponents.tool_button
                  label="Adicionar texto"
                  event="canvas:add_element"
                  value="text"
                >
                  <:icon><Lucideicons.type class="size-4" /></:icon>
                </EditorComponents.tool_button>
                <EditorComponents.tool_button
                  label="Adicionar retângulo"
                  event="canvas:add_element"
                  value="rect"
                >
                  <:icon><Lucideicons.square class="size-4" /></:icon>
                </EditorComponents.tool_button>
                <EditorComponents.tool_button
                  label="Adicionar elipse"
                  event="canvas:add_element"
                  value="ellipse"
                >
                  <:icon><Lucideicons.circle class="size-4" /></:icon>
                </EditorComponents.tool_button>
              </div>
              <form id="editor-image-form" phx-submit="canvas:add_element" class="mt-3 flex gap-2">
                <input type="hidden" name="action" value="image" />
                <input
                  id="editor-image-src"
                  name="src"
                  type="url"
                  placeholder="URL da imagem"
                  aria-label="URL da imagem"
                  class="min-w-0 flex-1 rounded-md border border-line bg-page px-2.5 py-2 text-xs text-ink placeholder:text-muted focus:border-focus focus:outline-none focus:ring-2 focus:ring-focus/30"
                />
                <button
                  type="submit"
                  class="grid size-9 shrink-0 place-items-center rounded-md border border-line bg-surface text-muted hover:bg-surface-secondary hover:text-ink"
                  aria-label="Adicionar imagem"
                >
                  <Lucideicons.image_plus class="size-4" />
                </button>
              </form>
            </EditorComponents.panel>

            <EditorComponents.panel id="editor-pages" title="Páginas" class="flex-1 overflow-y-auto">
              <:actions>
                <button
                  type="button"
                  aria-label="Adicionar página"
                  title="Adicionar página"
                  class="grid size-7 place-items-center rounded text-muted hover:bg-surface-secondary hover:text-ink"
                  phx-click="canvas:page_action"
                  phx-value-action="add"
                >
                  <Lucideicons.plus class="size-4" />
                </button>
              </:actions>
              <div role="tablist" aria-label="Páginas do projeto" class="space-y-1">
                <button
                  :for={{page, index} <- Enum.with_index(@pages, 1)}
                  id={"page-tab-#{page["id"]}"}
                  type="button"
                  role="tab"
                  aria-selected={to_string(page["id"] == @active_page_id)}
                  phx-click="canvas:page_action"
                  phx-value-action="select"
                  phx-value-page-id={page["id"]}
                  class={[
                    "flex w-full items-center gap-2 rounded-md border px-2 py-1.5 text-left",
                    if(page["id"] == @active_page_id,
                      do: "border-focus bg-surface-secondary",
                      else: "border-transparent hover:bg-surface-secondary"
                    )
                  ]}
                >
                  <span class="grid size-8 shrink-0 place-items-center rounded border border-line bg-page text-xs text-muted">{index}</span>
                  <span class="min-w-0 flex-1 truncate text-xs font-medium text-ink">{page["name"]}</span>
                </button>
              </div>
              <div class="mt-3 flex gap-1 border-t border-line pt-3">
                <button
                  type="button"
                  class="flex-1 rounded px-2 py-1.5 text-xs text-muted hover:bg-surface-secondary hover:text-ink"
                  phx-click="canvas:page_action"
                  phx-value-action="duplicate"
                  phx-value-page-id={@active_page_id}
                >Duplicar</button>
                <button
                  type="button"
                  class="flex-1 rounded px-2 py-1.5 text-xs text-muted hover:bg-surface-secondary hover:text-ink"
                  phx-click="canvas:page_action"
                  phx-value-action="delete"
                  phx-value-page-id={@active_page_id}
                >Excluir</button>
              </div>
              <div class="mt-2 flex gap-1">
                <button
                  type="button"
                  aria-label="Mover página para a esquerda"
                  class="flex-1 rounded px-2 py-1.5 text-xs text-muted hover:bg-surface-secondary hover:text-ink"
                  phx-click="canvas:page_action"
                  phx-value-action="reorder"
                  phx-value-page-id={@active_page_id}
                  phx-value-destination={
                    max(Enum.find_index(@pages, &(&1["id"] == @active_page_id)) - 1, 0)
                  }
                ><Lucideicons.arrow_left class="mx-auto size-3.5" /></button>
                <button
                  type="button"
                  aria-label="Mover página para a direita"
                  class="flex-1 rounded px-2 py-1.5 text-xs text-muted hover:bg-surface-secondary hover:text-ink"
                  phx-click="canvas:page_action"
                  phx-value-action="reorder"
                  phx-value-page-id={@active_page_id}
                  phx-value-destination={
                    min(
                      Enum.find_index(@pages, &(&1["id"] == @active_page_id)) + 1,
                      length(@pages) - 1
                    )
                  }
                ><Lucideicons.arrow_right class="mx-auto size-3.5" /></button>
              </div>
            </EditorComponents.panel>
          </aside>

          <section aria-label="Área de desenho" class="flex min-w-0 flex-col bg-workspace">
            <div class="flex min-h-0 flex-1 items-center justify-center overflow-auto p-8">
              <div
                id="fabric-canvas-frame"
                class="max-h-full max-w-full border border-line bg-page shadow-lg"
              >
                <canvas
                  id="fabric-canvas"
                  phx-hook="FabricCanvas"
                  phx-update="ignore"
                  data-design-id={@design.id}
                  aria-label="Tela de desenho"
                  class="block"
                />
              </div>
            </div>
            <footer class="flex min-h-12 items-center justify-between gap-3 border-t border-line bg-surface px-4">
              <div class="flex items-center gap-2 text-xs text-muted">
                <span>{@design.width} × {@design.height} px</span>
                <span aria-hidden="true">·</span>
                <span>{length(@pages)} páginas</span>
              </div>
              <div class="flex items-center gap-1">
                <button
                  type="button"
                  aria-label="Diminuir zoom"
                  class="grid size-8 place-items-center rounded text-muted hover:bg-surface-secondary hover:text-ink"
                  phx-click="canvas:update_active"
                  phx-value-action="zoom_out"
                ><Lucideicons.minus class="size-4" /></button>
                <button
                  type="button"
                  aria-label="Aumentar zoom"
                  class="grid size-8 place-items-center rounded text-muted hover:bg-surface-secondary hover:text-ink"
                  phx-click="canvas:update_active"
                  phx-value-action="zoom_in"
                ><Lucideicons.plus class="size-4" /></button>
                <button
                  type="button"
                  class="rounded px-2 py-1 text-xs text-muted hover:bg-surface-secondary"
                  phx-click="canvas:update_active"
                  phx-value-action="zoom_fit"
                >Ajustar</button>
              </div>
            </footer>
          </section>

          <aside
            aria-label="Camadas e propriedades"
            class="flex min-h-0 flex-col border-l border-line bg-surface"
          >
            <EditorComponents.panel id="editor-selection" title="Seleção">
              <p :if={!@selection} class="text-xs leading-5 text-muted">
                Selecione um elemento na tela ou na lista de camadas.
              </p>
              <div :if={@selection} class="space-y-1 text-xs">
                <p class="font-medium text-ink">{@selection["name"] || @selection["type"]}</p>
                <p class="text-muted">
                  {@selection["type"]} · {@selection["width"]} × {@selection["height"]} px
                </p>
              </div>
              <div :if={@selection} class="mt-3 grid grid-cols-2 gap-2 border-t border-line pt-3">
                <label class="space-y-1 text-[11px] text-muted">
                  Cor
                  <input
                    type="color"
                    name="fill"
                    aria-label="Cor do elemento selecionado"
                    phx-change="canvas:update_active"
                    value="#202124"
                    class="h-8 w-full cursor-pointer rounded border border-line bg-page p-1"
                  />
                </label>
                <label class="space-y-1 text-[11px] text-muted">
                  Tamanho do texto
                  <input
                    type="number"
                    name="fontSize"
                    min="8"
                    max="300"
                    aria-label="Tamanho do texto"
                    phx-change="canvas:update_active"
                    value={@selection["fontSize"] || 56}
                    class="h-8 w-full rounded border border-line bg-page px-2 text-xs text-ink"
                  />
                </label>
              </div>
              <div :if={@selection} class="mt-2 flex gap-1">
                <button
                  type="button"
                  aria-label="Trazer camada para frente"
                  class="flex-1 rounded px-2 py-1.5 text-xs text-muted hover:bg-surface-secondary"
                  phx-click="canvas:layer_action"
                  phx-value-action="front"
                  phx-value-object-id={@selection["id"]}
                ><Lucideicons.chevrons_up class="mx-auto size-4" /></button>
                <button
                  type="button"
                  aria-label="Enviar camada para trás"
                  class="flex-1 rounded px-2 py-1.5 text-xs text-muted hover:bg-surface-secondary"
                  phx-click="canvas:layer_action"
                  phx-value-action="back"
                  phx-value-object-id={@selection["id"]}
                ><Lucideicons.chevrons_down class="mx-auto size-4" /></button>
                <button
                  type="button"
                  aria-label="Duplicar camada"
                  class="flex-1 rounded px-2 py-1.5 text-xs text-muted hover:bg-surface-secondary"
                  phx-click="canvas:layer_action"
                  phx-value-action="duplicate"
                  phx-value-object-id={@selection["id"]}
                ><Lucideicons.copy class="mx-auto size-4" /></button>
                <button
                  type="button"
                  aria-label="Excluir camada"
                  class="flex-1 rounded px-2 py-1.5 text-xs text-muted hover:bg-surface-secondary"
                  phx-click="canvas:layer_action"
                  phx-value-action="delete"
                  phx-value-object-id={@selection["id"]}
                ><Lucideicons.trash_2 class="mx-auto size-4" /></button>
              </div>
            </EditorComponents.panel>
            <EditorComponents.panel
              id="editor-layers"
              title="Camadas"
              class="min-h-0 flex-1 overflow-y-auto"
            >
              <ol id="editor-layer-list" class="space-y-1">
                <EditorComponents.layer_row
                  :for={layer <- @layers}
                  id={"layer-#{layer["id"]}"}
                  object_id={layer["id"]}
                  name={layer["name"] || layer["type"]}
                  type={layer["type"]}
                  selected={layer["selected"] || false}
                  visible={layer["visible"] != false}
                  locked={layer["locked"] || false}
                />
                <li :if={@layers == []} class="px-2 py-6 text-center text-xs text-muted">
                  Ainda não há camadas.
                </li>
              </ol>
            </EditorComponents.panel>
            <section
              :if={@animation_open?}
              id="editor-animation-panel"
              class="border-t border-line bg-surface-secondary px-4 py-4"
            >
              <h2 class="text-xs font-semibold uppercase tracking-wide text-muted">Animação</h2>
              <p class="mt-2 text-xs leading-5 text-muted">
                O painel de animação está reservado para a próxima etapa.
              </p>
            </section>
          </aside>
        </div>

        <nav
          aria-label="Exportar projeto"
          class="flex flex-wrap items-center justify-end gap-2 border-t border-line bg-surface px-4 py-2"
        >
          <span class="mr-auto text-xs text-muted">PNG e JPG exportam a página atual. SVG, PDF e GIF serão habilitados na etapa de exportação.</span>
          <button
            type="button"
            class="rounded border border-line px-2.5 py-1.5 text-xs text-ink hover:bg-surface-secondary"
            phx-click="canvas:export"
            phx-value-format="png"
            phx-value-multiplier="1"
          >PNG · 1×</button>
          <button
            type="button"
            class="rounded border border-line px-2.5 py-1.5 text-xs text-ink hover:bg-surface-secondary"
            phx-click="canvas:export"
            phx-value-format="png"
            phx-value-multiplier="2"
          >PNG · 2×</button>
          <button
            type="button"
            class="rounded border border-line px-2.5 py-1.5 text-xs text-ink hover:bg-surface-secondary"
            phx-click="canvas:export"
            phx-value-format="png"
            phx-value-multiplier="3"
          >PNG · 3×</button>
          <button
            type="button"
            class="rounded border border-line px-2.5 py-1.5 text-xs text-ink hover:bg-surface-secondary"
            phx-click="canvas:export"
            phx-value-format="jpg"
            phx-value-multiplier="1"
          >JPG · 1×</button>
          <button
            type="button"
            class="rounded border border-line px-2.5 py-1.5 text-xs text-ink hover:bg-surface-secondary"
            phx-click="canvas:export"
            phx-value-format="jpg"
            phx-value-multiplier="2"
          >JPG · 2×</button>
          <button
            type="button"
            class="rounded border border-line px-2.5 py-1.5 text-xs text-ink hover:bg-surface-secondary"
            phx-click="canvas:export"
            phx-value-format="jpg"
            phx-value-multiplier="3"
          >JPG · 3×</button>
          <button
            type="button"
            class="rounded border border-line px-2.5 py-1.5 text-xs text-muted"
            disabled
            title="Disponível na etapa dedicada de exportação"
          >SVG / PDF / GIF</button>
        </nav>
        <p
          id="editor-export-notice"
          role="status"
          class="min-h-6 px-4 py-1 text-right text-xs text-muted"
        >
          {@export_notice}
        </p>
      </main>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("editor:ready", _params, socket) do
    design = socket.assigns.design

    {:noreply,
     push_event(socket, "canvas:init", %{
       document: design.document,
       revision: design.revision,
       activePageId: first_page_id(design.document)
     })}
  end

  def handle_event("design:save", params, socket) do
    design = socket.assigns.design

    input = %{
      design_id: design.id,
      document: Map.get(params, "document"),
      expected_revision: integer_param(Map.get(params, "expected_revision"))
    }

    case Designs.save_document(input) do
      {:ok, saved} ->
        {:reply, %{status: "saved", revision: saved.revision}, assign(socket, :design, saved)}

      {:error, :revision_conflict} ->
        case Designs.get(design.id) do
          {:ok, current} ->
            {:reply, %{status: "conflict", revision: current.revision},
             assign(socket, :design, current)}

          {:error, :not_found} ->
            {:reply, %{status: "error", reason: "not_found"}, socket}
        end

      {:error, reason} ->
        {:reply, %{status: "error", reason: inspect(reason)}, socket}
    end
  end

  def handle_event("editor:selection_changed", params, socket),
    do: {:noreply, assign(socket, :selection, Map.get(params, "selection"))}

  def handle_event("editor:layers_updated", params, socket),
    do: {:noreply, assign(socket, :layers, Map.get(params, "layers", []))}

  def handle_event("editor:pages_updated", params, socket) do
    socket =
      socket
      |> assign(:pages, Map.get(params, "pages", []))
      |> assign(:active_page_id, Map.get(params, "activePageId"))

    {:noreply, socket}
  end

  def handle_event("editor:dirty", %{"status" => status}, socket) do
    status =
      if status in ["saved", "saving", "dirty", "error", "conflict"],
        do: String.to_existing_atom(status),
        else: :dirty

    {:noreply, assign(socket, :save_status, status)}
  end

  def handle_event("editor:export_status", %{"message" => message}, socket),
    do: {:noreply, assign(socket, :export_notice, message)}

  def handle_event("editor:toggle-animation", _params, socket),
    do: {:noreply, update(socket, :animation_open?, &(!&1))}

  def handle_event("canvas:add_element", params, socket),
    do: forward_event(socket, "canvas:add_element", params)

  def handle_event("canvas:update_active", params, socket),
    do: forward_event(socket, "canvas:update_active", params)

  def handle_event("canvas:layer_action", params, socket),
    do: forward_event(socket, "canvas:layer_action", params)

  def handle_event("canvas:page_action", params, socket),
    do: forward_event(socket, "canvas:page_action", params)

  def handle_event("canvas:history_action", params, socket),
    do: forward_event(socket, "canvas:history_action", params)

  def handle_event("canvas:export", params, socket),
    do: forward_event(socket, "canvas:export", params)

  def handle_event(_event, _params, socket), do: {:noreply, socket}

  defp forward_event(socket, event, params), do: {:noreply, push_event(socket, event, params)}

  defp load_current_profile(profile_id) when is_binary(profile_id) do
    case Profiles.get_profile(profile_id) do
      {:ok, profile} -> profile
      {:error, :not_found} -> nil
    end
  end

  defp load_current_profile(_profile_id), do: nil

  defp integer_param(value) when is_integer(value), do: value

  defp integer_param(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} -> integer
      _ -> nil
    end
  end

  defp integer_param(_value), do: nil

  defp first_page_id(%{"pages" => [%{"id" => id} | _]}), do: id
  defp first_page_id(_document), do: nil

  defp page_summaries(%{"pages" => pages}) when is_list(pages) do
    Enum.map(pages, fn page ->
      %{
        "id" => page["id"],
        "name" =>
          page["name"] || "Página #{Enum.find_index(pages, &(&1["id"] == page["id"])) + 1}"
      }
    end)
  end

  defp page_summaries(_document), do: []
end
