defmodule Tela.Media do
  @moduledoc "Shared workspace media uploads and their local storage."

  import Ecto.Query
  alias Tela.Media.Format
  alias Tela.Media.HTTPcClient
  alias Tela.Media.MediaUpload
  alias Tela.Media.StockProvider.Pexels
  alias Tela.Media.StockProvider.Pixabay
  alias Tela.Media.StockProvider.Unsplash
  alias Tela.Media.StockProvider.Wikimedia
  alias Tela.Media.Storage.Local
  alias Tela.Repo

  @providers %{pexels: Pexels, pixabay: Pixabay, unsplash: Unsplash, wikimedia: Wikimedia}
  @max_external_bytes 20_000_000
  @max_upload_bytes 50_000_000
  @max_poster_bytes 5_000_000
  @max_metadata_bytes 65_536

  @spec list_uploads() :: {:ok, [MediaUpload.t()]}
  def list_uploads do
    uploads =
      MediaUpload
      |> order_by([upload], desc: upload.inserted_at, desc: upload.id)
      |> Repo.all()

    {:ok, uploads}
  end

  @spec list_uploads(map()) :: {:ok, [MediaUpload.t()]}
  def list_uploads(filters) when is_map(filters) do
    kind = attr(filters, :kind)
    search = attr(filters, :q) || attr(filters, :search)
    ordering = attr(filters, :ordering)

    uploads =
      MediaUpload
      |> maybe_filter_kind(kind)
      |> maybe_search_filename(search)
      |> order_uploads(ordering)
      |> Repo.all()

    {:ok, uploads}
  end

  @spec get_upload(binary()) :: {:ok, MediaUpload.t()} | {:error, :not_found}
  def get_upload(id) do
    with {:ok, uuid} <- Ecto.UUID.cast(id),
         %MediaUpload{} = upload <- Repo.get(MediaUpload, uuid) do
      {:ok, upload}
    else
      _ -> {:error, :not_found}
    end
  end

  @spec list_uploads_by_ids([binary()]) :: {:ok, [MediaUpload.t()]} | {:error, :invalid_asset}
  def list_uploads_by_ids(ids) when is_list(ids) do
    with {:ok, uuids} <- cast_uuids(ids) do
      uploads = Repo.all(from upload in MediaUpload, where: upload.id in ^uuids)
      by_id = Map.new(uploads, &{&1.id, &1})
      ordered_uploads = Enum.map(uuids, &Map.get(by_id, &1))

      if Enum.any?(ordered_uploads, &is_nil/1),
        do: {:error, :invalid_asset},
        else: {:ok, ordered_uploads}
    end
  end

  def list_uploads_by_ids(_ids), do: {:error, :invalid_asset}

  @spec delete_upload(binary()) :: {:ok, MediaUpload.t()} | {:error, :not_found}
  def delete_upload(id) do
    with {:ok, upload} <- get_upload(id),
         {:ok, deleted} <- Repo.delete(upload) do
      Local.remove(deleted.storage_path)
      Local.remove(deleted.poster_path)
      {:ok, deleted}
    end
  end

  @spec to_asset(MediaUpload.t()) :: map()
  def to_asset(%MediaUpload{} = upload) do
    metadata = upload.metadata || %{}
    is_image = upload.kind in ["image", "svg"]
    poster_url = if is_binary(upload.poster_path), do: public_url(upload, :poster), else: ""

    attribution =
      if upload.attribution,
        do: %{provider: upload.source, author: upload.attribution, author_url: "", source_url: ""}

    %{
      id: upload.id,
      kind: upload.kind,
      name: upload.filename,
      url: public_url(upload),
      thumb_url: if(is_image, do: public_url(upload), else: poster_url),
      width: upload.width || 0,
      height: upload.height || 0,
      size: upload.byte_size,
      mime: upload.content_type,
      tags: [],
      attribution: attribution,
      duration_ms: upload.duration_ms,
      status: "ready",
      error: nil,
      poster_url: poster_url,
      audio_url: "",
      video: if(upload.kind == "video", do: Map.get(metadata, "video"), else: nil),
      metadata: metadata,
      created_at: iso8601(upload.inserted_at)
    }
  end

  @spec upload(Ecto.UUID.t() | nil, map()) :: {:ok, MediaUpload.t()} | {:error, term()}
  def upload(created_by_id, upload) when is_map(upload) do
    with {:ok, temp_path} <- upload_value(upload, :temp_path),
         {:ok, client_name} <- upload_value(upload, :client_name),
         {:ok, byte_size} <- file_size(temp_path),
         :ok <- validate_upload_size(byte_size),
         kind <- attr(upload, :kind) || kind_from_content_type(attr(upload, :content_type)),
         {:ok, media_info} <- Format.inspect_upload(temp_path, kind),
         :ok <- validate_content_type(upload, media_info.content_type),
         {:ok, metadata} <- upload_metadata(upload),
         {:ok, duration_ms} <- optional_positive_integer(attr(upload, :duration_ms)),
         {:ok, width} <- optional_positive_integer(attr(upload, :width), media_info.width),
         {:ok, height} <- optional_positive_integer(attr(upload, :height), media_info.height),
         {:ok, filename} <- display_filename(client_name, media_info.extension),
         uuid <- Ecto.UUID.generate(),
         {:ok, storage_path, poster_path} <-
           store_upload_files(temp_path, media_info, uuid, upload) do
      attrs = %{
        created_by_id: created_by_id,
        kind: media_info.kind,
        filename: filename,
        storage_path: storage_path,
        content_type: media_info.content_type,
        byte_size: byte_size,
        source: "upload",
        width: width,
        height: height,
        duration_ms: duration_ms,
        poster_path: poster_path,
        metadata: metadata
      }

      case %MediaUpload{} |> MediaUpload.changeset(attrs) |> Repo.insert() do
        {:ok, media_upload} ->
          {:ok, media_upload}

        {:error, changeset} ->
          Local.remove(storage_path)
          Local.remove(poster_path)
          {:error, changeset}
      end
    else
      false -> {:error, :upload_too_large}
      {:error, reason} -> {:error, reason}
    end
  end

  def upload(_created_by_id, _upload), do: {:error, :invalid_upload}

  @spec search_external(String.t(), atom(), pos_integer()) ::
          {:ok, %{items: [map()], next_page: pos_integer() | nil, errors: [map()]}}
          | {:error, term()}
  def search_external(query, provider, page \\ 1)

  def search_external(query, :all, page)
      when is_binary(query) and is_integer(page) and page > 0 do
    providers = available_providers()

    results =
      providers
      |> Task.async_stream(
        fn provider -> {provider, search_provider(query, provider, page)} end,
        ordered: true,
        timeout: 15_000,
        on_timeout: :kill_task
      )
      |> Enum.zip(providers)
      |> Enum.map(fn
        {{:ok, {provider, result}}, _expected_provider} -> {provider, result}
        {{:exit, reason}, provider} -> {provider, {:error, reason}}
      end)

    {items, errors, has_next_page?} =
      Enum.reduce(results, {[], [], false}, fn
        {_provider, {:ok, %{items: items, next_page: next_page}}},
        {all_items, errors, has_next} ->
          {all_items ++ items, errors, has_next or not is_nil(next_page)}

        {provider, {:error, reason}}, {all_items, errors, has_next} ->
          {all_items, errors ++ [%{provider: provider, reason: reason}], has_next}
      end)

    {:ok, %{items: items, next_page: if(has_next_page?, do: page + 1), errors: errors}}
  end

  def search_external(query, provider, page)
      when is_binary(query) and is_integer(page) and page > 0 and is_atom(provider) do
    case search_provider(query, provider, page) do
      {:ok, %{items: items, next_page: next_page}} ->
        {:ok, %{items: items, next_page: next_page, errors: []}}

      {:error, reason} ->
        {:ok, %{items: [], next_page: nil, errors: [%{provider: provider, reason: reason}]}}
    end
  end

  def search_external(_query, _provider, _page), do: {:error, :invalid_search}

  @spec import_external(Ecto.UUID.t() | nil, atom(), String.t()) ::
          {:ok, MediaUpload.t()} | {:error, term()}
  def import_external(_created_by_id, :unsplash, external_id)
      when is_binary(external_id) and external_id != "" do
    {:error, :hotlinked_provider}
  end

  def import_external(created_by_id, provider, external_id)
      when is_atom(provider) and is_binary(external_id) and external_id != "" do
    with {:ok, provider_module} <- provider_module(provider),
         {:ok, cached} <- cached_external(provider, external_id) do
      case cached do
        %MediaUpload{} = media_upload ->
          {:ok, media_upload}

        nil ->
          import_external_photo(created_by_id, provider, external_id, provider_module)
      end
    end
  end

  def import_external(_created_by_id, _provider, _external_id), do: {:error, :invalid_external_id}

  @spec select_external(Ecto.UUID.t() | nil, atom(), String.t()) ::
          {:ok, map()} | {:error, term()}
  def select_external(_created_by_id, :unsplash, external_id)
      when is_binary(external_id) and external_id != "" do
    with {:ok, photo} <- Unsplash.select(external_id) do
      {:ok, unsplash_asset(photo)}
    end
  end

  def select_external(created_by_id, provider, external_id) do
    with {:ok, upload} <- import_external(created_by_id, provider, external_id) do
      {:ok, to_asset(upload)}
    end
  end

  @spec public_url(MediaUpload.t()) :: String.t()
  def public_url(%MediaUpload{id: id}) when is_binary(id), do: "/uploads/" <> id

  def public_url(%MediaUpload{id: id}, :poster) when is_binary(id),
    do: "/uploads/" <> id <> "?variant=poster"

  defp search_provider(query, provider, page) do
    with {:ok, provider_module} <- provider_module(provider) do
      provider_module.search(query, page)
    end
  end

  defp provider_module(provider) do
    case Map.fetch(@providers, provider) do
      {:ok, module} -> {:ok, module}
      :error -> {:error, :unsupported_provider}
    end
  end

  defp available_providers do
    [:wikimedia]
    |> maybe_add_provider(:pixabay, configured?(:pixabay_api_key))
    |> maybe_add_provider(:pexels, configured?(:pexels_api_key))
    |> maybe_add_provider(:unsplash, configured?(:unsplash_access_key))
  end

  defp maybe_add_provider(providers, _provider, false), do: providers
  defp maybe_add_provider(providers, provider, true), do: providers ++ [provider]

  defp configured?(key) do
    case Application.get_env(:tela, key) do
      value when is_binary(value) -> String.trim(value) != ""
      _ -> false
    end
  end

  defp cached_external(provider, external_id) do
    case Repo.get_by(MediaUpload, source: Atom.to_string(provider), external_id: external_id) do
      nil -> {:ok, nil}
      media_upload -> {:ok, media_upload}
    end
  end

  defp import_external_photo(created_by_id, provider, external_id, provider_module) do
    with {:ok, %{url: url, author: author}} <- provider_module.resolve(external_id),
         :ok <- validate_download_url(provider, url),
         {:ok, %{status: 200, body: body}} <- http_client().get(url, [], timeout: 20_000),
         :ok <- validate_download_size(body),
         {:ok, media_info} <- Format.inspect(body),
         {:ok, temp_path} <- write_temporary_file(body),
         result <-
           store_external(created_by_id, provider, external_id, author, media_info, temp_path) do
      File.rm(temp_path)
      result
    else
      {:ok, %{status: status}} -> {:error, {:download_failed, status}}
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_provider_response}
    end
  end

  defp store_external(created_by_id, provider, external_id, author, media_info, temp_path) do
    uuid = Ecto.UUID.generate()

    with {:ok, storage_path} <- Local.store(temp_path, media_info.extension, uuid) do
      attrs = %{
        created_by_id: created_by_id,
        filename: Atom.to_string(provider) <> "-" <> external_id <> media_info.extension,
        storage_path: storage_path,
        content_type: media_info.content_type,
        byte_size: File.stat!(storage_path).size,
        source: Atom.to_string(provider),
        kind: media_info.kind,
        external_id: external_id,
        attribution: author,
        width: media_info.width,
        height: media_info.height
      }

      case %MediaUpload{} |> MediaUpload.changeset(attrs) |> Repo.insert() do
        {:ok, media_upload} ->
          {:ok, media_upload}

        {:error, changeset} ->
          File.rm(storage_path)

          case cached_external(provider, external_id) do
            {:ok, %MediaUpload{} = media_upload} -> {:ok, media_upload}
            _ -> {:error, changeset}
          end
      end
    end
  end

  defp unsplash_asset(photo) do
    %{
      id: "unsplash:" <> photo.external_id,
      kind: "image",
      name: "unsplash-" <> photo.external_id,
      url: photo.url,
      thumb_url: photo.thumb_url,
      width: photo.width || 0,
      height: photo.height || 0,
      size: 0,
      mime: "image/jpeg",
      tags: [],
      attribution: %{
        provider: "unsplash",
        author: photo.author,
        author_url: photo.author_url,
        source_url: photo.source_url
      },
      duration_ms: nil,
      status: "ready",
      error: nil,
      poster_url: "",
      audio_url: "",
      video: nil,
      metadata: %{},
      created_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp validate_download_url(provider, url) when is_binary(url) do
    uri = URI.parse(url)

    if uri.scheme == "https" and is_nil(uri.userinfo) and
         allowed_download_host?(provider, uri.host) and
         uri.port in [nil, 443] do
      :ok
    else
      {:error, :invalid_download_url}
    end
  end

  defp validate_download_url(_provider, _url), do: {:error, :invalid_download_url}

  defp allowed_download_host?(:pexels, "images.pexels.com"), do: true

  defp allowed_download_host?(:pixabay, host) when is_binary(host) do
    host == "pixabay.com" or String.ends_with?(host, ".pixabay.com")
  end

  defp allowed_download_host?(:wikimedia, "upload.wikimedia.org"), do: true
  defp allowed_download_host?(:unsplash, "images.unsplash.com"), do: true
  defp allowed_download_host?(_provider, _host), do: false

  defp validate_download_size(body)
       when is_binary(body) and byte_size(body) in 1..@max_external_bytes,
       do: :ok

  defp validate_download_size(_body), do: {:error, :unsupported_media}

  defp write_temporary_file(body) do
    path = Path.join(System.tmp_dir!(), "tela-external-#{Ecto.UUID.generate()}")

    case File.write(path, body, [:binary, :exclusive]) do
      :ok -> {:ok, path}
      {:error, reason} -> {:error, reason}
    end
  end

  defp http_client, do: Application.get_env(:tela, :http_client, HTTPcClient)

  defp upload_value(upload, key) do
    case Map.fetch(upload, key) do
      {:ok, value} when is_binary(value) and value != "" ->
        {:ok, value}

      :error ->
        case Map.fetch(upload, Atom.to_string(key)) do
          {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
          _ -> {:error, :invalid_upload}
        end

      _ ->
        {:error, :invalid_upload}
    end
  end

  defp attr(attrs, key) when is_map(attrs),
    do: Map.get(attrs, key, Map.get(attrs, Atom.to_string(key)))

  defp attr(_attrs, _key), do: nil

  defp kind_from_content_type(type) when is_binary(type) do
    type = type |> String.split(";", parts: 2) |> hd() |> String.trim() |> String.downcase()

    cond do
      type == "image/svg+xml" -> "svg"
      String.starts_with?(type, "image/") -> "image"
      String.starts_with?(type, "audio/") -> "audio"
      String.starts_with?(type, "video/") -> "video"
      true -> nil
    end
  end

  defp kind_from_content_type(_type), do: nil

  defp validate_upload_size(size) when size in 1..@max_upload_bytes, do: :ok
  defp validate_upload_size(_size), do: {:error, :upload_too_large}

  defp optional_positive_integer(nil), do: {:ok, nil}
  defp optional_positive_integer(0), do: {:ok, nil}
  defp optional_positive_integer(value) when is_integer(value) and value > 0, do: {:ok, value}

  defp optional_positive_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {0, ""} -> {:ok, nil}
      {integer, ""} when integer > 0 -> {:ok, integer}
      _ -> {:error, :invalid_upload_metadata}
    end
  end

  defp optional_positive_integer(_value), do: {:error, :invalid_upload_metadata}

  defp optional_positive_integer(nil, fallback), do: {:ok, fallback}
  defp optional_positive_integer(value, _fallback), do: optional_positive_integer(value)

  defp upload_metadata(upload) do
    case attr(upload, :metadata) do
      nil ->
        {:ok, nil}

      metadata when is_map(metadata) ->
        validate_metadata(metadata)

      metadata when is_binary(metadata) ->
        with {:ok, decoded} when is_map(decoded) <- JSON.decode(metadata) do
          validate_metadata(decoded)
        else
          _ -> {:error, :invalid_upload_metadata}
        end

      _ ->
        {:error, :invalid_upload_metadata}
    end
  end

  defp validate_metadata(metadata) do
    encoded = JSON.encode!(metadata)

    if byte_size(encoded) <= @max_metadata_bytes,
      do: {:ok, metadata},
      else: {:error, :invalid_upload_metadata}
  end

  defp store_upload_files(temp_path, media_info, uuid, upload) do
    with {:ok, storage_path} <- Local.store(temp_path, media_info.extension, uuid) do
      case attr(upload, :poster_temp_path) do
        nil ->
          {:ok, storage_path, nil}

        poster_temp_path ->
          case store_poster(poster_temp_path, uuid <> "-poster") do
            {:ok, poster_path} ->
              {:ok, storage_path, poster_path}

            {:error, reason} ->
              Local.remove(storage_path)
              {:error, reason}
          end
      end
    end
  end

  defp store_poster(path, uuid) when is_binary(path) do
    with {:ok, size} <- file_size(path),
         true <- size <= @max_poster_bytes,
         {:ok, info} <- Format.inspect_upload(path, nil),
         true <- info.kind in ["image", "svg"],
         {:ok, poster_path} <- Local.store(path, info.extension, uuid) do
      {:ok, poster_path}
    else
      false -> {:error, :invalid_poster}
      {:error, :unsupported_media} -> {:error, :invalid_poster}
      {:error, reason} -> {:error, reason}
    end
  end

  defp store_poster(_path, _uuid), do: {:error, :invalid_poster}

  defp maybe_filter_kind(query, kind) when kind in ["image", "svg", "audio", "video"],
    do: where(query, [upload], upload.kind == ^kind)

  defp maybe_filter_kind(query, nil),
    do: where(query, [upload], upload.kind in ["image", "svg"])

  defp maybe_filter_kind(query, kind) when is_binary(kind),
    do: where(query, [upload], upload.kind == ^kind)

  defp maybe_filter_kind(query, _kind),
    do: where(query, [upload], upload.kind in ["image", "svg"])

  defp maybe_search_filename(query, search) when is_binary(search) and search != "" do
    pattern = "%#{String.downcase(String.trim(search))}%"
    where(query, [upload], fragment("lower(?) LIKE ?", upload.filename, ^pattern))
  end

  defp maybe_search_filename(query, _search), do: query

  defp order_uploads(query, ordering) when ordering in ["name", "-name"] do
    direction = if String.starts_with?(ordering, "-"), do: :desc, else: :asc

    order_by(query, [upload], [
      {^direction, fragment("lower(?)", upload.filename)},
      asc: upload.id
    ])
  end

  defp order_uploads(query, ordering) when ordering in ["size", "-size"] do
    direction = if String.starts_with?(ordering, "-"), do: :desc, else: :asc
    order_by(query, [upload], [{^direction, upload.byte_size}, asc: upload.id])
  end

  defp order_uploads(query, ordering) when ordering in ["created_at", "-created_at"] do
    direction = if String.starts_with?(ordering, "-"), do: :desc, else: :asc
    order_by(query, [upload], [{^direction, upload.inserted_at}, asc: upload.id])
  end

  defp order_uploads(query, _ordering),
    do: order_by(query, [upload], desc: upload.inserted_at, desc: upload.id)

  defp cast_uuids(ids) do
    Enum.reduce_while(ids, {:ok, []}, fn id, {:ok, acc} ->
      case Ecto.UUID.cast(id) do
        {:ok, uuid} -> {:cont, {:ok, acc ++ [uuid]}}
        :error -> {:halt, {:error, :invalid_asset}}
      end
    end)
  end

  defp file_size(path) do
    case File.stat(path) do
      {:ok, %{size: size}} when size > 0 -> {:ok, size}
      {:ok, _} -> {:error, :unsupported_media}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_content_type(upload, actual_type) do
    client_type = Map.get(upload, :content_type) || Map.get(upload, "content_type")

    case client_type do
      nil ->
        :ok

      type when is_binary(type) ->
        normalized_type =
          type |> String.split(";", parts: 2) |> hd() |> String.trim() |> String.downcase()

        normalized_actual =
          if normalized_type == "image/jpg", do: "image/jpeg", else: normalized_type

        normalized_actual =
          case normalized_actual do
            "audio/x-wav" -> "audio/wav"
            "audio/wave" -> "audio/wav"
            type -> type
          end

        if normalized_actual == actual_type do
          :ok
        else
          {:error, :unsupported_media}
        end

      _ ->
        {:error, :unsupported_media}
    end
  end

  defp display_filename(client_name, extension) do
    filename =
      client_name
      |> String.replace("\\", "/")
      |> Path.basename()
      |> String.replace(~r/[[:cntrl:]]/, "")
      |> String.trim()

    if filename == "" do
      {:ok, "upload" <> extension}
    else
      {:ok, filename}
    end
  end

  defp iso8601(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
  defp iso8601(_datetime), do: nil
end
