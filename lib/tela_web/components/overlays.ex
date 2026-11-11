defmodule TelaWeb.Components.Overlays do
  @moduledoc "Native dialogs and disclosure-based overlays with accessible labels and controls."
  use Phoenix.Component

  @doc "Renders a native dialog element. Use `open` to display it and a form with `method=dialog` to close it."
  attr :id, :string, required: true
  attr :open, :boolean, default: false
  attr :labelledby, :string, required: true
  attr :on_close, :string, default: nil
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true
  slot :title, required: true
  slot :description
  slot :actions

  def dialog(assigns) do
    ~H"""
    <dialog
      id={@id}
      data-open={to_string(@open)}
      data-close-event={@on_close}
      phx-hook="NativeDialog"
      aria-labelledby={@labelledby}
      aria-modal={if(@open, do: "true", else: nil)}
      class={[
        "m-auto w-[min(36rem,calc(100vw-2rem))] rounded-xl border border-line bg-surface p-0 text-ink shadow-artboard backdrop:bg-ink/40",
        @class
      ]}
      {@rest}
    >
      <div class="border-b border-line px-6 py-5">
        <h2 id={@labelledby} class="font-display text-2xl">{render_slot(@title)}</h2>
        <p :if={@description != []} class="mt-1 text-sm text-muted">{render_slot(@description)}</p>
      </div>
      <div class="px-6 py-5">{render_slot(@inner_block)}</div>
      <form
        :if={@actions != []}
        method="dialog"
        class="flex justify-end gap-2 border-t border-line px-6 py-4"
      >
        {render_slot(@actions)}
      </form>
    </dialog>
    """
  end

  @doc "Renders a side drawer using the native dialog element."
  attr :id, :string, required: true
  attr :open, :boolean, default: false
  attr :labelledby, :string, required: true
  attr :on_close, :string, default: nil
  attr :side, :atom, default: :right, values: [:left, :right]
  attr :class, :any, default: nil
  slot :inner_block, required: true
  slot :title, required: true
  slot :actions

  def drawer(assigns) do
    ~H"""
    <dialog
      id={@id}
      data-open={to_string(@open)}
      data-close-event={@on_close}
      phx-hook="NativeDialog"
      aria-labelledby={@labelledby}
      aria-modal={if(@open, do: "true", else: nil)}
      class={[
        "fixed inset-y-0 m-0 h-full max-h-none w-[min(28rem,calc(100vw-1rem))] border-0 bg-surface p-0 text-ink shadow-artboard backdrop:bg-ink/40",
        if(@side == :left, do: "left-0 border-r border-line", else: "right-0 border-l border-line"),
        @class
      ]}
    >
      <div class="flex h-full flex-col">
        <header class="border-b border-line px-6 py-5">
          <h2 id={@labelledby} class="font-display text-2xl">{render_slot(@title)}</h2>
        </header>
        <div class="min-h-0 flex-1 overflow-y-auto px-6 py-5">{render_slot(@inner_block)}</div>
        <footer :if={@actions != []} class="border-t border-line px-6 py-4">
          <form method="dialog" class="flex justify-end gap-2">{render_slot(@actions)}</form>
        </footer>
      </div>
    </dialog>
    """
  end

  @doc "Renders a native disclosure menu. The trigger is a keyboard-operable summary element."
  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :class, :any, default: nil
  slot :trigger, required: true
  slot :inner_block, required: true

  def dropdown(assigns) do
    ~H"""
    <details id={@id} class={["group relative inline-block", @class]}>
      <summary aria-label={@label} class="list-none [&::-webkit-details-marker]:hidden">
        {render_slot(@trigger)}
      </summary>
      <div
        role="region"
        aria-label={@label}
        class="absolute right-0 z-30 mt-2 min-w-48 rounded-lg border border-line bg-surface p-1 shadow-artboard"
      >
        {render_slot(@inner_block)}
      </div>
    </details>
    """
  end

  @doc "Renders a labelled disclosure list of native links and buttons for keyboard-friendly actions."
  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :class, :any, default: nil
  slot :trigger, required: true
  slot :inner_block, required: true

  def menu(assigns) do
    ~H"""
    <details id={@id} class={["group relative inline-block", @class]}>
      <summary aria-label={@label} class="list-none [&::-webkit-details-marker]:hidden">
        {render_slot(@trigger)}
      </summary>
      <div
        role="group"
        aria-label={@label}
        class="absolute right-0 z-30 mt-2 min-w-48 rounded-lg border border-line bg-surface p-1 shadow-artboard"
      >
        {render_slot(@inner_block)}
      </div>
    </details>
    """
  end

  @doc "Renders a disclosure popover. Native details behavior supports keyboard and touch interaction."
  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :placement, :atom, default: :bottom, values: [:bottom, :top]
  attr :class, :any, default: nil
  slot :trigger, required: true
  slot :inner_block, required: true

  def popover(assigns) do
    ~H"""
    <details id={@id} class={["group relative inline-block", @class]}>
      <summary aria-label={@label} class="list-none [&::-webkit-details-marker]:hidden">
        {render_slot(@trigger)}
      </summary>
      <div
        role="region"
        aria-label={@label}
        class={[
          "absolute z-30 min-w-56 rounded-lg border border-line bg-surface p-4 shadow-artboard",
          if(@placement == :top, do: "bottom-full mb-2", else: "top-full mt-2")
        ]}
      >
        {render_slot(@inner_block)}
      </div>
    </details>
    """
  end

  @doc "Adds a non-interactive browser tooltip to an element. Do not place interactive content inside."
  attr :label, :string, required: true
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def tooltip(assigns) do
    ~H"""
    <span title={@label} class={@class}>{render_slot(@inner_block)}</span>
    """
  end
end
