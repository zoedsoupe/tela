defmodule Tela.Fonts do
  @moduledoc "Offline font catalog and workspace-wide font uploads."

  import Ecto.Query

  alias Tela.Fonts.Family
  alias Tela.Fonts.Storage
  alias Tela.Repo

  @categories ["sans-serif", "serif", "display", "handwriting", "monospace"]
  @default_page_size 50
  @max_page_size 100
  @max_file_bytes 10_000_000
  @max_request_bytes 20_000_000
  @max_files 10
  @max_family_length 80

  @spec list(map()) :: {:ok, map()} | {:error, term()}
  def list(filters \\ %{})
  def list(filters) when is_map(filters), do: list_families(filters, false)
  def list(_filters), do: {:error, :invalid_search}

  @spec list_mine(map()) :: {:ok, map()} | {:error, term()}
  def list_mine(filters \\ %{})
  def list_mine(filters) when is_map(filters), do: list_families(filters, true)
  def list_mine(_filters), do: {:error, :invalid_search}

  @spec upload(map()) :: {:ok, Family.t()} | {:error, term()}
  def upload(params) when is_map(params) do
    files = value(params, :files) |> List.wrap()
    requested_family = value(params, :family) |> empty_to_nil()
    requested_category = value(params, :category)

    with {:ok, prepared} <- validate_files(files),
         {:ok, family} <- family_name(requested_family, prepared),
         {:ok, category} <- category(requested_category),
         :ok <- available_family_name(family),
         :ok <- unique_variants(prepared),
         {:ok, variants} <- store_variants(prepared) do
      attrs = %{
        family: family,
        normalized_name: normalized_name(family),
        category: category,
        scripts: %{values: ["latin"]},
        is_variable: false,
        is_user_font: true,
        variants: %{items: variants},
        popularity: 9999
      }

      case %Family{} |> Family.changeset(attrs) |> Repo.insert() do
        {:ok, family} ->
          {:ok, family}

        {:error, changeset} ->
          remove_variants(variants)
          {:error, changeset}
      end
    end
  end

  def upload(_params), do: {:error, :invalid_upload}

  @spec delete_mine(binary()) :: {:ok, Family.t()} | {:error, :not_found}
  def delete_mine(id) do
    with {:ok, uuid} <- Ecto.UUID.cast(id),
         %Family{is_user_font: true} = family <- Repo.get(Family, uuid),
         {:ok, deleted} <- Repo.delete(family) do
      deleted.variants
      |> variant_items()
      |> remove_variants()

      {:ok, deleted}
    else
      _ -> {:error, :not_found}
    end
  end

  @spec get_file(binary()) :: {:ok, binary(), binary()} | {:error, :not_found}
  def get_file(id) do
    with {:ok, uuid} <- Ecto.UUID.cast(id),
         {:ok, variant} <- find_variant(uuid),
         path <- Map.get(variant, "storage_path"),
         true <- Storage.regular_file?(path) do
      {:ok, path, content_type(Map.get(variant, "extension"))}
    else
      _ -> {:error, :not_found}
    end
  end

  @spec to_api(Family.t()) :: map()
  def to_api(%Family{} = family) do
    variants =
      family.variants
      |> variant_items()
      |> Enum.map(fn variant ->
        variant
        |> Map.take(["weight", "style", "url", "subsets"])
        |> Enum.reject(fn {_key, value} -> is_nil(value) end)
        |> Map.new()
      end)

    %{
      id: family.id,
      family: family.family,
      category: family.category,
      scripts: map_values(family.scripts),
      is_variable: family.is_variable,
      is_user_font: family.is_user_font,
      variants: variants,
      popularity: family.popularity
    }
    |> maybe_put_unicode_ranges(family.unicode_ranges)
  end

  @spec normalized_name(binary()) :: binary()
  def normalized_name(name) when is_binary(name) do
    name
    |> String.normalize(:nfd)
    |> String.replace(~r/\p{Mn}/u, "")
    |> String.downcase()
    |> String.trim()
  end

  def normalized_name(_name), do: ""

  defp list_families(filters, mine?) do
    query = filters |> value(:q) |> fts_query()
    category = value(filters, :category)
    page = bounded_page(value(filters, :page))
    page_size = bounded_page_size(value(filters, :page_size))
    offset = (page - 1) * page_size

    join = if query, do: "JOIN fonts_fts ON fonts_fts.id = fonts.id", else: ""
    search_condition = if query, do: "fonts_fts MATCH ? AND ", else: ""
    search_params = if query, do: [query], else: []
    user_flag = if(mine?, do: 1, else: 0)
    params = search_params ++ [user_flag, category, category]

    count_sql = """
    SELECT count(*)
    FROM fonts
    #{join}
    WHERE #{search_condition}fonts.is_user_font = ?
      AND (? IS NULL OR fonts.category = ?)
    """

    list_sql = """
    SELECT fonts.id, fonts.family, fonts.normalized_name, fonts.category, fonts.scripts,
           fonts.is_variable, fonts.is_user_font, fonts.variants, fonts.popularity,
           fonts.unicode_ranges, fonts.inserted_at, fonts.updated_at
    FROM fonts
    #{join}
    WHERE #{search_condition}fonts.is_user_font = ?
      AND (? IS NULL OR fonts.category = ?)
    ORDER BY #{font_order(value(filters, :ordering), query != "")}
    LIMIT ? OFFSET ?
    """

    with {:ok, %{rows: [[count]]}} <- Repo.query(count_sql, params),
         {:ok, %{rows: rows}} <- Repo.query(list_sql, params ++ [page_size, offset]) do
      {:ok,
       %{
         count: count,
         page: page,
         page_size: page_size,
         results: Enum.map(rows, &to_family/1)
       }}
    end
  end

  defp to_family([
         id,
         family,
         normalized_name,
         category,
         scripts,
         is_variable,
         is_user_font,
         variants,
         popularity,
         unicode_ranges,
         inserted_at,
         updated_at
       ]) do
    %Family{
      id: id,
      family: family,
      normalized_name: normalized_name,
      category: category,
      scripts: decode_json_map(scripts),
      is_variable: boolean_value(is_variable),
      is_user_font: boolean_value(is_user_font),
      variants: decode_json_map(variants),
      popularity: popularity,
      unicode_ranges: decode_json_map(unicode_ranges),
      inserted_at: inserted_at,
      updated_at: updated_at
    }
  end

  defp font_order(ordering, _has_query) when ordering in ["family", "-family"] do
    direction = if String.starts_with?(ordering, "-"), do: "DESC", else: "ASC"
    "fonts.family COLLATE NOCASE #{direction}, fonts.id"
  end

  defp font_order(ordering, _has_query) when ordering in ["-popularity"] do
    "fonts.popularity DESC, fonts.family COLLATE NOCASE, fonts.id"
  end

  defp font_order(ordering, _has_query) when ordering in ["created_at", "-created_at"] do
    direction = if String.starts_with?(ordering, "-"), do: "DESC", else: "ASC"
    "fonts.inserted_at #{direction}, fonts.id"
  end

  defp font_order(_ordering, _has_query),
    do: "fonts.popularity ASC, fonts.family COLLATE NOCASE, fonts.id"

  defp fts_query(query) when is_binary(query) do
    result =
      query
      |> String.trim()
      |> then(fn trimmed -> Regex.scan(~r/[\p{L}\p{N}_]+/u, trimmed, capture: :first) end)
      |> List.flatten()
      |> Enum.map_join(" OR ", fn token -> "\"#{token}\"" end)

    if result == "", do: nil, else: result
  end

  defp fts_query(_query), do: nil

  defp validate_files(files)
       when is_list(files) and files != [] and length(files) <= @max_files do
    Enum.reduce_while(files, {:ok, []}, fn file, {:ok, acc} ->
      case inspect_upload(file) do
        {:ok, prepared} ->
          total_size = Enum.reduce([prepared | acc], 0, &(&1.size + &2))

          if total_size <= @max_request_bytes do
            {:cont, {:ok, [prepared | acc]}}
          else
            {:halt, {:error, :font_upload_too_large}}
          end

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, prepared} -> {:ok, Enum.reverse(prepared)}
      error -> error
    end
  end

  defp validate_files(files) when is_list(files) and length(files) > @max_files,
    do: {:error, :font_upload_too_large}

  defp validate_files(_files), do: {:error, :invalid_font_upload}

  defp inspect_upload(%Plug.Upload{path: path, filename: filename}) do
    extension = Path.extname(filename) |> String.downcase()

    with true <- extension in [".woff", ".woff2", ".ttf", ".otf"],
         {:ok, %{size: size, type: :regular}} <- File.lstat(path),
         :ok <- validate_file_size(size),
         {:ok, signature} <- font_signature(path),
         true <- valid_signature?(extension, signature),
         {:ok, safe_filename} <- safe_filename(filename) do
      {:ok,
       %{
         path: path,
         filename: safe_filename,
         extension: extension,
         size: size,
         weight: font_weight(safe_filename),
         style: font_style(safe_filename)
       }}
    else
      false -> {:error, :invalid_font_file}
      {:error, :enoent} -> {:error, :invalid_font_file}
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_font_file}
    end
  end

  defp inspect_upload(_upload), do: {:error, :invalid_font_upload}

  defp validate_file_size(size) when size in 1..@max_file_bytes, do: :ok
  defp validate_file_size(size) when size > @max_file_bytes, do: {:error, :font_upload_too_large}
  defp validate_file_size(_size), do: {:error, :invalid_font_file}

  defp font_signature(path) do
    case File.open(path, [:read, :binary], fn file -> IO.binread(file, 4) end) do
      {:ok, signature} when is_binary(signature) and byte_size(signature) == 4 -> {:ok, signature}
      {:ok, _signature} -> {:error, :invalid_font_file}
      {:error, reason} -> {:error, reason}
    end
  end

  defp valid_signature?(".woff", "wOFF"), do: true
  defp valid_signature?(".woff2", "wOF2"), do: true
  defp valid_signature?(".ttf", <<0, 1, 0, 0>>), do: true
  defp valid_signature?(".otf", "OTTO"), do: true
  defp valid_signature?(".otf", <<0, 1, 0, 0>>), do: true
  defp valid_signature?(_extension, _signature), do: false

  defp safe_filename(filename) when is_binary(filename) do
    safe =
      filename
      |> String.replace("\\", "/")
      |> Path.basename()
      |> String.replace(~r/[[:cntrl:]]/u, "")
      |> String.trim()

    if safe != "" and String.length(safe) <= 160 do
      {:ok, safe}
    else
      {:error, :invalid_font_filename}
    end
  end

  defp family_name(name, _prepared) when is_binary(name) do
    family = String.trim(name)

    cond do
      family == "" -> {:error, :invalid_font_family}
      String.length(family) > @max_family_length -> {:error, :invalid_font_family}
      String.match?(family, ~r/[[:cntrl:]]/u) -> {:error, :invalid_font_family}
      true -> {:ok, family}
    end
  end

  defp family_name(_name, [first | _prepared]) do
    stem = Path.basename(first.filename, first.extension)

    family =
      stem
      |> String.replace(~r/(?:italic|oblique)$/i, "")
      |> String.replace(
        ~r/[-_ ]+(?:thin|extralight|ultralight|light|regular|book|medium|semibold|demibold|bold|extrabold|ultrabold|black|heavy|[1-9]00)$/i,
        ""
      )
      |> String.replace(~r/[-_ ]+/u, " ")
      |> String.trim()

    family_name(family, [])
  end

  defp family_name(_name, _prepared), do: {:error, :invalid_font_family}

  defp category(nil), do: {:ok, "sans-serif"}
  defp category(category) when category in @categories, do: {:ok, category}
  defp category(_category), do: {:error, :invalid_font_category}

  defp available_family_name(family) do
    if Repo.get_by(Family, normalized_name: normalized_name(family)) do
      {:error, :font_name_taken}
    else
      :ok
    end
  end

  defp unique_variants(prepared) do
    keys = Enum.map(prepared, &{&1.weight, &1.style})
    if length(keys) == length(Enum.uniq(keys)), do: :ok, else: {:error, :font_variant_exists}
  end

  defp store_variants(prepared) do
    Enum.reduce_while(prepared, {:ok, []}, fn font, {:ok, acc} ->
      file_id = Ecto.UUID.generate()

      case Storage.store(font.path, font.extension, file_id) do
        {:ok, path} ->
          variant = %{
            "file_id" => file_id,
            "storage_path" => path,
            "extension" => font.extension,
            "weight" => font.weight,
            "style" => font.style,
            "url" => "/api/fonts/files/" <> file_id
          }

          {:cont, {:ok, [variant | acc]}}

        {:error, reason} ->
          remove_variants(acc)
          {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, variants} -> {:ok, Enum.reverse(variants)}
      error -> error
    end
  end

  defp remove_variants(variants) do
    Enum.each(variants, fn variant ->
      case Map.get(variant, "storage_path") do
        path when is_binary(path) -> Storage.remove(path)
        _ -> :ok
      end
    end)
  end

  defp find_variant(file_id) do
    Family
    |> where([font], font.is_user_font == true)
    |> Repo.all()
    |> Enum.find_value({:error, :not_found}, fn family ->
      family
      |> Map.get(:variants)
      |> variant_items()
      |> Enum.find_value(fn variant ->
        if Map.get(variant, "file_id") == file_id, do: {:ok, variant}
      end)
    end)
  end

  defp variant_items(%{"items" => items}) when is_list(items), do: items
  defp variant_items(%{items: items}) when is_list(items), do: items
  defp variant_items(_variants), do: []

  defp decode_json_map(value) when is_map(value), do: value

  defp decode_json_map(value) when is_binary(value) do
    case JSON.decode(value) do
      {:ok, decoded} when is_map(decoded) -> decoded
      _ -> %{}
    end
  end

  defp decode_json_map(_value), do: %{}

  defp boolean_value(value) when value in [true, 1], do: true
  defp boolean_value(_value), do: false

  defp map_values(%{"values" => values}) when is_list(values), do: values
  defp map_values(%{values: values}) when is_list(values), do: values
  defp map_values(_map), do: []

  defp maybe_put_unicode_ranges(map, ranges) when is_map(ranges) and map_size(ranges) > 0,
    do: Map.put(map, :unicode_ranges, ranges)

  defp maybe_put_unicode_ranges(map, _ranges), do: map

  defp font_weight(filename) do
    stem =
      filename
      |> Path.rootname()
      |> String.downcase()
      |> String.replace(~r/(?:italic|oblique)$/i, "")

    case Regex.run(
           ~r/(?:^|[-_ ])(thin|extralight|ultralight|light|regular|book|medium|semibold|demibold|bold|extrabold|ultrabold|black|heavy|[1-9]00)(?:[-_ ]|$)/,
           stem
         ) do
      [_, weight] -> weight_number(weight)
      _ -> 400
    end
  end

  defp weight_number(weight) when weight in ["thin"], do: 100
  defp weight_number(weight) when weight in ["extralight", "ultralight"], do: 200
  defp weight_number("light"), do: 300
  defp weight_number(weight) when weight in ["regular", "book"], do: 400
  defp weight_number("medium"), do: 500
  defp weight_number(weight) when weight in ["semibold", "demibold"], do: 600
  defp weight_number("bold"), do: 700
  defp weight_number(weight) when weight in ["extrabold", "ultrabold"], do: 800
  defp weight_number(weight) when weight in ["black", "heavy"], do: 900
  defp weight_number(weight), do: String.to_integer(weight)

  defp font_style(filename) do
    if String.match?(filename, ~r/(?:italic|oblique)/i),
      do: "italic",
      else: "normal"
  end

  defp content_type(".woff"), do: "font/woff"
  defp content_type(".woff2"), do: "font/woff2"
  defp content_type(".ttf"), do: "font/ttf"
  defp content_type(".otf"), do: "font/otf"
  defp content_type(_extension), do: "application/octet-stream"

  defp value(params, key), do: Map.get(params, key) || Map.get(params, Atom.to_string(key))

  defp empty_to_nil(value) when value in [nil, ""], do: nil
  defp empty_to_nil(value), do: value

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
