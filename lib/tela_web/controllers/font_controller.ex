defmodule TelaWeb.FontController do
  use TelaWeb, :controller

  alias Tela.Fonts

  def index(conn, params) do
    case Fonts.list(params) do
      {:ok, page} -> json(conn, page_json(conn, params, page))
      {:error, _reason} -> unavailable(conn)
    end
  end

  def mine(conn, params) do
    case Fonts.list_mine(params) do
      {:ok, page} -> json(conn, page_json(conn, params, page))
      {:error, _reason} -> unavailable(conn)
    end
  end

  def create(conn, params) do
    case Fonts.upload(params) do
      {:ok, family} ->
        conn
        |> put_status(:created)
        |> json(Fonts.to_api(family))

      {:error, reason} ->
        upload_error(conn, reason)
    end
  end

  def delete(conn, %{"id" => id}) do
    case Fonts.delete_mine(id) do
      {:ok, _family} -> send_resp(conn, :no_content, "")
      {:error, :not_found} -> not_found(conn)
    end
  end

  def delete(conn, _params), do: not_found(conn)

  def file(conn, %{"id" => id}) do
    case Fonts.get_file(id) do
      {:ok, path, content_type} ->
        conn
        |> put_resp_header("cache-control", "private, max-age=3600")
        |> put_resp_header("content-type", content_type)
        |> put_resp_header("x-content-type-options", "nosniff")
        |> send_file(200, path)

      {:error, :not_found} ->
        not_found(conn)
    end
  end

  def file(conn, _params), do: not_found(conn)

  defp page_json(conn, params, page) do
    %{
      count: page.count,
      next: page_url(conn, params, page.page + 1, page.page * page.page_size < page.count),
      previous: page_url(conn, params, page.page - 1, page.page > 1),
      results: Enum.map(page.results, &Fonts.to_api/1)
    }
  end

  defp page_url(_conn, _params, _page, false), do: nil

  defp page_url(conn, params, page, true) do
    query = params |> Map.drop(["format"]) |> Map.put("page", page) |> Plug.Conn.Query.encode()
    conn.request_path <> "?" <> query
  end

  defp upload_error(conn, reason) do
    {status, code, message} =
      case reason do
        :font_upload_too_large ->
          {413, "font_upload_too_large",
           "O arquivo ou conjunto de fontes excede o limite permitido."}

        :invalid_font_file ->
          {:unprocessable_entity, "invalid_font_file",
           "Envie um arquivo WOFF, WOFF2, TTF ou OTF válido."}

        :invalid_font_filename ->
          {:unprocessable_entity, "invalid_font_filename",
           "O nome do arquivo de fonte é inválido."}

        :invalid_font_family ->
          {:unprocessable_entity, "invalid_font_family",
           "Informe um nome de família de fonte válido."}

        :invalid_font_category ->
          {:unprocessable_entity, "invalid_font_category", "A categoria da fonte é inválida."}

        :font_name_taken ->
          {:unprocessable_entity, "font_name_taken",
           "Já existe uma família com esse nome no workspace."}

        :font_variant_exists ->
          {:unprocessable_entity, "variant_exists",
           "Já existe uma variante com esse peso e estilo."}

        :invalid_upload ->
          {:unprocessable_entity, "invalid_font_upload",
           "Envie pelo menos um arquivo de fonte válido."}

        _ ->
          {:unprocessable_entity, "invalid_font_upload",
           "Não foi possível adicionar essas fontes."}
      end

    conn
    |> put_status(status)
    |> json(%{error: %{code: code, message: message}})
  end

  defp unavailable(conn) do
    conn
    |> put_status(:service_unavailable)
    |> json(%{
      error: %{
        code: "font_catalog_unavailable",
        message: "O catálogo de fontes não está disponível agora."
      }
    })
  end

  defp not_found(conn) do
    conn
    |> put_status(:not_found)
    |> json(%{error: %{code: "not_found", message: "Fonte não encontrada."}})
  end
end
