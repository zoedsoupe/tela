defmodule TelaWeb.Components.DataDisplay do
  @moduledoc "Headers, collections, and media primitives for displaying workspace data."
  use Phoenix.Component

  @doc "Renders a page or section heading with optional description and actions."
  attr :class, :any, default: nil
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[
      "flex flex-wrap items-start justify-between gap-5 border-b border-line pb-5",
      @class
    ]}>
      <div>
        <h1 class="font-display text-3xl leading-tight text-ink">{render_slot(@inner_block)}</h1>
        <p :if={@subtitle != []} class="mt-1.5 max-w-2xl text-sm text-muted">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div :if={@actions != []} class="flex shrink-0 flex-wrap items-center gap-2">
        {render_slot(@actions)}
      </div>
    </header>
    """
  end

  @doc "Renders a semantic HTML table. LiveStream rows automatically use stream IDs and `phx-update=stream`."
  attr :id, :string, required: true
  attr :rows, :any, required: true
  attr :row_id, :any, default: nil
  attr :row_item, :any, default: nil
  attr :class, :any, default: nil

  slot :col, required: true do
    attr :label, :string, required: true
  end

  slot :action

  def table(assigns) do
    stream? = match?(%Phoenix.LiveView.LiveStream{}, assigns.rows)

    assigns = assign(assigns, stream?: stream?)

    ~H"""
    <div class="overflow-x-auto rounded-lg border border-line">
      <table class={["w-full border-collapse text-left text-sm", @class]}>
        <thead class="bg-surface-secondary text-xs uppercase tracking-wide text-muted">
          <tr>
            <th :for={col <- @col} scope="col" class="px-4 py-3 font-medium">{col[:label]}</th>
            <th :if={@action != []} scope="col" class="px-4 py-3">
              <span class="sr-only">Ações</span>
            </th>
          </tr>
        </thead>
        <tbody
          id={@id}
          phx-update={if(@stream?, do: "stream", else: nil)}
          class="divide-y divide-line"
        >
          <tr
            :for={row <- @rows}
            id={row_dom_id(row, @row_id, @row_item, @stream?)}
            class="bg-surface transition-colors hover:bg-surface-secondary"
          >
            <td :for={col <- @col} class="px-4 py-3 text-ink">
              {render_slot(col, row_value(row, @row_item, @stream?))}
            </td>
            <td :if={@action != []} class="px-4 py-3 text-right">
              <div class="inline-flex items-center gap-2">
                <%= for action <- @action do %>
                  {render_slot(action, row_value(row, @row_item, @stream?))}
                <% end %>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  @doc "Renders a definition list from title/content slots."
  attr :class, :any, default: nil

  slot :item, required: true do
    attr :title, :string, required: true
  end

  def description_list(assigns) do
    ~H"""
    <dl class={["divide-y divide-line", @class]}>
      <div
        :for={item <- @item}
        class="grid gap-1 py-3 sm:grid-cols-[minmax(8rem,0.35fr)_1fr] sm:gap-4"
      >
        <dt class="text-sm font-medium text-muted">{item.title}</dt>
        <dd class="text-sm text-ink">{render_slot(item)}</dd>
      </div>
    </dl>
    """
  end

  @doc "Renders a simple list with a title and optional supporting content."
  attr :class, :any, default: nil

  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <ul class={["divide-y divide-line", @class]}>
      <li :for={item <- @item} class="py-3 first:pt-0 last:pb-0">
        <p class="font-medium text-ink">{item.title}</p>
        <div class="mt-1 text-sm text-muted">{render_slot(item)}</div>
      </li>
    </ul>
    """
  end

  @doc "Displays a cropped image with an accessible text alternative."
  attr :src, :string, required: true
  attr :alt, :string, required: true
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(width height loading decoding)

  def thumbnail(assigns) do
    ~H"""
    <img
      src={@src}
      alt={@alt}
      class={[
        "aspect-[4/3] w-full rounded-md border border-line bg-surface-secondary object-cover",
        @class
      ]}
      {@rest}
    />
    """
  end

  @doc "Constrains its content to an aspect ratio such as `4 / 3` or `1 / 1`."
  attr :ratio, :string, default: "1 / 1"
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def aspect_ratio(assigns) do
    ~H"""
    <div style={"aspect-ratio: #{@ratio}"} class={["overflow-hidden", @class]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  @doc "Creates a responsive grid for asset cards or thumbnails."
  attr :columns, :atom, default: :auto, values: [:auto, :two, :three, :four]
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def asset_grid(assigns) do
    ~H"""
    <div class={["grid gap-4", grid_columns(@columns), @class]}>
      {render_slot(@inner_block)}
    </div>
    """
  end

  defp row_value({_id, item}, _row_item, true), do: item
  defp row_value(row, row_item, _stream?) when is_function(row_item, 1), do: row_item.(row)
  defp row_value(row, _row_item, _stream?), do: row

  defp row_dom_id({dom_id, _item}, nil, _row_item, true), do: dom_id

  defp row_dom_id(row, row_id, row_item, stream?) when is_function(row_id, 1),
    do: row_id.(row_value(row, row_item, stream?))

  defp row_dom_id(_row, _row_id, _row_item, _stream?), do: nil

  defp grid_columns(:auto), do: "grid-cols-[repeat(auto-fill,minmax(min(100%,12rem),1fr))]"
  defp grid_columns(:two), do: "grid-cols-1 sm:grid-cols-2"
  defp grid_columns(:three), do: "grid-cols-1 sm:grid-cols-2 lg:grid-cols-3"
  defp grid_columns(:four), do: "grid-cols-2 sm:grid-cols-3 lg:grid-cols-4"
end
