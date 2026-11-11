defmodule TelaWeb.Components.Actions do
  @moduledoc "Buttons and action groups built on semantic design tokens."
  use Phoenix.Component

  attr :variant, :atom,
    default: :primary,
    values: [:primary, :secondary, :outline, :ghost, :danger]

  attr :size, :atom, default: :md, values: [:sm, :md, :lg]
  attr :loading, :boolean, default: false
  attr :type, :string, default: "button", values: ["button", "submit", "reset"]
  attr :class, :any, default: nil
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled id)
  slot :inner_block, required: true

  def button(assigns) do
    ~H"""
    <.link
      :if={@rest[:href] || @rest[:navigate] || @rest[:patch]}
      class={classes(@variant, @size, @class)}
      data-variant={@variant}
      data-size={@size}
      aria-busy={to_string(@loading)}
      {@rest}
    >
      <Lucideicons.loader_circle :if={@loading} class="size-4 animate-spin" />
      {render_slot(@inner_block)}
    </.link>
    <button
      :if={!(@rest[:href] || @rest[:navigate] || @rest[:patch])}
      type={@type}
      class={classes(@variant, @size, @class)}
      data-variant={@variant}
      data-size={@size}
      aria-busy={to_string(@loading)}
      disabled={@loading || @rest[:disabled]}
      {@rest}
    >
      <Lucideicons.loader_circle :if={@loading} class="size-4 animate-spin" />
      {render_slot(@inner_block)}
    </button>
    """
  end

  defp classes(variant, size, class) do
    [
      "inline-flex shrink-0 cursor-pointer items-center justify-center gap-2 rounded-md border font-semibold transition-colors duration-fast focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus focus-visible:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50",
      variant_classes(variant),
      size_classes(size),
      class
    ]
  end

  defp variant_classes(:primary),
    do: "border-transparent bg-accent text-on-accent hover:bg-accent-hover"

  defp variant_classes(:secondary),
    do: "border-line bg-surface-secondary text-ink hover:border-line-strong"

  defp variant_classes(:outline), do: "border-line bg-surface text-ink hover:bg-surface-secondary"

  defp variant_classes(:ghost),
    do: "border-transparent bg-transparent text-ink hover:bg-surface-secondary"

  defp variant_classes(:danger), do: "border-transparent bg-danger text-on-accent"

  defp size_classes(:sm), do: "min-h-8 px-3 text-xs"
  defp size_classes(:md), do: "min-h-10 px-4 text-sm"
  defp size_classes(:lg), do: "min-h-12 px-5 text-base"
end
