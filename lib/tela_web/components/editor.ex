defmodule TelaWeb.Components.Editor do
  @moduledoc "Small semantic building blocks for the editor workspace."
  use Phoenix.Component

  @doc "A compact tool button with a required accessible label and icon slot."
  attr :label, :string, required: true
  attr :event, :string, required: true
  attr :value, :string, default: nil
  attr :selected, :boolean, default: false
  attr :rest, :global, include: ~w(id disabled)
  slot :icon, required: true

  def tool_button(assigns) do
    ~H"""
    <button
      type="button"
      aria-label={@label}
      title={@label}
      phx-click={@event}
      phx-value-action={@value}
      data-selected={to_string(@selected)}
      class="inline-flex min-h-9 items-center justify-center gap-2 rounded-md border border-line bg-surface px-2.5 text-sm text-ink transition-colors hover:bg-surface-secondary focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus data-[selected=true]:border-focus data-[selected=true]:bg-surface-secondary"
      {@rest}
    >
      {render_slot(@icon)}
      <span class="sr-only">{@label}</span>
    </button>
    """
  end

  @doc "A semantic panel with a heading and optional actions."
  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :class, :any, default: nil
  slot :actions
  slot :inner_block, required: true

  def panel(assigns) do
    ~H"""
    <section id={@id} aria-labelledby={"#{@id}-heading"} class={["border-b border-line", @class]}>
      <header class="flex items-center justify-between gap-3 px-4 py-3">
        <h2 id={"#{@id}-heading"} class="text-xs font-semibold uppercase tracking-wide text-muted">
          {@title}
        </h2>
        <div :if={@actions != []} class="flex items-center gap-1">{render_slot(@actions)}</div>
      </header>
      <div class="px-4 pb-4">{render_slot(@inner_block)}</div>
    </section>
    """
  end

  @doc "A page tab for the editor page strip."
  attr :id, :string, required: true
  attr :name, :string, required: true
  attr :selected, :boolean, default: false
  attr :index, :integer, required: true

  def page_tab(assigns) do
    ~H"""
    <button
      id={@id}
      type="button"
      role="tab"
      aria-selected={to_string(@selected)}
      phx-click="canvas:page_action"
      phx-value-action="select"
      phx-value-page-id={@id |> String.replace_prefix("page-tab-", "")}
      class={[
        "group flex min-w-28 items-center gap-2 rounded-md border px-2 py-1.5 text-left transition-colors focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus",
        if(@selected,
          do: "border-focus bg-surface text-ink",
          else: "border-line bg-page text-muted hover:bg-surface-secondary"
        )
      ]}
    >
      <span class="grid size-8 shrink-0 place-items-center rounded border border-line bg-surface-secondary text-xs font-medium text-muted">
        {@index}
      </span>
      <span class="truncate text-xs font-medium">{@name}</span>
    </button>
    """
  end

  @doc "A layer row with explicit selection and visibility/lock affordances."
  attr :id, :string, required: true
  attr :object_id, :string, required: true
  attr :name, :string, required: true
  attr :type, :string, required: true
  attr :selected, :boolean, default: false
  attr :visible, :boolean, default: true
  attr :locked, :boolean, default: false

  def layer_row(assigns) do
    ~H"""
    <li
      id={@id}
      class="flex min-w-0 items-center gap-1 rounded-md border border-transparent px-1 py-1 hover:border-line hover:bg-surface-secondary"
    >
      <button
        type="button"
        class="min-w-0 flex-1 truncate rounded px-2 py-1 text-left text-xs focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus"
        aria-pressed={to_string(@selected)}
        phx-click="canvas:layer_action"
        phx-value-action="select"
        phx-value-object-id={@object_id}
      >
        <span class="mr-2 text-muted">{@type}</span>{@name}
      </button>
      <button
        type="button"
        class="grid size-7 place-items-center rounded text-muted hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus"
        aria-label={if @visible, do: "Ocultar camada", else: "Mostrar camada"}
        phx-click="canvas:layer_action"
        phx-value-action="toggle_visible"
        phx-value-object-id={@object_id}
      >
        <Lucideicons.eye :if={@visible} class="size-3.5" />
        <Lucideicons.eye_off :if={!@visible} class="size-3.5" />
      </button>
      <button
        type="button"
        class="grid size-7 place-items-center rounded text-muted hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus"
        aria-label={if @locked, do: "Desbloquear camada", else: "Bloquear camada"}
        phx-click="canvas:layer_action"
        phx-value-action="toggle_lock"
        phx-value-object-id={@object_id}
      >
        <Lucideicons.lock_keyhole :if={@locked} class="size-3.5" />
        <Lucideicons.lock_keyhole_open :if={!@locked} class="size-3.5" />
      </button>
    </li>
    """
  end
end
