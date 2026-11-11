defmodule TelaWeb.DashboardLive do
  use TelaWeb, :live_view

  alias Tela.Designs
  alias Tela.Designs.Preset
  alias Tela.Profiles

  @impl true
  def mount(_params, session, socket) do
    {:ok, designs} = Designs.list()
    current_profile = load_current_profile(session["profile_id"])

    socket =
      socket
      |> assign(:current_profile, current_profile)
      |> assign(:designs_empty?, designs == [])
      |> assign(:presets, Preset.all())
      |> assign(:profile_form, to_form(%{"name" => ""}, as: :profile))
      |> assign(:rename_design_id, nil)
      |> assign(:rename_form, to_form(%{"title" => ""}, as: :design))
      |> stream(:designs, designs, dom_id: &"design-#{&1.id}")

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="space-y-12">
        <section class="relative overflow-hidden rounded-xl border border-line bg-surface px-6 py-8 sm:px-10 sm:py-12">
          <div
            class="absolute -right-10 -top-12 size-48 rounded-full border border-accent/20 sm:size-64"
            aria-hidden="true"
          />
          <div class="relative max-w-3xl">
            <p class="text-xs font-semibold uppercase tracking-[0.2em] text-accent">
              Seu espaço de criação
            </p>
            <h1 class="mt-4 max-w-2xl font-display text-4xl leading-tight text-ink sm:text-6xl">
              Ideias ganham forma por aqui.
            </h1>
            <p class="mt-4 max-w-xl text-base leading-7 text-muted">
              Um espaço compartilhado para criar peças, convites e apresentações no seu ritmo.
            </p>
            <a
              href="#formatos"
              class="mt-7 inline-flex items-center gap-2 rounded-md border border-line bg-page px-4 py-2.5 text-sm font-semibold text-ink transition-colors hover:bg-surface-secondary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus"
            >
              <Lucideicons.panels_top_left class="size-4" /> Explorar formatos
              <Lucideicons.arrow_down class="size-4" />
            </a>
          </div>
          <div
            class="absolute bottom-8 right-10 hidden rotate-3 border border-line bg-page p-3 shadow-lg lg:block"
            aria-hidden="true"
          >
            <div class="grid aspect-[4/3] w-40 place-items-center bg-accent-soft">
              <Lucideicons.sparkles class="size-10 text-accent" />
            </div>
            <p class="mt-2 font-display text-lg">uma boa ideia</p>
          </div>
        </section>

        <section aria-labelledby="formats-heading" id="formatos" class="space-y-5">
          <div class="flex flex-wrap items-end justify-between gap-3">
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.16em] text-muted">
                Comece pelas dimensões
              </p>
              <h2 id="formats-heading" class="mt-1 font-display text-2xl text-ink">
                Formatos para toda ideia
              </h2>
            </div>
            <span class="text-sm text-muted">{length(@presets)} formatos disponíveis</span>
          </div>

          <div class="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-5">
            <article
              :for={preset <- @presets}
              id={"preset-#{preset.id}"}
              class="group rounded-lg border border-line bg-surface p-3 transition-transform duration-fast hover:-translate-y-1 hover:border-line-strong sm:p-4"
            >
              <button
                id={"create-design-#{preset.id}"}
                type="button"
                phx-click="create_design"
                phx-value-preset_id={preset.id}
                aria-label={"Criar projeto no formato #{preset.name}"}
                class="block w-full rounded-md text-left focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus"
              >
                <div class="grid aspect-[4/3] place-items-center overflow-hidden rounded-md bg-surface-secondary p-4">
                  <div
                    class="grid max-h-full max-w-full place-items-center border border-line bg-page text-accent transition-colors group-hover:bg-accent-soft"
                    style={preset_preview_style(preset)}
                    aria-hidden="true"
                  >
                    <Lucideicons.scan class="size-5" />
                  </div>
                </div>
                <span class="mt-3 block text-sm font-semibold text-ink">{preset.name}</span>
                <span class="mt-1 block text-xs text-muted">{preset.width} × {preset.height} px</span>
                <span class="sr-only">Criar projeto</span>
              </button>
            </article>
          </div>
        </section>

        <section aria-labelledby="designs-heading" class="space-y-5">
          <div class="flex flex-wrap items-end justify-between gap-3">
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.16em] text-muted">
                Feito em conjunto
              </p>
              <h2 id="designs-heading" class="mt-1 font-display text-2xl text-ink">
                Projetos do espaço
              </h2>
            </div>
            <span class="text-sm text-muted">Compartilhados com quem tem acesso</span>
          </div>

          <div
            id="workspace-designs"
            phx-update="stream"
            class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3"
          >
            <article
              :for={{dom_id, design} <- @streams.designs}
              id={dom_id}
              class="group overflow-hidden rounded-lg border border-line bg-surface transition-shadow hover:shadow-md"
            >
              <div class="grid aspect-[4/3] place-items-center bg-workspace p-6">
                <div
                  data-design-format={design.preset_id}
                  class="grid aspect-[4/3] w-2/3 place-items-center overflow-hidden border border-line bg-page shadow-sm"
                >
                  <span class="font-display text-2xl text-ink">{design.title}</span>
                </div>
              </div>
              <div class="flex items-center justify-between gap-3 p-4">
                <div class="min-w-0">
                  <h3 class="truncate font-semibold text-ink">{design.title}</h3>
                  <p class="mt-1 text-xs text-muted">
                    {design.width} × {design.height} px · {design.page_count} página(s)
                  </p>
                </div>
                <.link
                  navigate={"/designs/#{design.id}"}
                  aria-label={"Abrir #{design.title}"}
                  class="grid size-9 shrink-0 place-items-center rounded-md border border-line text-muted transition-colors hover:bg-surface-secondary hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus"
                >
                  <Lucideicons.arrow_up_right class="size-4" />
                </.link>
              </div>
              <div class="border-t border-line px-4 py-3">
                <details id={"design-actions-#{design.id}"} class="group/actions">
                  <summary class="flex cursor-pointer list-none items-center gap-2 text-sm font-medium text-muted outline-none transition-colors hover:text-ink focus-visible:ring-2 focus-visible:ring-focus [&::-webkit-details-marker]:hidden">
                    <Lucideicons.ellipsis class="size-4" aria-hidden="true" />
                    <span>Ações do projeto</span>
                    <Lucideicons.chevron_down
                      class="ml-auto size-4 transition-transform group-open/actions:rotate-180"
                      aria-hidden="true"
                    />
                  </summary>
                  <div class="mt-3 space-y-3 border-t border-line pt-3">
                    <button
                      id={"duplicate-design-#{design.id}"}
                      type="button"
                      phx-click="duplicate_design"
                      phx-value-id={design.id}
                      class="flex min-h-9 w-full items-center gap-2 rounded-md px-2 text-left text-sm text-ink transition-colors hover:bg-surface-secondary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus"
                    >
                      <Lucideicons.copy class="size-4 text-muted" aria-hidden="true" />
                      Duplicar projeto
                    </button>
                    <%= if @rename_design_id == design.id do %>
                      <.form
                        for={@rename_form}
                        id={"rename-design-form-#{design.id}"}
                        phx-submit="rename_design"
                        phx-value-id={design.id}
                        class="space-y-2"
                      >
                        <.input field={@rename_form[:title]} label="Novo título" />
                        <div class="flex gap-2">
                          <.button type="submit" class="min-h-9 px-3 py-1.5 text-sm">
                            Salvar nome
                          </.button>
                          <button
                            type="button"
                            phx-click="cancel_rename"
                            class="min-h-9 rounded-md px-3 py-1.5 text-sm text-muted hover:bg-surface-secondary hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus"
                          >
                            Cancelar
                          </button>
                        </div>
                      </.form>
                    <% else %>
                      <button
                        id={"start-rename-design-#{design.id}"}
                        type="button"
                        phx-click="rename_design"
                        phx-value-id={design.id}
                        class="flex min-h-9 w-full items-center gap-2 rounded-md px-2 text-left text-sm text-ink transition-colors hover:bg-surface-secondary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus"
                      >
                        <Lucideicons.pencil class="size-4 text-muted" aria-hidden="true" />
                        Renomear projeto
                      </button>
                    <% end %>
                    <details id={"delete-confirmation-#{design.id}"} class="rounded-md">
                      <summary class="flex min-h-9 cursor-pointer list-none items-center gap-2 rounded-md px-2 text-sm text-danger outline-none transition-colors hover:bg-danger-soft focus-visible:ring-2 focus-visible:ring-focus [&::-webkit-details-marker]:hidden">
                        <Lucideicons.trash_2 class="size-4" aria-hidden="true" /> Excluir projeto…
                      </summary>
                      <div class="mt-2 rounded-md border border-danger/30 bg-danger-soft p-3">
                        <p class="text-sm text-ink">Excluir “{design.title}” deste espaço?</p>
                        <button
                          id={"confirm-delete-design-#{design.id}"}
                          type="button"
                          phx-click="delete_design"
                          phx-value-id={design.id}
                          class="mt-3 inline-flex min-h-9 items-center gap-2 rounded-md bg-danger px-3 py-1.5 text-sm font-semibold text-white transition-colors hover:bg-danger/90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus"
                        >
                          <Lucideicons.trash_2 class="size-4" aria-hidden="true" /> Confirmar exclusão
                        </button>
                      </div>
                    </details>
                  </div>
                </details>
              </div>
            </article>
            <div
              :if={@designs_empty?}
              id="designs-empty"
              class="col-span-full grid min-h-56 place-items-center rounded-lg border border-dashed border-line bg-surface px-6 py-10 text-center"
            >
              <div class="max-w-sm">
                <span class="mx-auto grid size-12 place-items-center rounded-full bg-accent-soft text-accent"><Lucideicons.shapes class="size-5" /></span>
                <h3 class="mt-4 font-display text-xl text-ink">
                  Seu próximo projeto começa com uma ideia
                </h3>
                <p class="mt-2 text-sm leading-6 text-muted">
                  Os projetos criados neste espaço aparecem aqui para todo mundo acompanhar.
                </p>
              </div>
            </div>
          </div>
        </section>

        <section
          aria-labelledby="profile-heading"
          class="grid gap-6 rounded-xl border border-line bg-surface p-5 sm:grid-cols-[1fr_auto] sm:items-center sm:p-7"
        >
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.16em] text-muted">
              Identificação opcional
            </p>
            <h2 id="profile-heading" class="mt-1 font-display text-2xl text-ink">
              Quem está criando?
            </h2>
            <%= if @current_profile do %>
              <p
                id="current-profile"
                data-profile-id={@current_profile.id}
                class="mt-2 flex items-center gap-2 text-sm text-muted"
              >
                <Lucideicons.circle_user_round class="size-4 text-accent" />
                Você está usando o perfil <strong class="font-semibold text-ink">{@current_profile.name}</strong>.
              </p>
            <% else %>
              <p class="mt-2 max-w-xl text-sm leading-6 text-muted">
                Crie um perfil local para identificar quem criou cada peça. Ele não é uma conta e não limita o acesso ao espaço.
              </p>
            <% end %>
          </div>

          <.form
            for={@profile_form}
            action="/profiles"
            method="post"
            id="profile-selection"
            class="flex w-full flex-col gap-3 sm:min-w-80 sm:flex-row sm:items-end"
          >
            <.input
              field={@profile_form[:name]}
              label="Seu nome"
              placeholder="Como podemos chamar você?"
              autocomplete="name"
            />
            <.button type="submit" class="shrink-0">
              <Lucideicons.user_round_plus class="size-4" /> Criar perfil
            </.button>
          </.form>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("create_design", %{"preset_id" => preset_id}, socket) do
    attrs = %{
      created_by_id: profile_id(socket.assigns.current_profile),
      title: "Sem título",
      preset_id: preset_id
    }

    case Designs.create(attrs) do
      {:ok, design} -> {:noreply, push_navigate(socket, to: "/designs/#{design.id}")}
      {:error, _reason} -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("duplicate_design", %{"id" => design_id}, socket) do
    case Designs.duplicate(design_id, profile_id(socket.assigns.current_profile)) do
      {:ok, _design} -> {:noreply, refresh_designs(socket)}
      {:error, _reason} -> {:noreply, socket}
    end
  end

  @impl true
  def handle_event("rename_design", %{"id" => design_id} = params, socket) do
    case rename_title(params) do
      nil ->
        case Designs.get(design_id) do
          {:ok, design} ->
            socket =
              socket
              |> assign(:rename_design_id, design.id)
              |> assign(:rename_form, to_form(%{"title" => design.title}, as: :design))
              |> refresh_designs()

            {:noreply, socket}

          {:error, _reason} ->
            {:noreply, socket}
        end

      title ->
        case Designs.rename(design_id, title) do
          {:ok, _design} ->
            socket =
              socket
              |> assign(:rename_design_id, nil)
              |> refresh_designs()

            {:noreply, socket}

          {:error, _reason} ->
            {:noreply, socket}
        end
    end
  end

  @impl true
  def handle_event("cancel_rename", _params, socket) do
    {:noreply, socket |> assign(:rename_design_id, nil) |> refresh_designs()}
  end

  @impl true
  def handle_event("delete_design", %{"id" => design_id}, socket) do
    case Designs.delete(design_id) do
      {:ok, _design} ->
        socket =
          socket
          |> assign(:rename_design_id, nil)
          |> refresh_designs()

        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  defp refresh_designs(socket) do
    {:ok, designs} = Designs.list()

    socket
    |> assign(:designs_empty?, designs == [])
    |> stream(:designs, designs, reset: true, dom_id: &"design-#{&1.id}")
  end

  defp profile_id(nil), do: nil
  defp profile_id(profile), do: profile.id

  defp rename_title(%{"title" => title}) when is_binary(title), do: title
  defp rename_title(%{"design" => %{"title" => title}}) when is_binary(title), do: title
  defp rename_title(_params), do: nil

  defp load_current_profile(profile_id) when is_binary(profile_id) do
    case Profiles.get_profile(profile_id) do
      {:ok, profile} -> profile
      {:error, :not_found} -> nil
    end
  end

  defp load_current_profile(_profile_id), do: nil

  defp preset_preview_style(preset) do
    ratio = preset.width / preset.height

    if ratio > 1 do
      "width: 88%; aspect-ratio: #{preset.width} / #{preset.height}"
    else
      "height: 88%; aspect-ratio: #{preset.width} / #{preset.height}"
    end
  end
end
