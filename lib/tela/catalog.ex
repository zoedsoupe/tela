defmodule Tela.Catalog do
  @moduledoc "Accent-insensitive search and API serialization for the local element catalog."

  alias Tela.Catalog.Asset
  alias Tela.Repo

  @default_page_size 30
  @max_page_size 100

  @spec search(binary(), map()) :: {:ok, [Asset.t()]} | {:error, term()}
  def search(query, filters \\ %{})

  def search(query, filters) when is_binary(query) and is_map(filters) do
    if String.trim(query) == "" do
      {:ok, []}
    else
      filters = Map.put(filters, :q, query)

      with {:ok, %{results: results}} <- list_elements(filters) do
        {:ok, results}
      end
    end
  end

  def search(_query, _filters), do: {:error, :invalid_search}

  @spec list_elements(map()) ::
          {:ok,
           %{
             count: non_neg_integer(),
             page: pos_integer(),
             page_size: pos_integer(),
             results: [Asset.t()]
           }}
          | {:error, term()}
  def list_elements(filters) when is_map(filters) do
    query = filters |> value(:q) |> normalized_query()
    kind = value(filters, :kind) || value(filters, :type)
    style = value(filters, :style)
    pack = value(filters, :pack)
    page = bounded_page(value(filters, :page))
    page_size = bounded_page_size(value(filters, :page_size) || value(filters, :limit))

    match_query = if query == "", do: nil, else: query
    offset = (page - 1) * page_size

    join =
      if match_query,
        do: "JOIN catalog_assets_fts ON catalog_assets_fts.rowid = catalog_assets.id",
        else: ""

    search_condition =
      if match_query,
        do: "catalog_assets_fts MATCH ? AND ",
        else: ""

    search_params = if match_query, do: [match_query], else: []
    filter_params = search_params ++ [kind, kind, style, style, pack, pack]

    count_sql = """
    SELECT count(*)
    FROM catalog_assets
    #{join}
    WHERE #{search_condition}(? IS NULL OR catalog_assets.type = ?)
      AND (? IS NULL OR catalog_assets.style = ?)
      AND (? IS NULL OR catalog_assets.pack_slug = ?)
    """

    data_sql = """
    SELECT catalog_assets.id, catalog_assets.slug, catalog_assets.title_pt,
           catalog_assets.tags_pt, catalog_assets.type, catalog_assets.file_path,
           catalog_assets.pack_slug, catalog_assets.pack_name, catalog_assets.style,
           catalog_assets.svg, catalog_assets.width, catalog_assets.height,
           catalog_assets.colors, catalog_assets.is_recolorable, catalog_assets.license,
           catalog_assets.license_url, catalog_assets.attribution, catalog_assets.source_url,
           catalog_assets.sort_order
    FROM catalog_assets
    #{join}
    WHERE #{search_condition}(? IS NULL OR catalog_assets.type = ?)
      AND (? IS NULL OR catalog_assets.style = ?)
      AND (? IS NULL OR catalog_assets.pack_slug = ?)
    ORDER BY #{ordering(query, value(filters, :ordering))}
    LIMIT ? OFFSET ?
    """

    with {:ok, %{rows: [[count]]}} <- Repo.query(count_sql, filter_params),
         {:ok, %{rows: rows}} <- Repo.query(data_sql, filter_params ++ [page_size, offset]) do
      {:ok,
       %{
         count: count,
         page: page,
         page_size: page_size,
         results: Enum.map(rows, &to_asset/1)
       }}
    end
  end

  def list_elements(_filters), do: {:error, :invalid_search}

  @spec list_packs() :: {:ok, [map()]} | {:error, term()}
  def list_packs do
    sql = """
    SELECT pack_slug, pack_name, type, count(*), license, license_url,
           attribution, min(source_url)
    FROM catalog_assets
    GROUP BY pack_slug, pack_name, type, license, license_url, attribution
    ORDER BY pack_name COLLATE NOCASE, pack_slug
    """

    case Repo.query(sql) do
      {:ok, %{rows: rows}} ->
        {:ok, Enum.map(rows, &to_pack/1)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec to_api(Asset.t()) :: map()
  def to_api(%Asset{} = asset) do
    %{
      id: asset.slug,
      name: asset.title_pt,
      kind: asset.type,
      style: asset.style,
      pack: %{id: asset.pack_slug, slug: asset.pack_slug, name: asset.pack_name},
      tags: String.split(asset.tags_pt || "", ~r/\s+/, trim: true),
      svg_url: svg_data_url(asset.svg),
      width: asset.width,
      height: asset.height,
      colors: get_in(asset.colors || %{}, ["values"]) || [],
      is_recolorable: asset.is_recolorable in [true, 1]
    }
  end

  defp to_pack([slug, name, kind, count, license, license_url, attribution, source_url]) do
    %{
      id: slug,
      slug: slug,
      name: name,
      kind: kind,
      thumbnail_url: nil,
      element_count: count,
      license: license,
      license_url: license_url,
      attribution: attribution,
      source_url: source_url
    }
  end

  defp to_asset([
         id,
         slug,
         title_pt,
         tags_pt,
         type,
         file_path,
         pack_slug,
         pack_name,
         style,
         svg,
         width,
         height,
         colors,
         is_recolorable,
         license,
         license_url,
         attribution,
         source_url,
         sort_order
       ]) do
    %Asset{
      id: id,
      slug: slug,
      title_pt: title_pt,
      tags_pt: tags_pt,
      type: type,
      file_path: file_path,
      pack_slug: pack_slug,
      pack_name: pack_name,
      style: style,
      svg: svg,
      width: width,
      height: height,
      colors: decode_json_map(colors),
      is_recolorable: is_recolorable,
      license: license,
      license_url: license_url,
      attribution: attribution,
      source_url: source_url,
      sort_order: sort_order
    }
  end

  defp svg_data_url(svg) when is_binary(svg) and svg != "" do
    "data:image/svg+xml;base64," <> Base.encode64(svg)
  end

  defp svg_data_url(_svg), do: ""

  defp decode_json_map(value) when is_map(value), do: value

  defp decode_json_map(value) when is_binary(value) do
    case JSON.decode(value) do
      {:ok, decoded} when is_map(decoded) -> decoded
      _ -> %{}
    end
  end

  defp decode_json_map(_value), do: %{}

  defp ordering(_query, ordering) when ordering in ["name", "-name"] do
    direction = if String.starts_with?(ordering, "-"), do: "DESC", else: "ASC"
    "catalog_assets.title_pt COLLATE NOCASE #{direction}, catalog_assets.id"
  end

  defp ordering(_query, ordering) when ordering in ["-sort_order"] do
    "catalog_assets.sort_order DESC, catalog_assets.id"
  end

  defp ordering(_query, ordering) when ordering in ["sort_order"] do
    "catalog_assets.sort_order ASC, catalog_assets.id"
  end

  defp ordering(query, ordering) when query != "" and ordering in [nil, "relevance"] do
    "bm25(catalog_assets_fts), catalog_assets.id"
  end

  defp ordering(_query, _ordering), do: "catalog_assets.sort_order ASC, catalog_assets.id"

  defp normalized_query(query) when is_binary(query) do
    query
    |> String.trim()
    |> then(fn trimmed -> Regex.scan(~r/[\p{L}\p{N}_]+/u, trimmed, capture: :first) end)
    |> List.flatten()
    |> Enum.map_join(" OR ", fn token -> "\"#{token}\"" end)
  end

  defp normalized_query(_query), do: ""

  defp value(filters, key), do: Map.get(filters, key) || Map.get(filters, Atom.to_string(key))

  defp bounded_page(page) when is_integer(page), do: page |> max(1) |> min(1_000_000)

  defp bounded_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {integer, ""} -> bounded_page(integer)
      _ -> 1
    end
  end

  defp bounded_page(_page), do: 1

  defp bounded_page_size(size) when is_integer(size), do: size |> max(1) |> min(@max_page_size)

  defp bounded_page_size(size) when is_binary(size) do
    case Integer.parse(size) do
      {integer, ""} -> bounded_page_size(integer)
      _ -> @default_page_size
    end
  end

  defp bounded_page_size(_size), do: @default_page_size
end
