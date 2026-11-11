defmodule TelaWeb.MediaController do
  use TelaWeb, :controller

  alias Tela.Media.MediaUpload
  alias Tela.Repo

  @cache_control "private, max-age=3600"

  def show(conn, %{"id" => id}) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} -> serve_upload(conn, Repo.get(MediaUpload, uuid))
      :error -> not_found(conn)
    end
  end

  defp serve_upload(conn, %MediaUpload{storage_path: path} = upload)
       when is_binary(path) do
    if File.regular?(path) do
      conn
      |> put_resp_header("cache-control", @cache_control)
      |> send_download({:file, path},
        filename: safe_filename(upload.filename),
        content_type: upload.content_type,
        disposition: :inline
      )
    else
      not_found(conn)
    end
  end

  defp serve_upload(conn, _upload), do: not_found(conn)

  defp not_found(conn) do
    conn
    |> send_resp(:not_found, "Not Found")
    |> halt()
  end

  defp safe_filename(filename) when is_binary(filename) do
    filename =
      filename
      |> String.replace("\\", "/")
      |> Path.basename()
      |> String.replace(~r/[[:cntrl:]]/u, "")
      |> String.trim()

    if filename == "", do: "media", else: filename
  end

  defp safe_filename(_filename), do: "media"
end
