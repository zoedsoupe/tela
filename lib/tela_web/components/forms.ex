defmodule TelaWeb.Components.Forms do
  @moduledoc "Accessible native form controls styled with Tela semantic tokens."
  use Phoenix.Component

  @doc "Renders a native input, textarea, select, checkbox, radio, or switch with an associated label and messages."
  attr :id, :any, default: nil
  attr :name, :any, default: nil
  attr :label, :string, default: nil
  attr :hint, :string, default: nil
  attr :value, :any, default: nil
  attr :type, :string, default: "text"
  attr :field, Phoenix.HTML.FormField, default: nil
  attr :errors, :list, default: []
  attr :checked, :boolean, default: nil
  attr :prompt, :string, default: nil
  attr :options, :list, default: []
  attr :multiple, :boolean, default: false
  attr :class, :any, default: nil

  attr :rest, :global,
    include:
      ~w(accept autocomplete capture cols disabled form list max maxlength min minlength multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error/1))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{id: nil, name: name} = assigns) when is_binary(name) do
    assigns
    |> assign(:id, name)
    |> input()
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns = assign(assigns, :checked, checked_value(assigns.checked, assigns.value))

    ~H"""
    <div class="space-y-1.5">
      <label for={@id} class="flex cursor-pointer items-center gap-2 text-sm text-ink">
        <input
          type="hidden"
          name={@name}
          value="false"
          disabled={@rest[:disabled]}
          form={@rest[:form]}
        />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class={[
            "size-4 accent-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus",
            @class
          ]}
          aria-invalid={to_string(@errors != [])}
          aria-describedby={described_by(@id, @hint, @errors)}
          {@rest}
        />
        <span :if={@label}>{@label}</span>
      </label>
      <.hint :if={@hint} id={"#{@id}-hint"}>{@hint}</.hint>
      <.error :if={@errors != []} id={"#{@id}-error"} messages={@errors} />
    </div>
    """
  end

  def input(%{type: "radio"} = assigns) do
    ~H"""
    <div class="space-y-1.5">
      <label for={@id} class="flex cursor-pointer items-center gap-2 text-sm text-ink">
        <input
          type="radio"
          id={@id}
          name={@name}
          value={@value}
          checked={@checked}
          class={[
            "size-4 accent-accent focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-focus",
            @class
          ]}
          aria-invalid={to_string(@errors != [])}
          aria-describedby={described_by(@id, @hint, @errors)}
          {@rest}
        />
        <span :if={@label}>{@label}</span>
      </label>
      <.hint :if={@hint} id={"#{@id}-hint"}>{@hint}</.hint>
      <.error :if={@errors != []} id={"#{@id}-error"} messages={@errors} />
    </div>
    """
  end

  def input(%{type: "switch"} = assigns) do
    assigns = assign(assigns, :checked, checked_value(assigns.checked, assigns.value))

    ~H"""
    <div class="space-y-1.5">
      <label for={@id} class="flex cursor-pointer items-center gap-3 text-sm text-ink">
        <input
          type="hidden"
          name={@name}
          value="false"
          disabled={@rest[:disabled]}
          form={@rest[:form]}
        />
        <input
          type="checkbox"
          role="switch"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class={["peer sr-only", @class]}
          aria-invalid={to_string(@errors != [])}
          aria-describedby={described_by(@id, @hint, @errors)}
          {@rest}
        />
        <span
          aria-hidden="true"
          class="relative h-6 w-11 rounded-full bg-line transition-colors after:absolute after:left-1 after:top-1 after:size-4 after:rounded-full after:bg-surface after:transition-transform peer-checked:bg-accent peer-checked:after:translate-x-5 peer-focus-visible:ring-2 peer-focus-visible:ring-focus peer-disabled:opacity-50"
        />
        <span :if={@label}>{@label}</span>
      </label>
      <.hint :if={@hint} id={"#{@id}-hint"}>{@hint}</.hint>
      <.error :if={@errors != []} id={"#{@id}-error"} messages={@errors} />
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="space-y-1.5">
      <.input_label id={@id} label={@label} />
      <select
        id={@id}
        name={@name}
        class={[control_classes(), @class]}
        multiple={@multiple}
        aria-invalid={to_string(@errors != [])}
        aria-describedby={described_by(@id, @hint, @errors)}
        {@rest}
      >
        <option :if={@prompt} value="">{@prompt}</option>
        {Phoenix.HTML.Form.options_for_select(@options, @value)}
      </select>
      <.hint :if={@hint} id={"#{@id}-hint"}>{@hint}</.hint>
      <.error :if={@errors != []} id={"#{@id}-error"} messages={@errors} />
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="space-y-1.5">
      <.input_label id={@id} label={@label} />
      <textarea
        id={@id}
        name={@name}
        class={[control_classes(), "min-h-24", @class]}
        aria-invalid={to_string(@errors != [])}
        aria-describedby={described_by(@id, @hint, @errors)}
        {@rest}
      >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      <.hint :if={@hint} id={"#{@id}-hint"}>{@hint}</.hint>
      <.error :if={@errors != []} id={"#{@id}-error"} messages={@errors} />
    </div>
    """
  end

  def input(assigns) do
    ~H"""
    <div class="space-y-1.5">
      <.input_label id={@id} label={@label} />
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[control_classes(), @class]}
        aria-invalid={to_string(@errors != [])}
        aria-describedby={described_by(@id, @hint, @errors)}
        {@rest}
      />
      <.hint :if={@hint} id={"#{@id}-hint"}>{@hint}</.hint>
      <.error :if={@errors != []} id={"#{@id}-error"} messages={@errors} />
    </div>
    """
  end

  @doc "Renders a standalone associated label."
  attr :for, :string, required: true
  attr :required, :boolean, default: false
  slot :inner_block, required: true

  def label(assigns) do
    ~H"""
    <label for={@for} class="block text-sm font-medium text-ink">
      {render_slot(@inner_block)}
      <span :if={@required} aria-hidden="true" class="text-danger">*</span>
      <span :if={@required} class="sr-only"> (obrigatório)</span>
    </label>
    """
  end

  @doc "Renders short supporting text for a control."
  attr :id, :string, required: true
  slot :inner_block, required: true

  def hint(assigns) do
    ~H"""
    <p id={@id} class="text-xs text-muted">{render_slot(@inner_block)}</p>
    """
  end

  @doc "Renders one or more validation messages."
  attr :id, :string, required: true
  attr :messages, :list, required: true

  def error(assigns) do
    ~H"""
    <p id={@id} class="flex items-start gap-1.5 text-sm text-danger" role="alert">
      <Lucideicons.circle_alert class="mt-0.5 size-4 shrink-0" />
      <span :for={message <- @messages}>{message}</span>
    </p>
    """
  end

  @doc "Groups a native control with optional leading and trailing content."
  attr :class, :any, default: nil
  attr :rest, :global
  slot :leading
  slot :inner_block, required: true
  slot :trailing

  def input_group(assigns) do
    ~H"""
    <div class={["flex min-w-0 items-stretch", @class]} {@rest}>
      <span
        :if={@leading != []}
        class="inline-flex items-center rounded-l-md border border-r-0 border-line bg-surface-secondary px-3 text-sm text-muted"
      >
        {render_slot(@leading)}
      </span>
      {render_slot(@inner_block)}
      <span
        :if={@trailing != []}
        class="inline-flex items-center rounded-r-md border border-l-0 border-line bg-surface-secondary px-3 text-sm text-muted"
      >
        {render_slot(@trailing)}
      </span>
    </div>
    """
  end

  defp input_label(assigns) do
    ~H"""
    <label :if={@label} for={@id} class="block text-sm font-medium text-ink">{@label}</label>
    """
  end

  defp control_classes do
    "block min-h-10 w-full rounded-md border border-line bg-surface px-3 py-2 text-sm text-ink outline-none transition-colors placeholder:text-muted hover:border-line-strong focus:border-focus focus:ring-2 focus:ring-focus/25 aria-invalid:border-danger disabled:cursor-not-allowed disabled:opacity-50"
  end

  defp described_by(id, hint, errors) do
    [hint && "#{id}-hint", errors != [] && "#{id}-error"]
    |> Enum.filter(& &1)
    |> Enum.join(" ")
    |> case do
      "" -> nil
      value -> value
    end
  end

  defp translate_error({message, options}) do
    Enum.reduce(options, message, fn {key, value}, text ->
      String.replace(text, "%{#{key}}", to_string(value))
    end)
  end

  defp checked_value(nil, value), do: Phoenix.HTML.Form.normalize_value("checkbox", value)
  defp checked_value(checked, _value), do: checked
end
