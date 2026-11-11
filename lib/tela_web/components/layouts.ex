defmodule TelaWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use TelaWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="min-h-screen bg-page text-ink" data-workspace-shell>
      <header class="sticky top-0 z-40 border-b border-line bg-surface/95 shadow-topbar backdrop-blur">
        <div class="mx-auto flex min-h-16 max-w-screen-2xl items-center justify-between gap-5 px-4 sm:px-8">
          <.link
            href="/"
            class="group inline-flex items-center gap-3 rounded-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus"
          >
            <span class="relative grid size-9 place-items-center rounded-md bg-accent text-on-accent transition-transform duration-fast group-hover:-rotate-3">
              <Lucideicons.panels_top_left class="size-5" />
            </span>
            <span class="leading-tight">
              <span class="block font-display text-2xl leading-none">tela</span>
              <span class="mt-1 block text-[0.65rem] font-medium uppercase tracking-[0.16em] text-muted">atelier visual</span>
            </span>
          </.link>

          <nav aria-label="Navegação do espaço" class="hidden items-center gap-1 sm:flex">
            <.nav_item href="/" current={true}>Projetos</.nav_item>
            <.nav_item href="/">Modelos</.nav_item>
            <.nav_item href="/brand-kits">Identidade visual</.nav_item>
          </nav>

          <div class="flex items-center gap-2">
            <span class="hidden text-xs text-muted md:inline">Seu espaço criativo</span>
            <.button href="/" size={:sm}>
              <Lucideicons.plus class="size-4" />
              <span>Novo projeto</span>
            </.button>
          </div>
        </div>
        <nav
          aria-label="Navegação compacta"
          class="flex gap-1 overflow-x-auto border-t border-line px-4 py-2 sm:hidden"
        >
          <.nav_item href="/" current={true}>Projetos</.nav_item>
          <.nav_item href="/">Modelos</.nav_item>
          <.nav_item href="/brand-kits">Identidade visual</.nav_item>
        </nav>
      </header>

      <main id="main-content" class="mx-auto w-full max-w-screen-2xl px-4 py-8 sm:px-8 sm:py-12">
        {render_slot(@inner_block)}
      </main>

      <footer class="border-t border-line bg-surface px-4 py-4 text-center text-xs text-muted sm:px-8">
        <a
          href="https://github.com/shaongitbd/doory"
          target="_blank"
          rel="noopener noreferrer"
          class="hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus"
        >
          Doory by Siam, creator and maintainer of Doory, https://github.com/shaongitbd/doory
        </a>
      </footer>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite" role="complementary" aria-label="Notificações">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title="Sem conexão com a internet"
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Tentando reconectar
        <Lucideicons.loader_circle class="ml-1 inline size-3 animate-spin motion-reduce:animate-none" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title="Algo deu errado"
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Tentando reconectar
        <Lucideicons.loader_circle class="ml-1 inline size-3 animate-spin motion-reduce:animate-none" />
      </.flash>
    </div>
    """
  end
end
