defmodule TelaWeb.Components.Feedback do
  @moduledoc "Status, progress, and feedback components for user-facing system state."
  use Phoenix.Component
  alias Phoenix.LiveView.JS

  @doc "Renders one flash message. The surrounding flash group belongs in `TelaWeb.Layouts`."
  attr :id, :string, default: nil
  attr :flash, :map, default: %{}
  attr :title, :string, default: nil
  attr :kind, :atom, required: true, values: [:info, :error]
  attr :rest, :global
  slot :inner_block

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={message = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      role="alert"
      data-state="visible"
      class="fixed right-4 top-4 z-50 w-[min(24rem,calc(100vw-2rem))]"
      {@rest}
    >
      <div class={["flex gap-3 rounded-lg border bg-surface p-4 shadow-topbar", alert_variant(@kind)]}>
        <Lucideicons.info :if={@kind == :info} class="mt-0.5 size-5 shrink-0" aria-hidden="true" />
        <Lucideicons.circle_alert
          :if={@kind == :error}
          class="mt-0.5 size-5 shrink-0"
          aria-hidden="true"
        />
        <div class="min-w-0 flex-1">
          <p :if={@title} class="font-semibold">{@title}</p>
          <p class="text-sm">{message}</p>
        </div>
        <button
          type="button"
          class="-mr-1 -mt-1 inline-flex size-8 shrink-0 items-center justify-center rounded-md text-muted hover:bg-surface-secondary hover:text-ink focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus"
          aria-label="Fechar notificação"
          phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> JS.hide(to: "##{@id}")}
        >
          <Lucideicons.x class="size-4" />
        </button>
      </div>
    </div>
    """
  end

  @doc "Renders a persistent inline message with a semantic tone."
  attr :variant, :atom, default: :info, values: [:info, :success, :warning, :danger]
  attr :title, :string, default: nil
  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def alert(assigns) do
    ~H"""
    <div
      role="status"
      data-variant={@variant}
      class={["flex gap-3 rounded-lg border p-4", alert_variant(@variant), @class]}
      {@rest}
    >
      <Lucideicons.info :if={@variant == :info} class="mt-0.5 size-5 shrink-0" aria-hidden="true" />
      <Lucideicons.circle_check
        :if={@variant == :success}
        class="mt-0.5 size-5 shrink-0"
        aria-hidden="true"
      />
      <Lucideicons.triangle_alert
        :if={@variant == :warning}
        class="mt-0.5 size-5 shrink-0"
        aria-hidden="true"
      />
      <Lucideicons.circle_alert
        :if={@variant == :danger}
        class="mt-0.5 size-5 shrink-0"
        aria-hidden="true"
      />
      <div>
        <p :if={@title} class="font-semibold">{@title}</p>
        <div class="text-sm">{render_slot(@inner_block)}</div>
      </div>
    </div>
    """
  end

  @doc "Renders a compact semantic status label."
  attr :variant, :atom,
    default: :neutral,
    values: [:neutral, :accent, :success, :warning, :danger]

  attr :class, :any, default: nil
  attr :rest, :global
  slot :inner_block, required: true

  def badge(assigns) do
    ~H"""
    <span
      data-variant={@variant}
      class={[
        "inline-flex items-center rounded-full border px-2.5 py-0.5 text-xs font-medium",
        badge_variant(@variant),
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </span>
    """
  end

  @doc "Renders an indeterminate progress indicator."
  attr :label, :string, default: "Carregando"
  attr :class, :any, default: nil
  attr :rest, :global

  def spinner(assigns) do
    ~H"""
    <span
      role="status"
      aria-label={@label}
      class={["inline-flex size-5 animate-spin text-accent motion-reduce:animate-none", @class]}
      {@rest}
    >
      <Lucideicons.loader_circle class="size-full" />
      <span class="sr-only">{@label}</span>
    </span>
    """
  end

  @doc "Renders a content placeholder that is hidden from assistive technology."
  attr :class, :any, default: nil
  attr :rest, :global

  def skeleton(assigns) do
    ~H"""
    <div
      aria-hidden="true"
      class={["animate-pulse rounded-md bg-surface-secondary motion-reduce:animate-none", @class]}
      {@rest}
    />
    """
  end

  @doc "Renders accessible native determinate progress. Values are clamped to the declared maximum by the browser."
  attr :value, :integer, required: true
  attr :max, :integer, default: 100
  attr :label, :string, default: "Progresso"
  attr :class, :any, default: nil
  attr :rest, :global

  def progress(assigns) do
    ~H"""
    <div class={["space-y-1.5", @class]} {@rest}>
      <div class="flex items-center justify-between gap-3 text-xs text-muted">
        <span>{@label}</span>
        <span>{@value}%</span>
      </div>
      <progress
        class="h-2 w-full overflow-hidden rounded-full accent-accent"
        value={@value}
        max={@max}
        aria-label={@label}
      >{@value}%</progress>
    </div>
    """
  end

  @doc "Explains an empty collection and offers an optional next action."
  attr :title, :string, required: true
  attr :class, :any, default: nil
  slot :inner_block
  slot :action

  def empty_state(assigns) do
    ~H"""
    <div class={[
      "flex min-h-48 flex-col items-center justify-center rounded-lg border border-dashed border-line px-6 py-10 text-center",
      @class
    ]}>
      <Lucideicons.panels_top_left class="mb-3 size-8 text-muted" aria-hidden="true" />
      <h2 class="font-display text-xl text-ink">{@title}</h2>
      <p :if={@inner_block != []} class="mt-2 max-w-md text-sm text-muted">
        {render_slot(@inner_block)}
      </p>
      <div :if={@action != []} class="mt-5">{render_slot(@action)}</div>
    </div>
    """
  end

  @doc "Displays a concise save lifecycle state."
  attr :status, :atom, required: true, values: [:saved, :saving, :dirty, :error, :conflict]
  attr :label, :string, default: nil
  attr :class, :any, default: nil

  def save_status(assigns) do
    ~H"""
    <span
      role="status"
      data-state={@status}
      class={["inline-flex items-center gap-1.5 text-xs text-muted", @class]}
    >
      <Lucideicons.circle_check :if={@status == :saved} class="size-4 text-success" />
      <.spinner :if={@status == :saving} class="size-4" />
      <Lucideicons.circle_dot :if={@status == :dirty} class="size-4 text-warning" />
      <Lucideicons.circle_alert :if={@status == :error} class="size-4 text-danger" />
      <Lucideicons.circle_alert :if={@status == :conflict} class="size-4 text-warning" />
      {@label || status_label(@status)}
    </span>
    """
  end

  defp alert_variant(:info), do: "border-focus/30 bg-surface-secondary text-ink"
  defp alert_variant(:success), do: "border-success/30 bg-surface-secondary text-ink"
  defp alert_variant(:warning), do: "border-warning/30 bg-surface-secondary text-ink"
  defp alert_variant(:danger), do: "border-danger/30 bg-surface-secondary text-ink"
  defp alert_variant(:error), do: "border-danger/30 bg-surface-secondary text-ink"

  defp badge_variant(:neutral), do: "border-line bg-surface-secondary text-ink"
  defp badge_variant(:accent), do: "border-accent/30 bg-accent-soft text-ink"
  defp badge_variant(:success), do: "border-success/30 bg-surface-secondary text-success"
  defp badge_variant(:warning), do: "border-warning/30 bg-surface-secondary text-warning"
  defp badge_variant(:danger), do: "border-danger/30 bg-surface-secondary text-danger"

  defp status_label(:saved), do: "Salvo"
  defp status_label(:saving), do: "Salvando…"
  defp status_label(:dirty), do: "Alterações não salvas"
  defp status_label(:error), do: "Falha ao salvar"
  defp status_label(:conflict), do: "Conflito de revisão"
end
