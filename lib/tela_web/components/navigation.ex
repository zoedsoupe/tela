defmodule TelaWeb.Components.Navigation do
  @moduledoc "Semantic navigation primitives with native links and keyboard behavior."
  use Phoenix.Component

  @doc "Renders a link as a navigation item and marks the current destination semantically."
  attr :current, :boolean, default: false
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(href navigate patch method id target rel)
  slot :inner_block, required: true

  def nav_item(assigns) do
    ~H"""
    <.link
      aria-current={@current && "page"}
      data-current={to_string(@current)}
      class={[
        "inline-flex min-h-10 items-center gap-2 rounded-md px-3 text-sm font-medium transition-colors duration-fast focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus",
        if(@current,
          do: "bg-surface-secondary text-ink",
          else: "text-muted hover:bg-surface-secondary hover:text-ink"
        ),
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc "Renders a tablist of links. Each tab slot accepts `label`, `href`, and `selected`."
  attr :label, :string, default: "Navegação"
  attr :class, :any, default: nil

  slot :tab, required: true do
    attr :label, :string
    attr :href, :string
    attr :selected, :boolean
  end

  def tabs(assigns) do
    ~H"""
    <nav aria-label={@label} class={@class}>
      <div role="tablist" class="flex gap-1 border-b border-line">
        <.link
          :for={tab <- @tab}
          role="tab"
          aria-selected={to_string(tab[:selected] || false)}
          aria-current={tab[:selected] && "page"}
          href={tab[:href]}
          class={[
            "-mb-px inline-flex min-h-11 items-center border-b-2 px-3 text-sm font-medium transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus",
            if(tab[:selected],
              do: "border-accent text-ink",
              else: "border-transparent text-muted hover:text-ink"
            )
          ]}
        >
          {tab[:label] || render_slot(tab)}
        </.link>
      </div>
    </nav>
    """
  end

  @doc "Renders a breadcrumb trail. Mark the final item with `current`."
  attr :label, :string, default: "Você está aqui"
  attr :class, :any, default: nil

  slot :item, required: true do
    attr :href, :string
    attr :current, :boolean
  end

  def breadcrumbs(assigns) do
    ~H"""
    <nav aria-label={@label} class={@class}>
      <ol class="flex flex-wrap items-center gap-2 text-sm">
        <li :for={{item, index} <- Enum.with_index(@item)} class="inline-flex items-center gap-2">
          <Lucideicons.chevron_right :if={index > 0} class="size-3.5 text-muted" aria-hidden="true" />
          <.link
            :if={item[:href] && !item[:current]}
            href={item[:href]}
            class="text-muted hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus"
          >
            {render_slot(item)}
          </.link>
          <span
            :if={!item[:href] || item[:current]}
            aria-current={item[:current] && "page"}
            class={if(item[:current], do: "font-medium text-ink", else: "text-muted")}
          >
            {render_slot(item)}
          </span>
        </li>
      </ol>
    </nav>
    """
  end

  @doc "Renders a compact set of mutually exclusive action choices. Send the selected value through `on_select`."
  attr :label, :string, required: true
  attr :selected, :string, required: true
  attr :on_select, :string, required: true
  attr :class, :any, default: nil

  slot :option, required: true do
    attr :value, :string, required: true
  end

  def segmented_control(assigns) do
    ~H"""
    <div
      role="group"
      aria-label={@label}
      class={["inline-flex rounded-md border border-line bg-surface-secondary p-1", @class]}
    >
      <button
        :for={option <- @option}
        type="button"
        aria-pressed={to_string(option.value == @selected)}
        data-selected={to_string(option.value == @selected)}
        phx-click={@on_select}
        phx-value-value={option.value}
        class={[
          "min-h-8 rounded px-3 text-sm transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus",
          if(option.value == @selected,
            do: "bg-surface text-ink shadow-sm",
            else: "text-muted hover:text-ink"
          )
        ]}
      >
        {render_slot(option)}
      </button>
    </div>
    """
  end

  @doc "Renders previous, numbered, and next links for a paginated collection."
  attr :current, :integer, required: true
  attr :total, :integer, required: true
  attr :page_path, :any, required: true
  attr :label, :string, default: "Paginação"

  def pagination(assigns) do
    ~H"""
    <nav aria-label={@label} class="flex items-center justify-center gap-1">
      <.link
        href={@page_path.(@current - 1)}
        aria-label="Página anterior"
        aria-disabled={to_string(@current <= 1)}
        class="inline-flex size-9 items-center justify-center rounded-md text-muted hover:bg-surface-secondary aria-disabled:pointer-events-none aria-disabled:opacity-40 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus"
      >
        <Lucideicons.chevron_left class="size-4" />
      </.link>
      <.link
        :for={page <- pagination_pages(@current, @total)}
        href={@page_path.(page)}
        aria-current={if(page == @current, do: "page", else: false)}
        class={[
          "inline-flex size-9 items-center justify-center rounded-md text-sm focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus",
          if(page == @current,
            do: "bg-accent text-on-accent",
            else: "text-muted hover:bg-surface-secondary hover:text-ink"
          )
        ]}
      >
        {page}
      </.link>
      <.link
        href={@page_path.(@current + 1)}
        aria-label="Próxima página"
        aria-disabled={to_string(@current >= @total)}
        class="inline-flex size-9 items-center justify-center rounded-md text-muted hover:bg-surface-secondary aria-disabled:pointer-events-none aria-disabled:opacity-40 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus"
      >
        <Lucideicons.chevron_right class="size-4" />
      </.link>
    </nav>
    """
  end

  defp pagination_pages(current, total) do
    first = max(current - 2, 1)
    last = min(max(current + 2, 5), total)
    Enum.to_list(first..max(last, first))
  end
end
