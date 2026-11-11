defmodule Tela.Catalog do
  @moduledoc "Accent-insensitive search over the local asset catalog."

  alias Tela.Catalog.Asset
  alias Tela.Repo

  @default_limit 30
  @max_limit 100

  @spec search(binary(), map()) :: {:ok, [Asset.t()]} | {:error, term()}
  def search(query, filters \\ %{})

  def search(query, filters) when is_binary(query) and is_map(filters) do
    case fts_query(query) do
      "" -> {:ok, []}
      match_query -> search_assets(match_query, filters)
    end
  end

  def search(_query, _filters), do: {:error, :invalid_search}

  defp search_assets(match_query, filters) do
    type = filter(filters, :type)
    limit = filters |> filter(:limit) |> bounded_limit()

    sql = """
    SELECT catalog_assets.id, catalog_assets.slug, catalog_assets.title_pt,
           catalog_assets.tags_pt, catalog_assets.type, catalog_assets.file_path
    FROM catalog_assets_fts
    JOIN catalog_assets ON catalog_assets.id = catalog_assets_fts.rowid
    WHERE catalog_assets_fts MATCH ?
      AND (? IS NULL OR catalog_assets.type = ?)
    ORDER BY bm25(catalog_assets_fts), catalog_assets.id
    LIMIT ?
    """

    case Repo.query(sql, [match_query, type, type, limit]) do
      {:ok, %{rows: rows}} -> {:ok, Enum.map(rows, &to_asset/1)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp to_asset([id, slug, title_pt, tags_pt, type, file_path]) do
    %Asset{
      id: id,
      slug: slug,
      title_pt: title_pt,
      tags_pt: tags_pt,
      type: type,
      file_path: file_path
    }
  end

  defp fts_query(query) do
    query
    |> String.trim()
    |> then(fn trimmed -> Regex.scan(~r/[\p{L}\p{N}_]+/u, trimmed, capture: :first) end)
    |> List.flatten()
    |> Enum.map_join(" OR ", fn token -> "\"#{token}\"" end)
  end

  defp filter(filters, key) do
    Map.get(filters, key) || Map.get(filters, Atom.to_string(key))
  end

  defp bounded_limit(limit) when is_integer(limit), do: limit |> max(1) |> min(@max_limit)
  defp bounded_limit(_), do: @default_limit
end
