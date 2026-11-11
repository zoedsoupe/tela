defmodule Tela.Media do
  @moduledoc "Shared workspace media uploads and their local storage."

  import Ecto.Query
  alias Tela.Media.Format
  alias Tela.Media.MediaUpload
  alias Tela.Media.Storage.Local
  alias Tela.Repo

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

  @spec public_url(MediaUpload.t() | binary()) :: String.t()
  def public_url(%MediaUpload{storage_path: path}), do: public_url(path)

  def public_url(path) when is_binary(path) do
    "/uploads/" <> URI.encode(Path.basename(path))
  end

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
