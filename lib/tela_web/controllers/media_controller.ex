defmodule TelaWeb.MediaController do
  use TelaWeb, :controller

  alias Tela.Media
  alias Tela.Media.MediaUpload
  alias Tela.Media.Storage.Local

  @cache_control "private, max-age=3600"

  def show(conn, %{"id" => id} = params) do
    with {:ok, upload} <- Media.get_upload(id),
         {:ok, path, content_type} <- file_for(upload, Map.get(params, "variant")),
         {:ok, %{size: size}} <- File.stat(path) do
      serve(conn, path, content_type, safe_filename(upload.filename), size)
    else
      _ -> not_found(conn)
    end
  end

  def show(conn, _params), do: not_found(conn)

  defp file_for(%MediaUpload{storage_path: path, content_type: content_type}, nil) do
    if Local.regular_file?(path), do: {:ok, path, content_type}, else: {:error, :not_found}
  end

  defp file_for(%MediaUpload{poster_path: path}, "poster") when is_binary(path) do
    if Local.regular_file?(path) do
      {:ok, path, poster_content_type(path)}
    else
      {:error, :not_found}
    end
  end

  defp file_for(_upload, _variant), do: {:error, :not_found}

  defp serve(conn, path, content_type, filename, size) do
    conn =
      conn
      |> put_resp_header("cache-control", @cache_control)
      |> put_resp_header("accept-ranges", "bytes")
      |> put_resp_header("content-type", content_type)
      |> put_resp_header("content-disposition", "inline; filename=\"#{filename}\"")

    case range(conn, size) do
      :full ->
        send_file_response(conn, path, 200, 0, size, size)

      {:partial, start, length} ->
        conn
        |> put_resp_header("content-range", "bytes #{start}-#{start + length - 1}/#{size}")
        |> send_file_response(path, 206, start, length, size)

      :invalid ->
        conn
        |> put_resp_header("content-range", "bytes */#{size}")
        |> put_resp_header("content-type", "application/json; charset=utf-8")
        |> put_status(416)
        |> json(%{
          error: %{
            code: "invalid_range",
            message: "O intervalo de bytes solicitado não é válido."
          }
        })
        |> halt()
    end
  end

  defp send_file_response(conn, _path, status, _offset, length, _size)
       when conn.method == "HEAD" do
    conn
    |> put_resp_header("content-length", Integer.to_string(length))
    |> send_resp(status, "")
  end

  defp send_file_response(conn, path, status, 0, length, size) when length == size do
    conn
    |> put_resp_header("content-length", Integer.to_string(size))
    |> send_file(status, path)
  end

  defp send_file_response(conn, path, status, offset, length, _size) do
    conn
    |> put_resp_header("content-length", Integer.to_string(length))
    |> send_file(status, path, offset, length)
  end

  defp range(conn, size) do
    case get_req_header(conn, "range") do
      [] -> :full
      [value] -> parse_range(value, size)
      _ -> :invalid
    end
  end

  defp parse_range("bytes=" <> spec, size) do
    case Regex.run(~r/\A(\d*)-(\d*)\z/, spec) do
      [_, "", ""] -> :invalid
      [_, "", suffix] -> suffix_range(suffix, size)
      [_, start, ""] -> parse_explicit_range(start, nil, size)
      [_, start, finish] -> parse_explicit_range(start, finish, size)
      _ -> :invalid
    end
  end

  defp parse_range(_value, _size), do: :invalid

  defp suffix_range(suffix, size) do
    with {length, ""} <- Integer.parse(suffix),
         true <- length > 0 do
      length = min(length, size)
      {:partial, size - length, length}
    else
      _ -> :invalid
    end
  end

  defp parse_explicit_range(start, finish, size) do
    with {start, ""} <- Integer.parse(start),
         {:ok, finish} <- parse_range_end(finish, size),
         true <- start >= 0 and start < size and finish >= start do
      {:partial, start, finish - start + 1}
    else
      _ -> :invalid
    end
  end

  defp parse_range_end(nil, size), do: {:ok, size - 1}

  defp parse_range_end(finish, size) do
    case Integer.parse(finish) do
      {integer, ""} when integer >= 0 -> {:ok, min(integer, size - 1)}
      _ -> :invalid
    end
  end

  defp poster_content_type(path) do
    case Path.extname(path) do
      ".png" -> "image/png"
      ".jpg" -> "image/jpeg"
      ".webp" -> "image/webp"
      ".svg" -> "image/svg+xml"
      _ -> "application/octet-stream"
    end
  end

  defp not_found(conn) do
    conn
    |> put_resp_header("content-type", "application/json; charset=utf-8")
    |> put_status(:not_found)
    |> json(%{error: %{code: "not_found", message: "Arquivo de mídia não encontrado."}})
    |> halt()
  end

  defp safe_filename(filename) when is_binary(filename) do
    filename =
      filename
      |> String.replace("\\", "/")
      |> Path.basename()
      |> String.replace(~r/[[:cntrl:]]/u, "")
      |> String.replace(["\\", "\""], "_")
      |> String.trim()

    if filename == "", do: "media", else: filename
  end

  defp safe_filename(_filename), do: "media"
end
