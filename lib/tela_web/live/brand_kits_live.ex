defmodule TelaWeb.BrandKitsLive do
  use TelaWeb, :live_view

  alias Tela.Brands
  alias Tela.Profiles

  @impl true
  def mount(_params, session, socket) do
    {:ok, kits} = Brands.list_kits()

    socket =
      socket
      |> assign(:current_profile, load_current_profile(session["profile_id"]))
      |> assign(:current_scope, nil)
      |> assign(:kits_empty?, kits == [])
      |> assign(:editing_kit_id, nil)
      |> assign(:color_error, nil)
      |> assign(:form_error, nil)
      |> assign(:form, blank_form())
      |> stream(:brand_kits, kits, dom_id: &"brand-kit-#{&1.id}")

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-6xl space-y-10">
        <header class="relative overflow-hidden rounded-xl border border-line bg-surface px-6 py-8 sm:px-10 sm:py-11">
          <div
            class="absolute -right-8 -top-10 size-44 rounded-full border border-accent/20 sm:size-56"
            aria-hidden="true"
          />
          <div class="relative max-w-2xl">
            <p class="text-xs font-semibold uppercase tracking-[0.18em] text-accent">
              Sistema da marca
            </p>
            <h1 class="mt-3 font-display text-4xl leading-tight text-ink sm:text-5xl">
              Identidade visual
            </h1>
            <p class="mt-4 max-w-xl text-sm leading-6 text-muted sm:text-base">
              Reúna cores e tipografias para que todo mundo crie peças com a mesma linguagem.
              Os kits ficam disponíveis para todo o espaço.
            </p>
          </div>
        </header>

        <section
          aria-labelledby="brand-kit-form-heading"
          class="grid gap-8 lg:grid-cols-[minmax(0,0.85fr)_minmax(0,1.15fr)]"
        >
          <div class="space-y-3">
            <p class="text-xs font-semibold uppercase tracking-[0.16em] text-muted">
              {if @editing_kit_id, do: "Atualize o conjunto", else: "Crie uma referência"}
            </p>
            <h2 id="brand-kit-form-heading" class="font-display text-2xl text-ink">
              {if @editing_kit_id, do: "Editar Brand Kit", else: "Novo Brand Kit"}
            </h2>
            <p class="max-w-md text-sm leading-6 text-muted">
              Defina uma paleta e duas famílias tipográficas. Você poderá ajustar estas informações depois.
            </p>
            <div class="flex items-center gap-2 pt-2 text-xs text-muted">
              <Lucideicons.users_round class="size-4 text-accent" aria-hidden="true" />
              <span>Compartilhado com quem tem acesso ao espaço</span>
            </div>
          </div>

          <.form
            for={@form}
            id="brand-kit-form"
            phx-change="validate"
            phx-submit="save_brand_kit"
            class="space-y-5 rounded-xl border border-line bg-surface p-5 sm:p-6"
          >
            <.input
              field={@form[:name]}
              id={@form[:name].id}
              name={@form[:name].name}
              value={@form[:name].value}
              label="Nome do kit"
              placeholder="Ex.: Feira de domingo"
              autocomplete="off"
              required
            />
            <div class="space-y-1.5">
              <.input
                field={@form[:colors]}
                id={@form[:colors].id}
                name={@form[:colors].name}
                value={@form[:colors].value}
                label="Cores da marca"
                placeholder="#A94330, #3859A8"
                autocomplete="off"
                required
              />
              <p id="brand-kit-colors-hint" class="text-xs text-muted">
                Use valores hexadecimais de seis dígitos separados por vírgula.
              </p>
              <p
                :if={@color_error}
                id="brand-kit-colors-error"
                role="alert"
                class="flex items-start gap-1.5 text-sm text-danger"
              >
                <Lucideicons.circle_alert class="mt-0.5 size-4 shrink-0" aria-hidden="true" />
                <span>{@color_error}</span>
              </p>
            </div>
            <div class="grid gap-4 sm:grid-cols-2">
              <.input
                field={@form[:heading_font]}
                id={@form[:heading_font].id}
                name={@form[:heading_font].name}
                value={@form[:heading_font].value}
                label="Tipografia de destaque"
                placeholder="Instrument Serif"
                autocomplete="off"
                required
              />
              <.input
                field={@form[:body_font]}
                id={@form[:body_font].id}
                name={@form[:body_font].name}
                value={@form[:body_font].value}
                label="Tipografia de leitura"
                placeholder="DM Sans"
                autocomplete="off"
                required
              />
            </div>
            <p :if={@form_error} id="brand-kit-form-error" role="alert" class="text-sm text-danger">
              {@form_error}
            </p>
            <div class="flex flex-wrap items-center gap-3 border-t border-line pt-4">
              <.button id="save-brand-kit" type="submit">
                <Lucideicons.save class="size-4" aria-hidden="true" />
                {if @editing_kit_id, do: "Salvar alterações", else: "Criar Brand Kit"}
              </.button>
              <button
                :if={@editing_kit_id}
                id="cancel-brand-kit-edit"
                type="button"
                phx-click="cancel_edit"
                class="inline-flex min-h-10 items-center rounded-md px-3 text-sm font-medium text-muted transition-colors hover:bg-surface-secondary hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus"
              >
                Cancelar
              </button>
            </div>
          </.form>
        </section>

        <section aria-labelledby="shared-brand-kits-heading" class="space-y-5">
          <div class="flex flex-wrap items-end justify-between gap-3">
            <div>
              <p class="text-xs font-semibold uppercase tracking-[0.16em] text-muted">
                Biblioteca compartilhada
              </p>
              <h2 id="shared-brand-kits-heading" class="mt-1 font-display text-2xl text-ink">
                Kits disponíveis
              </h2>
            </div>
            <span class="text-sm text-muted">Uma referência comum para cada criação</span>
          </div>

          <div id="brand-kits" phx-update="stream" class="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
            <article
              :for={{dom_id, kit} <- @streams.brand_kits}
              id={dom_id}
              data-brand-kit-name={kit.name}
              class="overflow-hidden rounded-xl border border-line bg-surface transition-shadow duration-fast hover:shadow-md"
            >
              <div class="border-b border-line bg-workspace p-5">
                <div class="flex items-start justify-between gap-4">
                  <div class="min-w-0">
                    <p class="text-[0.65rem] font-semibold uppercase tracking-[0.16em] text-muted">
                      Brand Kit
                    </p>
                    <h3 class="mt-1 truncate font-display text-xl text-ink">{kit.name}</h3>
                  </div>
                  <span
                    class="grid size-10 shrink-0 place-items-center rounded-full bg-surface text-accent"
                    aria-hidden="true"
                  >
                    <Lucideicons.swatch_book class="size-5" />
                  </span>
                </div>
                <div class="mt-5 flex flex-wrap gap-2" aria-label={"Cores de #{kit.name}"}>
                  <span
                    :for={color <- color_values(kit)}
                    class="size-8 rounded-full border border-line shadow-sm"
                    style={"background-color: #{color}"}
                    role="img"
                    aria-label={color}
                    title={color}
                  />
                </div>
              </div>
              <div class="space-y-4 p-5">
                <div class="grid grid-cols-2 gap-3">
                  <div class="min-w-0">
                    <p class="text-xs text-muted">Destaque</p>
                    <p class="mt-1 truncate text-sm font-medium text-ink">
                      {font_value(kit, "heading")}
                    </p>
                  </div>
                  <div class="min-w-0">
                    <p class="text-xs text-muted">Leitura</p>
                    <p class="mt-1 truncate text-sm font-medium text-ink">
                      {font_value(kit, "body")}
                    </p>
                  </div>
                </div>
                <p class="flex items-center gap-2 border-t border-line pt-3 text-xs text-muted">
                  <Lucideicons.image class="size-4" aria-hidden="true" />
                  {length(logo_items(kit))} logos adicionados
                </p>
                <div class="flex flex-wrap items-center gap-2">
                  <button
                    id={"edit-brand-kit-#{kit.id}"}
                    type="button"
                    phx-click="edit_kit"
                    phx-value-id={kit.id}
                    class="inline-flex min-h-9 items-center gap-2 rounded-md border border-line px-3 text-sm font-medium text-ink transition-colors hover:bg-surface-secondary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus"
                    aria-label={"Editar #{kit.name}"}
                  >
                    <Lucideicons.pencil class="size-4" aria-hidden="true" /> Editar
                  </button>
                  <details id={"delete-brand-kit-#{kit.id}"} class="group/delete relative">
                    <summary class="flex min-h-9 cursor-pointer list-none items-center gap-2 rounded-md px-3 text-sm font-medium text-danger outline-none transition-colors hover:bg-danger-soft focus-visible:ring-2 focus-visible:ring-focus [&::-webkit-details-marker]:hidden">
                      <Lucideicons.trash_2 class="size-4" aria-hidden="true" /> Excluir
                    </summary>
                    <div class="absolute right-0 z-10 mt-2 w-64 rounded-lg border border-danger/30 bg-surface p-4 shadow-lg">
                      <p class="text-sm leading-5 text-ink">Excluir “{kit.name}” do espaço?</p>
                      <div class="mt-3 flex justify-end gap-2">
                        <button
                          id={"confirm-delete-brand-kit-#{kit.id}"}
                          type="button"
                          phx-click="delete_kit"
                          phx-value-id={kit.id}
                          class="inline-flex min-h-9 items-center gap-2 rounded-md bg-danger px-3 text-sm font-semibold text-on-accent transition-colors hover:bg-danger/90 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus"
                        >
                          <Lucideicons.trash_2 class="size-4" aria-hidden="true" /> Confirmar
                        </button>
                      </div>
                    </div>
                  </details>
                </div>
              </div>
            </article>
            <div
              :if={@kits_empty?}
              id="brand-kits-empty"
              class="col-span-full grid min-h-52 place-items-center rounded-xl border border-dashed border-line bg-surface px-6 py-10 text-center"
            >
              <div class="max-w-sm">
                <span class="mx-auto grid size-12 place-items-center rounded-full bg-accent-soft text-accent">
                  <Lucideicons.swatch_book class="size-5" aria-hidden="true" />
                </span>
                <h3 class="mt-4 font-display text-xl text-ink">Sua identidade começa aqui</h3>
                <p class="mt-2 text-sm leading-6 text-muted">
                  Crie o primeiro Brand Kit para deixar cores e tipografias à mão de todo mundo.
                </p>
              </div>
            </div>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("validate", %{"brand" => params}, socket) do
    {:noreply,
     socket
     |> assign(:form, to_form(params, as: :brand))
     |> assign(:color_error, color_error(params["colors"]))
     |> assign(:form_error, nil)}
  end

  @impl true
  def handle_event("save_brand_kit", %{"brand" => params}, socket) do
    socket =
      socket
      |> assign(:form, to_form(params, as: :brand))
      |> assign(:form_error, nil)

    case parse_colors(params["colors"]) do
      {:ok, colors} ->
        save_kit(socket, params, colors)

      {:error, :invalid_colors} ->
        {:noreply,
         assign(socket, :color_error, "Informe uma ou mais cores válidas no formato #RRGGBB.")}
    end
  end

  @impl true
  def handle_event("save_brand_kit", _params, socket) do
    {:noreply, assign(socket, :form_error, "Preencha os campos para salvar o Brand Kit.")}
  end

  @impl true
  def handle_event("edit_kit", %{"id" => kit_id}, socket) do
    case find_kit(kit_id) do
      {:ok, kit} ->
        params = kit_form_params(kit)

        {:noreply,
         socket
         |> assign(:editing_kit_id, kit.id)
         |> assign(:form, to_form(params, as: :brand))
         |> assign(:color_error, nil)
         |> assign(:form_error, nil)}

      :error ->
        {:noreply, assign(socket, :form_error, "Não foi possível encontrar este Brand Kit.")}
    end
  end

  @impl true
  def handle_event("cancel_edit", _params, socket) do
    {:noreply, reset_form(socket)}
  end

  @impl true
  def handle_event("delete_kit", %{"id" => kit_id}, socket) do
    case Brands.delete_kit(kit_id) do
      {:ok, _kit} ->
        socket =
          if socket.assigns.editing_kit_id == kit_id do
            reset_form(socket)
          else
            socket
          end

        {:noreply, refresh_kits(socket)}

      {:error, :not_found} ->
        {:noreply, assign(socket, :form_error, "Este Brand Kit já não está disponível.")}

      {:error, _changeset} ->
        {:noreply, assign(socket, :form_error, "Não foi possível excluir o Brand Kit.")}
    end
  end

  defp save_kit(socket, params, colors) do
    attrs = %{
      name: param(params, "name") |> String.trim(),
      colors: %{"values" => colors},
      fonts: %{
        "heading" => param(params, "heading_font") |> String.trim(),
        "body" => param(params, "body_font") |> String.trim()
      },
      logos: %{"items" => []}
    }

    result =
      case socket.assigns.editing_kit_id do
        nil -> Brands.create_kit(profile_id(socket.assigns.current_profile), attrs)
        kit_id -> Brands.update_kit(kit_id, attrs)
      end

    case result do
      {:ok, _kit} ->
        {:noreply, socket |> reset_form() |> refresh_kits()}

      {:error, _changeset_or_reason} ->
        {:noreply,
         assign(socket, :form_error, "Confira o nome e as tipografias e tente novamente.")}
    end
  end

  defp refresh_kits(socket) do
    {:ok, kits} = Brands.list_kits()

    socket
    |> assign(:kits_empty?, kits == [])
    |> stream(:brand_kits, kits, reset: true, dom_id: &"brand-kit-#{&1.id}")
  end

  defp reset_form(socket) do
    socket
    |> assign(:editing_kit_id, nil)
    |> assign(:form, blank_form())
    |> assign(:color_error, nil)
    |> assign(:form_error, nil)
  end

  defp blank_form,
    do:
      to_form(%{"name" => "", "colors" => "", "heading_font" => "", "body_font" => ""},
        as: :brand
      )

  defp find_kit(kit_id) do
    with {:ok, kits} <- Brands.list_kits(),
         %{} = kit <- Enum.find(kits, &(&1.id == kit_id)) do
      {:ok, kit}
    else
      _ -> :error
    end
  end

  defp kit_form_params(kit) do
    %{
      "name" => kit.name || "",
      "colors" => color_values(kit) |> Enum.join(", "),
      "heading_font" => font_value(kit, "heading"),
      "body_font" => font_value(kit, "body")
    }
  end

  defp parse_colors(value) when is_binary(value) do
    colors = String.split(value, ",", trim: false) |> Enum.map(&String.trim/1)

    if colors != [] and Enum.all?(colors, &valid_color?/1) do
      {:ok, colors}
    else
      {:error, :invalid_colors}
    end
  end

  defp parse_colors(_value), do: {:error, :invalid_colors}

  defp color_error(value) do
    case parse_colors(value) do
      {:ok, _colors} -> nil
      {:error, :invalid_colors} -> "Informe uma ou mais cores válidas no formato #RRGGBB."
    end
  end

  defp valid_color?(color), do: Regex.match?(~r/^#[0-9A-Fa-f]{6}$/, color)

  defp color_values(kit) do
    case kit.colors do
      %{"values" => colors} when is_list(colors) -> colors
      %{values: colors} when is_list(colors) -> colors
      _ -> []
    end
  end

  defp font_value(kit, role) do
    Map.get(kit.fonts || %{}, role) || Map.get(kit.fonts || %{}, String.to_existing_atom(role)) ||
      "—"
  end

  defp logo_items(kit) do
    case kit.logos do
      %{"items" => items} when is_list(items) -> items
      %{items: items} when is_list(items) -> items
      _ -> []
    end
  end

  defp param(params, key) do
    case Map.get(params, key) do
      value when is_binary(value) -> value
      _ -> ""
    end
  end

  defp profile_id(nil), do: nil
  defp profile_id(profile), do: profile.id

  defp load_current_profile(profile_id) when is_binary(profile_id) do
    case Profiles.get_profile(profile_id) do
      {:ok, profile} -> profile
      {:error, :not_found} -> nil
    end
  end

  defp load_current_profile(nil) do
    case Profiles.list_profiles() do
      {:ok, [profile]} -> profile
      {:ok, _profiles} -> nil
    end
  end

  defp load_current_profile(_profile_id), do: nil
end
