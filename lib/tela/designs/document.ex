defmodule Tela.Designs.Document do
  @moduledoc "Envelope and size validation for Doory design documents."

  @max_dimension 20_000
  @max_pages 100
  @max_objects_per_page 5_000
  @max_object_depth 64
  @max_json_depth 64
  @max_document_bytes 12 * 1_024 * 1_024

  @spec blank(pos_integer(), pos_integer(), String.t() | nil) :: map()
  def blank(width, height, preset_id \\ nil)
      when is_integer(width) and is_integer(height) do
    %{
      "schemaVersion" => 1,
      "width" => width,
      "height" => height,
      "unit" => "px",
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

  @spec validate(term()) :: {:ok, map()} | {:error, :invalid_document | :document_too_large}
  def validate(document) when is_map(document) do
    case serialized_size(document) do
      {:ok, encoded_size} when encoded_size > @max_document_bytes ->
        {:error, :document_too_large}

      {:ok, _encoded_size} ->
        if valid_document?(document), do: {:ok, document}, else: {:error, :invalid_document}

      {:error, :invalid_document} ->
        {:error, :invalid_document}
    end
  end

  def validate(_), do: {:error, :invalid_document}

  @spec page_duration_ms(map()) :: 1_000..600_000
  def page_duration_ms(page) when is_map(page) do
    requested =
      case Map.get(page, "durationSec", 1) do
        duration when is_number(duration) and duration >= 1 and duration <= 600 ->
          duration |> ceil() |> Kernel.*(1_000)

        _ ->
          1_000
      end

    animation_end =
      page
      |> Map.get("objects", [])
      |> Enum.reduce(0, fn object, longest ->
        object
        |> Map.get("animation", %{})
        |> animation_end_ms()
        |> max(longest)
      end)

    max(requested, animation_end) |> min(600_000) |> max(1_000)
  end

  defp valid_document?(document) do
    document["schemaVersion"] == 1 and
      valid_dimension?(document["width"]) and
      valid_dimension?(document["height"]) and
      document["unit"] in ["px", "mm", "in"] and
      valid_pages?(document["pages"]) and
      valid_audio_tracks?(Map.get(document, "audioTracks"), document["pages"]) and
      valid_meta?(Map.get(document, "meta"))
  end

  defp serialized_size(document) do
    if valid_json_value?(document) do
      {:ok, document |> JSON.encode!() |> byte_size()}
    else
      {:error, :invalid_document}
    end
  end

  defp valid_json_value?(value) when is_binary(value), do: String.valid?(value)

  defp valid_json_value?(value) when is_integer(value) or is_boolean(value) or is_nil(value),
    do: true

  defp valid_json_value?(value) when is_float(value), do: value == value

  defp valid_json_value?(value), do: walk_json([{value, 0}])

  defp walk_json([]), do: true

  defp walk_json([{_value, depth} | _rest]) when depth > @max_json_depth, do: false

  defp walk_json([{value, _depth} | rest]) when is_binary(value),
    do: String.valid?(value) and walk_json(rest)

  defp walk_json([{value, _depth} | rest])
       when is_integer(value) or is_boolean(value) or is_nil(value),
       do: walk_json(rest)

  defp walk_json([{value, _depth} | rest]) when is_float(value),
    do: value == value and walk_json(rest)

  defp walk_json([{values, depth} | rest]) when is_list(values) do
    pending = Enum.reduce(values, rest, fn item, acc -> [{item, depth + 1} | acc] end)
    walk_json(pending)
  end

  defp walk_json([{value, depth} | rest]) when is_map(value) do
    if Enum.all?(Map.keys(value), &(is_binary(&1) and String.valid?(&1))) do
      pending =
        Enum.reduce(Map.values(value), rest, fn item, acc -> [{item, depth + 1} | acc] end)

      walk_json(pending)
    else
      false
    end
  end

  defp walk_json(_), do: false

  defp valid_dimension?(value), do: is_integer(value) and value in 1..@max_dimension

  defp valid_pages?(pages) when is_list(pages) and length(pages) in 1..@max_pages do
    Enum.reduce_while(pages, MapSet.new(), fn page, seen_ids ->
      with true <- valid_page?(page),
           id when is_binary(id) <- Map.get(page, "id"),
           false <- MapSet.member?(seen_ids, id) do
        {:cont, MapSet.put(seen_ids, id)}
      else
        _ -> {:halt, :invalid}
      end
    end) != :invalid
  end

  defp valid_pages?(_), do: false

  defp valid_page?(page) when is_map(page) do
    valid_id?(Map.get(page, "id")) and
      valid_page_dimensions?(page) and
      valid_background?(Map.get(page, "background")) and
      valid_objects?(Map.get(page, "objects"))
  end

  defp valid_page?(_), do: false

  defp valid_page_dimensions?(page) do
    valid_optional_dimension?(page, "width") and valid_optional_dimension?(page, "height")
  end

  defp valid_optional_dimension?(page, key) do
    case Map.fetch(page, key) do
      :error -> true
      {:ok, value} -> valid_dimension?(value)
    end
  end

  defp valid_background?(%{"type" => type}) when type in ["solid", "gradient", "image"], do: true
  defp valid_background?(_), do: false

  defp valid_objects?(objects)
       when is_list(objects) and length(objects) <= @max_objects_per_page do
    walk_objects(Enum.map(objects, &{&1, 1}), MapSet.new(), 0)
  end

  defp valid_objects?(_), do: false

  defp walk_objects([], _ids, _count), do: true

  defp walk_objects([{object, depth} | pending], ids, count) when is_map(object) do
    id = Map.get(object, "id")
    type = Map.get(object, "type")
    children = Map.get(object, "objects")

    if valid_id?(id) and is_binary(type) and String.trim(type) != "" and
         not MapSet.member?(ids, id) and depth <= @max_object_depth and
         (is_nil(children) or is_list(children)) do
      children = if is_list(children), do: Enum.map(children, &{&1, depth + 1}), else: []
      walk_objects(children ++ pending, MapSet.put(ids, id), count + 1)
    else
      false
    end
  end

  defp walk_objects([_ | _], _ids, _count), do: false

  defp valid_audio_tracks?(nil, _pages), do: true

  defp valid_audio_tracks?(tracks, pages) when is_list(tracks) and length(tracks) <= 32 do
    page_ids = MapSet.new(pages, &Map.get(&1, "id"))

    Enum.reduce_while(tracks, MapSet.new(), fn track, seen_ids ->
      id = if is_map(track), do: Map.get(track, "id")
      scope = if is_map(track), do: Map.get(track, "scope")
      scope_type = if is_map(scope), do: Map.get(scope, "type")
      page_id = if is_map(scope), do: Map.get(scope, "pageId")

      valid_scope =
        scope_type == "design" or
          (scope_type == "page" and MapSet.member?(page_ids, page_id))

      if valid_id?(id) and not MapSet.member?(seen_ids, id) and valid_scope do
        {:cont, MapSet.put(seen_ids, id)}
      else
        {:halt, :invalid}
      end
    end) != :invalid
  end

  defp valid_audio_tracks?(_, _pages), do: false

  defp valid_meta?(nil), do: true
  defp valid_meta?(meta), do: is_map(meta)

  defp valid_id?(id),
    do: is_binary(id) and byte_size(id) <= 128 and String.trim(id) != ""

  defp animation_end_ms(animation) when is_map(animation) do
    Enum.reduce(["enter", "exit", "emphasis"], 0, fn slot, longest ->
      case Map.get(animation, slot) do
        %{"durationMs" => duration, "delayMs" => delay} = entry
        when is_integer(duration) and is_integer(delay) ->
          if slot == "emphasis" and Map.get(entry, "loop", false) do
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
