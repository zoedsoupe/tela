defmodule Tela.Designs.Document do
  @moduledoc """
  Pure construction and validation for the versioned design document.
  """

  @max_dimension 20_000
  @max_pages 100
  @max_objects_per_page 2_000
  @easings ~w(linear ease-in ease-out ease-in-out spring)
  @directions ~w(left right up down in out)
  @slots [:enter, :emphasis, :exit]

  @spec blank(pos_integer(), pos_integer(), String.t() | nil) :: map()
  def blank(width, height, preset_id \\ nil)
      when is_integer(width) and is_integer(height) do
    %{
      "schemaVersion" => 1,
      "width" => width,
      "height" => height,
      "pages" => [
        %{
          "id" => Ecto.UUID.generate(),
          "background" => %{"type" => "solid", "color" => "#ffffff"},
          "objects" => []
        }
      ],
      "meta" => if(preset_id, do: %{"presetId" => preset_id}, else: %{})
    }
  end

  @spec validate(term()) :: {:ok, map()} | {:error, :invalid_document}
  def validate(document) when is_map(document) do
    if valid_document?(document) do
      {:ok, document}
    else
      {:error, :invalid_document}
    end
  end

  def validate(_), do: {:error, :invalid_document}

  @spec page_duration_ms(map()) :: 1_000..60_000
  def page_duration_ms(page) when is_map(page) do
    animation_end =
      page
      |> Map.get("objects", [])
      |> Enum.reduce(0, fn object, longest ->
        object
        |> Map.get("animation", %{})
        |> animation_end_ms()
        |> max(longest)
      end)

    requested =
      page |> Map.get("durationSec", 1) |> ceil() |> max(1) |> min(60) |> Kernel.*(1_000)

    max(1_000, max(animation_end, requested))
  end

  defp valid_document?(document) do
    document["schemaVersion"] == 1 and
      valid_dimension?(document["width"]) and
      valid_dimension?(document["height"]) and
      valid_pages?(document["pages"]) and
      valid_meta?(Map.get(document, "meta", %{}))
  end

  defp valid_dimension?(value), do: is_integer(value) and value > 0 and value <= @max_dimension

  defp valid_pages?(pages) when is_list(pages) and length(pages) in 1..@max_pages do
    ids = Enum.map(pages, &Map.get(&1, "id"))
    Enum.all?(pages, &valid_page?/1) and length(Enum.uniq(ids)) == length(ids)
  end

  defp valid_pages?(_), do: false

  defp valid_page?(page) when is_map(page) do
    valid_id?(page["id"]) and
      valid_background?(page["background"]) and
      valid_objects?(Map.get(page, "objects")) and
      valid_page_duration?(Map.get(page, "durationSec", 1)) and
      valid_transition?(Map.get(page, "transition"))
  end

  defp valid_page?(_), do: false

  defp valid_page_duration?(value), do: is_number(value) and value >= 1 and value <= 60

  defp valid_background?(%{"type" => "solid", "color" => color}) when is_binary(color), do: true

  defp valid_background?(%{"type" => "image", "src" => src} = background) when is_binary(src),
    do: Map.get(background, "fit", "cover") in ~w(cover contain tile)

  defp valid_background?(_), do: false

  defp valid_objects?(objects)
       when is_list(objects) and length(objects) <= @max_objects_per_page do
    Enum.all?(objects, &valid_object?/1)
  end

  defp valid_objects?(_), do: false

  defp valid_object?(object) when is_map(object) do
    valid_id?(object["id"]) and is_binary(object["type"]) and object["type"] != "" and
      valid_animation?(Map.get(object, "animation")) and
      valid_children?(Map.get(object, "objects"))
  end

  defp valid_object?(_), do: false
  defp valid_children?(nil), do: true
  defp valid_children?(children), do: valid_objects?(children)

  defp valid_animation?(nil), do: true

  defp valid_animation?(animation) when is_map(animation) do
    Enum.all?(@slots, fn slot ->
      case Map.get(animation, Atom.to_string(slot)) do
        nil -> true
        value -> valid_animation_entry?(value)
      end
    end)
  end

  defp valid_animation?(_), do: false

  defp valid_animation_entry?(animation) when is_map(animation) do
    valid_preset?(animation["preset"]) and
      valid_bounded_integer?(Map.get(animation, "durationMs", 600), 100, 10_000) and
      valid_bounded_integer?(Map.get(animation, "delayMs", 0), 0, 60_000) and
      Map.get(animation, "easing", "ease-out") in @easings and
      valid_optional_direction?(Map.get(animation, "direction")) and
      valid_intensity?(Map.get(animation, "intensity", 0.5)) and
      is_boolean(Map.get(animation, "loop", false))
  end

  defp valid_animation_entry?(_), do: false

  defp valid_transition?(nil), do: true

  defp valid_transition?(transition) when is_map(transition) do
    valid_preset?(transition["preset"]) and
      valid_bounded_integer?(Map.get(transition, "durationMs", 700), 200, 3_000) and
      Map.get(transition, "easing", "ease-in-out") in @easings and
      valid_optional_direction?(Map.get(transition, "direction"))
  end

  defp valid_transition?(_), do: false

  defp valid_preset?(preset),
    do: is_binary(preset) and Regex.match?(~r/^[a-z0-9-]{1,40}$/, preset)

  defp valid_optional_direction?(nil), do: true
  defp valid_optional_direction?(direction), do: direction in @directions
  defp valid_intensity?(value), do: is_number(value) and value >= 0 and value <= 1

  defp valid_bounded_integer?(value, min, max),
    do: is_integer(value) and value >= min and value <= max

  defp valid_id?(id), do: is_binary(id) and id != ""

  defp valid_meta?(meta) when is_map(meta) do
    Enum.all?(meta, fn
      {"presetId", value} -> is_binary(value)
      {"brandKitId", value} -> is_binary(value)
      _ -> false
    end)
  end

  defp valid_meta?(_), do: false

  defp animation_end_ms(animation) when is_map(animation) do
    Enum.reduce(@slots, 0, fn slot, longest ->
      case Map.get(animation, Atom.to_string(slot)) do
        %{"durationMs" => duration, "delayMs" => delay} = entry
        when is_integer(duration) and is_integer(delay) ->
          if slot == :emphasis and Map.get(entry, "loop", false) do
            longest
          else
            max(longest, duration + delay)
          end

        _ ->
          longest
      end
    end)
  end

  defp animation_end_ms(_), do: 0
end
