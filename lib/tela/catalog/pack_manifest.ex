defmodule Tela.Catalog.PackManifest do
  @moduledoc "Loads and validates the reviewed third-party element-pack manifest."

  @schema 1
  @normalizer_version 1
  @allowed_licenses ["MIT", "ISC", "Apache-2.0", "CC0-1.0", "ISC AND MIT"]
  @notice_licenses ~w(MIT ISC Apache-2.0)
  @allowed_download_hosts ~w(
    registry.npmjs.org
    opendoodles.s3-us-west-1.amazonaws.com
    cdn.prod.website-files.com
  )
  @id ~r/^[a-z0-9][a-z0-9-]{1,59}$/
  @npm_name ~r/^(?:@[a-z0-9~-][a-z0-9._~-]*\/)?[a-z0-9~-][a-z0-9._~-]*$/
  @version ~r/^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/
  @integrity ~r/^sha512-[A-Za-z0-9+\/]{86}==$/
  @sha256 ~r/^[0-9a-f]{64}$/
  @stem ~r/^[A-Za-z0-9][A-Za-z0-9._-]{0,120}$/

  @type pack :: %{
          required(:id) => String.t(),
          required(:name) => String.t(),
          required(:kind) => String.t(),
          required(:style) => String.t(),
          required(:sort_order) => non_neg_integer(),
          required(:source) => map(),
          required(:license) => map(),
          required(:attribution) => String.t(),
          required(:files) => map(),
          required(:naming) => map(),
          required(:tags) => map(),
          required(:normalize) => map(),
          required(:fingerprint) => String.t(),
          required(:source_ref) => String.t()
        }

  @spec load(Path.t()) :: {:ok, [pack()]} | {:error, term()}
  def load(path \\ manifest_path()) do
    with {:ok, manifest} <- File.read(path),
         {:ok, decoded} <- decode(manifest, path),
         {:ok, indexes} <- read_indexes(decoded, path),
         {:ok, packs} <- parse(manifest, indexes) do
      {:ok, packs}
    end
  end

  @spec parse(binary(), map()) :: {:ok, [pack()]} | {:error, term()}
  def parse(manifest, indexes \\ %{})

  def parse(manifest, indexes) when is_binary(manifest) and is_map(indexes) do
    with {:ok, decoded} <- JSON.decode(manifest),
         :ok <- expect(is_map(decoded), "manifest must be an object"),
         :ok <- expect(decoded["schema"] == @schema, "manifest schema must be #{@schema}"),
         raw_packs when is_list(raw_packs) <- decoded["packs"],
         :ok <- expect(raw_packs != [], "manifest packs must not be empty"),
         {:ok, packs} <- parse_packs(raw_packs, indexes),
         :ok <-
           expect(
             length(packs) == length(Enum.uniq_by(packs, & &1.id)),
             "pack ids must be unique"
           ) do
      {:ok, packs}
    else
      nil -> {:error, :invalid_manifest}
      false -> {:error, :invalid_manifest}
      {:error, _} = error -> error
      _ -> {:error, :invalid_manifest}
    end
  end

  def parse(_manifest, _indexes), do: {:error, :invalid_manifest}

  @spec select([pack()], [String.t()] | nil) :: {:ok, [pack()]} | {:error, term()}
  def select(packs, nil), do: {:ok, packs}
  def select(packs, []), do: {:ok, packs}

  def select(packs, ids) when is_list(ids) do
    unknown = Enum.reject(ids, &Enum.any?(packs, fn pack -> pack.id == &1 end))

    if unknown == [] do
      selected = MapSet.new(ids)
      {:ok, Enum.filter(packs, &MapSet.member?(selected, &1.id))}
    else
      {:error, {:unknown_packs, unknown}}
    end
  end

  def select(_packs, _ids), do: {:error, :invalid_pack_selection}

  @spec manifest_path() :: Path.t()
  def manifest_path do
    Application.app_dir(:tela, "priv/content/element_packs.json")
  end

  @spec index_path(String.t()) :: Path.t()
  def index_path(name),
    do: Path.join(Application.app_dir(:tela, "priv/content/element_pack_files"), name)

  @spec download_hosts() :: [String.t()]
  def download_hosts, do: @allowed_download_hosts

  @spec npm_url(pack()) :: String.t()
  def npm_url(%{source: %{package: package, version: version}}) do
    package_path =
      case String.split(package, "/", parts: 2) do
        ["@" <> scope, name] -> "@#{scope}%2F#{name}"
        [name] -> name
      end

    archive_name = package |> String.split("/") |> List.last()
    "https://registry.npmjs.org/#{package_path}/-/#{archive_name}-#{version}.tgz"
  end

  defp parse_packs(raw_packs, indexes) do
    Enum.reduce_while(raw_packs, {:ok, []}, fn raw, {:ok, packs} ->
      case parse_pack(raw, indexes) do
        {:ok, pack} -> {:cont, {:ok, [pack | packs]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, packs} -> {:ok, Enum.reverse(packs)}
      error -> error
    end
  end

  defp parse_pack(raw, indexes) when is_map(raw) do
    id = raw["id"]
    source = raw["source"]
    license = raw["license"]
    files = raw["files"] || %{}
    naming = raw["naming"] || %{}
    tags = raw["tags"] || %{}
    normalize = raw["normalize"]
    homepage = raw["homepage"] || ""

    with :ok <- expect(is_binary(id) and Regex.match?(@id, id), "invalid pack id"),
         :ok <- expect(is_binary(raw["name"]) and raw["name"] != "", "#{id}: name is required"),
         :ok <-
           expect(
             is_binary(homepage) and (homepage == "" or https_url?(homepage)),
             "#{id}: homepage must use HTTPS"
           ),
         :ok <-
           expect(
             raw["kind"] in ~w(icon sticker illustration shape graphic frame line),
             "#{id}: invalid kind"
           ),
         :ok <- expect(is_binary(raw["style"] || ""), "#{id}: invalid style"),
         :ok <-
           expect(
             is_integer(raw["sort_order"] || 0) and (raw["sort_order"] || 0) >= 0,
             "#{id}: invalid sort_order"
           ),
         {:ok, parsed_source, source_ref, index_fingerprint} <-
           parse_source(source, files, indexes, id),
         {:ok, parsed_license} <- parse_license(license, id),
         :ok <- validate_pack_files(files, source, id),
         {:ok, parsed_naming} <- parse_naming(naming, id),
         {:ok, parsed_tags} <- parse_tags(tags, source, id),
         {:ok, parsed_normalize} <- parse_normalize(normalize, id),
         :ok <- expect(is_binary(raw["attribution"] || ""), "#{id}: attribution must be a string"),
         :ok <- attribution_required(parsed_license, raw["attribution"] || "", id) do
      parsed = %{
        id: id,
        name: raw["name"],
        kind: raw["kind"],
        style: raw["style"] || "",
        description: raw["description"] || "",
        homepage: homepage,
        sort_order: raw["sort_order"] || 0,
        source: parsed_source,
        source_ref: source_ref,
        license: parsed_license,
        attribution: raw["attribution"] || "",
        files: parsed_files(files),
        naming: parsed_naming,
        tags: parsed_tags,
        normalize: parsed_normalize
      }

      fingerprint =
        :crypto.hash(:sha256, [
          JSON.encode!(raw),
          Integer.to_string(@normalizer_version),
          index_fingerprint
        ])
        |> Base.encode16(case: :lower)

      {:ok, Map.put(parsed, :fingerprint, fingerprint)}
    end
  end

  defp parse_pack(_raw, _indexes), do: {:error, :invalid_pack}

  defp parse_source(
         %{"type" => "npm", "package" => package, "version" => version, "integrity" => integrity},
         _files,
         _indexes,
         id
       ) do
    with :ok <-
           expect(
             is_binary(package) and Regex.match?(@npm_name, package),
             "#{id}: invalid npm package"
           ),
         :ok <-
           expect(
             is_binary(version) and Regex.match?(@version, version),
             "#{id}: npm version must be exact"
           ),
         :ok <-
           expect(
             is_binary(integrity) and Regex.match?(@integrity, integrity),
             "#{id}: invalid sha512 integrity"
           ) do
      {:ok, %{type: :npm, package: package, version: version, integrity: integrity},
       "#{package}@#{version}", ""}
    end
  end

  defp parse_source(%{"type" => "urls", "index" => index}, _files, indexes, id) do
    with :ok <- expect(safe_index?(index), "#{id}: invalid URL index name"),
         {:ok, bytes} <- fetch_index(indexes, index, id),
         {:ok, decoded} <- JSON.decode(bytes),
         {:ok, items} <- parse_url_items(decoded, id) do
      digest = :crypto.hash(:sha256, bytes) |> Base.encode16(case: :lower)

      {:ok, %{type: :urls, index: index, items: items}, "#{index} (#{length(items)} files)",
       digest}
    end
  end

  defp parse_source(_source, _files, _indexes, id),
    do: {:error, "#{id}: source must be pinned npm or urls"}

  defp parse_url_items(rows, id) when is_list(rows) and rows != [] do
    Enum.reduce_while(rows, {:ok, []}, fn row, {:ok, items} ->
      with :ok <- expect(is_map(row), "#{id}: URL index entry must be an object"),
           name when is_binary(name) <- row["name"],
           :ok <-
             expect(
               Regex.match?(@stem, name) and String.ends_with?(name, ".svg"),
               "#{id}: invalid file name"
             ),
           url when is_binary(url) <- row["url"],
           :ok <- validate_download_url(url, id),
           sha256 when is_binary(sha256) <- row["sha256"],
           :ok <- expect(Regex.match?(@sha256, sha256), "#{id}: invalid file sha256"),
           tags when is_list(tags) <- row["tags"] || [],
           :ok <- expect(Enum.all?(tags, &is_binary/1), "#{id}: tags must be strings") do
        item = %{name: name, url: url, sha256: sha256, tags: tags}
        {:cont, {:ok, [item | items]}}
      else
        _ -> {:halt, {:error, "#{id}: invalid URL index entry"}}
      end
    end)
    |> case do
      {:ok, items} ->
        items = Enum.reverse(items)

        if length(items) == length(Enum.uniq_by(items, & &1.name)),
          do: {:ok, items},
          else: {:error, "#{id}: duplicate URL file"}

      error ->
        error
    end
  end

  defp parse_url_items(_rows, id), do: {:error, "#{id}: URL index must be a non-empty list"}

  defp parse_license(%{"spdx" => spdx, "url" => url} = raw, id) do
    if is_binary(spdx) do
      with :ok <- expect(spdx in @allowed_licenses, "#{id}: unreviewed license"),
           :ok <- expect(https_url?(url), "#{id}: license URL must use HTTPS"),
           file when is_binary(file) <- raw["file"] || "",
           match when is_binary(match) <- raw["match"] || "",
           :ok <-
             expect(
               file == "" == (match == ""),
               "#{id}: license file and match must be provided together"
             ),
           :ok <- expect(file == "" or safe_pattern?(file), "#{id}: invalid license file path"),
           {:ok, _} <- compile_regex(match, "#{id}: invalid license matcher") do
        {:ok, %{spdx: spdx, url: url, file: file, match: match}}
      end
    else
      {:error, "#{id}: invalid license expression"}
    end
  end

  defp parse_license(_license, id), do: {:error, "#{id}: invalid license"}

  defp attribution_required(%{spdx: spdx}, attribution, id) do
    terms = Regex.split(~r/\s+(?:AND|OR)\s+/, spdx)

    expect(
      not Enum.any?(terms, &(&1 in @notice_licenses)) or attribution != "",
      "#{id}: license attribution is required"
    )
  end

  defp validate_pack_files(files, %{"type" => "npm"}, id) when is_map(files) do
    with include when is_list(include) and include != [] <- files["include"],
         :ok <- expect(Enum.all?(include, &safe_pattern?/1), "#{id}: invalid include patterns"),
         exclude when is_list(exclude) <- files["exclude"] || [],
         :ok <- expect(Enum.all?(exclude, &safe_pattern?/1), "#{id}: invalid exclude patterns"),
         reader when reader in ["svg", "iconify-json"] <- files["reader"] || "svg",
         :ok <- expect(is_binary(reader), "#{id}: invalid reader") do
      :ok
    else
      _ -> {:error, "#{id}: invalid file selection"}
    end
  end

  defp validate_pack_files(files, %{"type" => "urls"}, id) when is_map(files) do
    include = files["include"] || []
    exclude = files["exclude"] || []
    reader = files["reader"] || "svg"

    expect(
      reader == "svg" and is_list(include) and include != [] and
        Enum.all?(include, &safe_pattern?/1) and
        is_list(exclude) and Enum.all?(exclude, &safe_pattern?/1),
      "#{id}: invalid file selection"
    )
  end

  defp validate_pack_files(_files, _source, id), do: {:error, "#{id}: files must be an object"}

  defp parsed_files(files) do
    %{
      include: files["include"] || [],
      exclude: files["exclude"] || [],
      reader: files["reader"] || "svg"
    }
  end

  defp parse_naming(naming, id) when is_map(naming) do
    values = %{
      strip_prefix: naming["strip_prefix"] || "",
      strip_suffix: naming["strip_suffix"] || "",
      skip: naming["skip"] || "",
      brand: naming["brand"] || ""
    }

    with :ok <-
           expect(
             Enum.all?(values, fn {_key, value} -> is_binary(value) end),
             "#{id}: invalid naming rules"
           ),
         {:ok, _} <- compile_regex(values.skip, "#{id}: invalid naming.skip"),
         {:ok, _} <- compile_regex(values.brand, "#{id}: invalid naming.brand") do
      {:ok, values}
    end
  end

  defp parse_naming(_naming, id), do: {:error, "#{id}: naming must be an object"}

  defp parse_tags(tags, source, id) when is_map(tags) do
    format = tags["format"] || "none"
    file = tags["file"] || ""

    with :ok <-
           expect(
             format in ~w(none json-map tabler phosphor-js iconify-categories),
             "#{id}: invalid tags format"
           ),
         :ok <-
           expect(format == "none" == (file == ""), "#{id}: tags.file must match tags.format"),
         :ok <- expect(is_binary(file), "#{id}: tags.file must be a string"),
         :ok <- expect(file == "" or safe_pattern?(file), "#{id}: invalid tags file path"),
         :ok <-
           expect(source["type"] == "npm" or format == "none", "#{id}: URL packs use index tags") do
      {:ok, %{format: format, file: file}}
    end
  end

  defp parse_tags(_tags, _source, id), do: {:error, "#{id}: tags must be an object"}

  defp parse_normalize(%{"mode" => mode} = normalize, id) do
    size = normalize["size"]
    frame = normalize["frame"] || false
    color = normalize["color"] || "#7a64e0"

    with :ok <- expect(mode in ["mono", "colour"], "#{id}: normalize.mode must be mono or colour"),
         :ok <-
           expect(
             is_nil(size) or (is_number(size) and size >= 1 and size <= 4096),
             "#{id}: invalid normalize.size"
           ),
         :ok <- expect(is_boolean(frame), "#{id}: invalid normalize.frame"),
         :ok <-
           expect(
             is_binary(color) and Regex.match?(~r/^#[0-9a-fA-F]{6}$/, color),
             "#{id}: invalid normalize.color"
           ) do
      {:ok, %{mode: mode, size: size, frame: frame, color: String.downcase(color)}}
    end
  end

  defp parse_normalize(_normalize, id), do: {:error, "#{id}: normalize is required"}

  defp read_indexes(decoded, _path) when is_map(decoded) do
    indexes =
      decoded["packs"]
      |> List.wrap()
      |> Enum.flat_map(fn pack ->
        case pack do
          %{"source" => %{"type" => "urls", "index" => name}} when is_binary(name) ->
            if safe_index?(name) do
              case File.read(index_path(name)) do
                {:ok, bytes} -> [{name, bytes}]
                {:error, reason} -> [{name, {:error, reason}}]
              end
            else
              [{name, {:error, :invalid_index_name}}]
            end

          _ ->
            []
        end
      end)
      |> Map.new()

    case Enum.find(indexes, fn {_name, bytes} -> match?({:error, _}, bytes) end) do
      {name, {:error, reason}} -> {:error, {:index_read, name, reason}}
      nil -> {:ok, indexes}
    end
  end

  defp read_indexes(_decoded, _path), do: {:error, :invalid_manifest}

  defp fetch_index(indexes, name, id) do
    case Map.fetch(indexes, name) do
      {:ok, bytes} when is_binary(bytes) -> {:ok, bytes}
      _ -> {:error, "#{id}: missing local URL index #{name}"}
    end
  end

  defp decode(manifest, path) do
    case JSON.decode(manifest) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, reason} -> {:error, {:invalid_manifest_json, path, reason}}
    end
  end

  defp safe_index?(name) when is_binary(name) do
    Regex.match?(@stem, name) and String.ends_with?(name, ".json") and
      not String.contains?(name, "..")
  end

  defp safe_index?(_name), do: false

  defp safe_pattern?(pattern) when is_binary(pattern) and pattern != "" do
    not String.starts_with?(pattern, "/") and
      not Enum.member?(String.split(pattern, "/"), "..") and
      not String.contains?(pattern, "\\")
  end

  defp safe_pattern?(_pattern), do: false

  defp validate_download_url(url, id) do
    uri = URI.parse(url)

    expect(
      uri.scheme == "https" and uri.host in @allowed_download_hosts and is_nil(uri.userinfo),
      "#{id}: download URL host or scheme is not allowed"
    )
  rescue
    _ -> {:error, "#{id}: invalid download URL"}
  end

  defp https_url?(url) when is_binary(url) do
    uri = URI.parse(url)
    uri.scheme == "https" and is_binary(uri.host) and is_nil(uri.userinfo)
  rescue
    _ -> false
  end

  defp https_url?(_url), do: false

  defp compile_regex("", _message), do: {:ok, nil}

  defp compile_regex(value, message) do
    case Regex.compile(value) do
      {:ok, regex} -> {:ok, regex}
      {:error, _reason} -> {:error, message}
    end
  end

  defp expect(true, _message), do: :ok
  defp expect(false, message), do: {:error, message}
end
