defmodule TelaWeb.ShareController do
  use TelaWeb, :controller

  alias Tela.Sharing

  def index(conn, %{"design_id" => design_id}) do
    case Sharing.list_share_links(design_id) do
      {:ok, links} -> json_no_store(conn, Enum.map(links, &Sharing.share_link_json/1))
      {:error, reason} -> error(conn, reason)
    end
  end

  def index(conn, _params), do: error(conn, :not_found)

  def create(conn, %{"design_id" => design_id} = params) do
    case Sharing.create_share_link(design_id, params) do
      {:ok, %{link: link, token: token}} ->
        conn
        |> put_status(:created)
        |> json_no_store(Sharing.share_link_json(link, token))

      {:error, reason} ->
        error(conn, reason)
    end
  end

  def create(conn, _params), do: error(conn, :not_found)

  def update(conn, %{"id" => id} = params) do
    case Sharing.update_share_link(id, params) do
      {:ok, link} -> json_no_store(conn, Sharing.share_link_json(link))
      {:error, reason} -> error(conn, reason)
    end
  end

  def update(conn, _params), do: error(conn, :not_found)

  def delete(conn, %{"id" => id}) do
    case Sharing.revoke_share_link(id) do
      {:ok, _link} ->
        conn |> put_resp_header("cache-control", "no-store") |> send_resp(:no_content, "")

      {:error, reason} ->
        error(conn, reason)
    end
  end

  def delete(conn, _params), do: error(conn, :not_found)

  defp json_no_store(conn, payload) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> json(payload)
  end

  defp error(conn, reason) do
    {status, code, message} =
      case reason do
        :not_found ->
          {404, "not_found", "Design ou link de compartilhamento não encontrado."}

        :invalid_role ->
          {422, "invalid_role", "Escolha visualização, comentário ou edição."}

        :invalid_input ->
          {422, "invalid_input", "Os dados do link de compartilhamento são inválidos."}

        %Ecto.Changeset{} ->
          {422, "invalid_role", "Escolha visualização, comentário ou edição."}

        _ ->
          {422, "invalid_input", "Os dados do link de compartilhamento são inválidos."}
      end

    conn
    |> put_status(status)
    |> json_no_store(%{error: %{code: code, message: message}})
  end
end
