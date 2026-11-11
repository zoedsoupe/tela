defmodule Tela.Brands do
  @moduledoc "Shared workspace brand kits."

  import Ecto.Query
  alias Tela.Brands.Kit
  alias Tela.Media
  alias Tela.Repo

  @spec create_kit(Ecto.UUID.t() | nil, map()) :: {:ok, Kit.t()} | {:error, term()}
  def create_kit(created_by_id, attrs) when is_map(attrs) do
    with {:ok, attrs} <- normalize_attrs(attrs, nil),
         :ok <- validate_logo_references(attrs) do
      transaction(fn ->
        case %Kit{created_by_id: created_by_id} |> Kit.changeset(attrs) |> Repo.insert() do
          {:ok, kit} ->
            clear_other_defaults(kit)
            kit

          {:error, changeset} ->
            Repo.rollback(changeset)
        end
      end)
    end
  end

  def create_kit(_created_by_id, _attrs), do: {:error, :invalid_input}

  @spec update_kit(Ecto.UUID.t(), map()) :: {:ok, Kit.t()} | {:error, term()}
  def update_kit(id, attrs) when is_map(attrs) do
    with {:ok, uuid} <- Ecto.UUID.cast(id),
         %Kit{} = kit <- Repo.get(Kit, uuid),
         {:ok, attrs} <- normalize_attrs(attrs, kit),
         :ok <- validate_logo_references(attrs) do
      transaction(fn ->
        case kit |> Kit.changeset(attrs) |> Repo.update() do
          {:ok, updated} ->
            clear_other_defaults(updated)
            updated

          {:error, changeset} ->
            Repo.rollback(changeset)
        end
      end)
    else
      nil -> {:error, :not_found}
      :error -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  def update_kit(_id, _attrs), do: {:error, :invalid_input}

  @spec delete_kit(Ecto.UUID.t()) :: {:ok, Kit.t()} | {:error, :not_found}
  def delete_kit(id) do
    with {:ok, uuid} <- Ecto.UUID.cast(id),
         %Kit{} = kit <- Repo.get(Kit, uuid) do
      Repo.delete(kit)
    else
      _ -> {:error, :not_found}
    end
  end

  @spec list_kits() :: {:ok, [Kit.t()]}
  def list_kits do
    kits = Repo.all(from kit in Kit, order_by: [asc: kit.name, asc: kit.id])
    {:ok, kits}
  end

  @spec to_api(Kit.t()) :: map()
  def to_api(%Kit{} = kit) do
    logos =
      case Media.list_uploads_by_ids(logo_ids(kit.logos)) do
        {:ok, uploads} -> Enum.map(uploads, &Media.to_asset/1)
        {:error, _reason} -> []
      end

    %{
      id: kit.id,
      name: kit.name,
      is_default: kit.is_default,
      colors: api_colors(kit.colors),
      fonts: api_fonts(kit.fonts),
      logos: logos,
      created_at: iso8601(kit.inserted_at),
      updated_at: iso8601(kit.updated_at)
    }
  end

  defp normalize_attrs(attrs, existing) do
    is_default =
      if has_key?(attrs, :is_default),
        do: attr(attrs, :is_default),
        else: existing_default(existing)

    colors =
      if has_key?(attrs, :colors),
        do: normalize_colors(attr(attrs, :colors)),
        else: existing && existing.colors

    fonts =
      if has_key?(attrs, :fonts),
        do: normalize_fonts(attr(attrs, :fonts)),
        else: existing && existing.fonts

    logos = normalize_logos(attrs, existing)

    {:ok,
     %{
       name: if(has_key?(attrs, :name), do: attr(attrs, :name), else: existing && existing.name),
       is_default: is_default,
       colors: colors,
       fonts: fonts,
       logos: logos
     }}
  end

  defp normalize_colors(colors) when is_list(colors) do
    case colors do
      [%{} | _] ->
        items = Enum.map(colors, &stringify_keys/1)
        values = Enum.map(items, &Map.get(&1, "hex"))
        %{"items" => items, "values" => values}

      [] ->
        %{"items" => [], "values" => []}

      _ ->
        %{"values" => colors}
    end
  end

  defp normalize_colors(colors), do: colors

  defp normalize_fonts(fonts) when is_list(fonts) do
    items = Enum.map(fonts, &stringify_keys/1)

    %{
      "items" => items,
      "heading" => font_family(items, "heading"),
      "body" => font_family(items, "body")
    }
  end

  defp normalize_fonts(fonts), do: fonts

  defp normalize_logos(attrs, existing) do
    ids =
      cond do
        has_key?(attrs, :logo_ids) -> normalize_ids(attr(attrs, :logo_ids))
        has_key?(attrs, :logos) -> normalize_ids(attr(attrs, :logos))
        existing -> logo_ids(existing.logos)
        true -> []
      end

    %{"items" => ids}
  end

  defp normalize_ids(ids) when is_list(ids) do
    Enum.map(ids, fn
      %{} = item -> attr(item, :id)
      id -> id
    end)
  end

  defp normalize_ids(_ids), do: []

  defp validate_logo_references(attrs) do
    ids = logo_ids(Map.get(attrs, :logos))

    cond do
      length(ids) > 12 ->
        {:error, :invalid_input}

      Enum.any?(ids, &(not is_binary(&1))) ->
        {:error, :invalid_asset}

      ids == [] ->
        :ok

      true ->
        with {:ok, uploads} <- Media.list_uploads_by_ids(ids),
             true <- Enum.all?(uploads, &(&1.kind in ["image", "svg"])) do
          :ok
        else
          _ -> {:error, :invalid_asset}
        end
    end
  end

  defp clear_other_defaults(%Kit{} = kit) do
    if kit.is_default do
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      from(other in Kit, where: other.id != ^kit.id and other.is_default == true)
      |> Repo.update_all(set: [is_default: false, updated_at: now])
    end
  end

  defp existing_default(%Kit{is_default: is_default}), do: is_default
  defp existing_default(nil), do: false

  defp logo_ids(%{"items" => items}) when is_list(items), do: normalize_ids(items)
  defp logo_ids(%{items: items}) when is_list(items), do: normalize_ids(items)
  defp logo_ids(_logos), do: []

  defp api_colors(%{"items" => items}) when is_list(items), do: items

  defp api_colors(%{"values" => values}) when is_list(values) do
    values
    |> Enum.with_index()
    |> Enum.map(fn {hex, index} -> %{id: "legacy-#{index}", name: hex, hex: hex} end)
  end

  defp api_colors(_colors), do: []

  defp api_fonts(%{"items" => items}) when is_list(items), do: items

  defp api_fonts(fonts) when is_map(fonts) do
    ["heading", "subheading", "body"]
    |> Enum.flat_map(fn role ->
      case Map.get(fonts, role) do
        family when is_binary(family) and family != "" -> [%{role: role, family: family}]
        _ -> []
      end
    end)
  end

  defp api_fonts(_fonts), do: []

  defp font_family(fonts, role) do
    case Enum.find(fonts, &(Map.get(&1, "role") == role)) do
      %{"family" => family} -> family
      _ -> ""
    end
  end

  defp stringify_keys(map), do: Map.new(map, fn {key, value} -> {to_string(key), value} end)

  defp has_key?(map, key), do: Map.has_key?(map, key) or Map.has_key?(map, Atom.to_string(key))

  defp attr(map, key), do: Map.get(map, key, Map.get(map, Atom.to_string(key)))

  defp iso8601(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
  defp iso8601(_datetime), do: nil

  defp transaction(fun) do
    case Repo.transaction(fun) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end
end
