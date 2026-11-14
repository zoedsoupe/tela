defmodule TelaWeb.SPAController do
  use TelaWeb, :controller

  def index(conn, _params) do
    serve_document(conn, "index.html")
  end

  def presenter(conn, _params) do
    serve_document(conn, "presenter-view.html")
  end

  defp serve_document(conn, filename) do
    path = Path.join(distribution_dir(), filename)

    case File.read(path) do
      {:ok, document} ->
        conn
        |> put_resp_header("content-type", "text/html; charset=utf-8")
        |> put_resp_header("cache-control", "no-cache")
        |> send_resp(:ok, document)

      {:error, _reason} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(:service_unavailable, "Frontend não encontrado. Execute npm --prefix frontend run build.")
    end
  end

  if Mix.env() == :dev do
    defp distribution_dir, do: Path.expand("frontend/dist", File.cwd!())
  else
    defp distribution_dir, do: Application.app_dir(:tela, "priv/static")
  end
end
