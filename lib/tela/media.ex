defmodule Tela.Media do
  @moduledoc "Shared workspace media uploads and their local storage."

  import Ecto.Query
  alias Tela.Media.Format
  alias Tela.Media.HTTPcClient
  alias Tela.Media.MediaUpload
  alias Tela.Media.StockProvider.Pexels
  alias Tela.Media.StockProvider.Pixabay
  alias Tela.Media.StockProvider.Wikimedia
  alias Tela.Media.Storage.Local
  alias Tela.Repo

  @providers %{pexels: Pexels, pixabay: Pixabay, wikimedia: Wikimedia}
  @max_external_bytes 20_000_000

  @spec list_uploads() :: {:ok, [MediaUpload.t()]}
  def list_uploads do
    uploads =
      MediaUpload
      |> order_by([upload], desc: upload.inserted_at, desc: upload.id)
      |> Repo.all()

    {:ok, uploads}
  end

  @spec upload(Ecto.UUID.t() | nil, map()) :: {:ok, MediaUpload.t()} | {:error, term()}
  def upload(created_by_id, upload) when is_map(upload) do
    with {:ok, temp_path} <- upload_value(upload, :temp_path),
         {:ok, client_name} <- upload_value(upload, :client_name),
         {:ok, binary} <- File.read(temp_path),
         {:ok, media_info} <- Format.inspect(binary),
         :ok <- validate_content_type(upload, media_info.content_type),
         {:ok, byte_size} <- file_size(temp_path),
         {:ok, filename} <- display_filename(client_name, media_info.extension),
         uuid <- Ecto.UUID.generate(),
         {:ok, storage_path} <- Local.store(temp_path, media_info.extension, uuid) do
      attrs = %{
        created_by_id: created_by_id,
        filename: filename,
        storage_path: storage_path,
        content_type: media_info.content_type,
        byte_size: byte_size,
        source: "upload",
        width: media_info.width,
        height: media_info.height
      }

      case %MediaUpload{} |> MediaUpload.changeset(attrs) |> Repo.insert() do
        {:ok, media_upload} ->
          {:ok, media_upload}

        {:error, changeset} ->
          File.rm(storage_path)
          {:error, changeset}
      end
    end
  end

  def upload(_created_by_id, _upload), do: {:error, :invalid_upload}

  @spec search_external(String.t(), atom(), pos_integer()) ::
          {:ok, %{items: [map()], next_page: pos_integer() | nil, errors: [map()]}}
          | {:error, term()}
  def search_external(query, provider, page \\ 1)

  def search_external(query, :all, page)
      when is_binary(query) and is_integer(page) and page > 0 do
    providers = [:pexels, :pixabay, :wikimedia]

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

  @spec public_url(MediaUpload.t()) :: String.t()
  def public_url(%MediaUpload{id: id}) when is_binary(id), do: "/uploads/" <> id

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
end
