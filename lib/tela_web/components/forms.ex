defmodule TelaWeb.Components.Forms do
  @moduledoc "Accessible form controls driven by Phoenix FormField and semantic tokens."
  use Phoenix.Component

  attr :id, :any, default: nil
  attr :name, :any, default: nil
  attr :label, :string, default: nil
  attr :hint, :string, default: nil
  attr :value, :any, default: nil
  attr :type, :string, default: "text"
  attr :field, Phoenix.HTML.FormField, default: nil
  attr :errors, :list, default: []
  attr :checked, :boolean, default: false
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

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input type="hidden" id={@id} name={@name} value={@value} {@rest} />
    """
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns.value)
      end)

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
          class={["size-4 accent-accent", @class]}
          aria-invalid={to_string(@errors != [])}
          aria-describedby={@errors != [] && "#{@id}-error"}
          {@rest}
        />
        <span :if={@label}>{@label}</span>
      </label>
      <.error :for={message <- @errors} id={"#{@id}-error"}>{message}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="space-y-1.5">
      <.label id={@id} label={@label} />
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
      <.error :for={message <- @errors} id={"#{@id}-error"}>{message}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="space-y-1.5">
      <.label id={@id} label={@label} />
      <textarea
        id={@id}
        name={@name}
        class={[control_classes(), "min-h-24", @class]}
        aria-invalid={to_string(@errors != [])}
        aria-describedby={described_by(@id, @hint, @errors)}
        {@rest}
      >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      <.hint :if={@hint} id={"#{@id}-hint"}>{@hint}</.hint>
      <.error :for={message <- @errors} id={"#{@id}-error"}>{message}</.error>
    </div>
    """
  end

  def input(assigns) do
    ~H"""
    <div class="space-y-1.5">
      <.label id={@id} label={@label} />
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
      <.error :for={message <- @errors} id={"#{@id}-error"}>{message}</.error>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, default: nil

  defp label(assigns) do
    ~H"""
    <label :if={@label} for={@id} class="block text-sm font-medium text-ink">{@label}</label>
    """
  end

  attr :id, :string, required: true
  slot :inner_block, required: true

  defp hint(assigns) do
    ~H"""
    <p id={@id} class="text-xs text-muted">{render_slot(@inner_block)}</p>
    """
  end

  attr :id, :string, required: true
  slot :inner_block, required: true

  defp error(assigns) do
    ~H"""
    <p id={@id} class="flex items-center gap-1.5 text-sm text-danger">
      <Lucideicons.circle_alert class="size-4 shrink-0" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  defp control_classes do
    "block min-h-10 w-full rounded-md border-line bg-surface px-3 py-2 text-sm text-ink shadow-none outline-none transition-colors placeholder:text-muted hover:border-line-strong focus:border-focus focus:ring-2 focus:ring-focus/25 aria-invalid:border-danger disabled:cursor-not-allowed disabled:opacity-50"
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
end
