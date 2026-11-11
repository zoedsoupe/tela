defmodule TelaWeb.ElementController do
  use TelaWeb, :controller

  alias Tela.Catalog

  def packs(conn, _params) do
    case Catalog.list_packs() do
      {:ok, packs} -> json(conn, packs)
      {:error, _reason} -> error(conn, :catalog_unavailable)
    end
  end

  def index(conn, params) do
    case Catalog.list_elements(params) do
      {:ok, page} ->
        json(conn, %{
          count: page.count,
          next: page_url(conn, params, page.page + 1, page.page * page.page_size < page.count),
          previous: page_url(conn, params, page.page - 1, page.page > 1),
          results: Enum.map(page.results, &Catalog.to_api/1)
        })

      {:error, _reason} ->
        error(conn, :catalog_unavailable)
    end
  end

  defp page_url(_conn, _params, _page, false), do: nil

  defp page_url(conn, params, page, true) do
    query = params |> Map.drop(["format"]) |> Map.put("page", page) |> Plug.Conn.Query.encode()
    conn.request_path <> "?" <> query
  end

  defp error(conn, _reason) do
    conn
    |> put_status(:service_unavailable)
    |> json(%{
      error: %{
        code: "catalog_unavailable",
        message: "O catálogo local não está disponível agora."
      }
    })
  end
end
