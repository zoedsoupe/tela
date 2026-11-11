defmodule TelaWeb.CommentController do
  use TelaWeb, :controller

  alias Tela.Sharing

  def index(conn, %{"design_id" => design_id}) do
    case Sharing.list_comments(design_id) do
      {:ok, comments} -> json(conn, Enum.map(comments, &Sharing.comment_json/1))
      {:error, reason} -> error(conn, reason)
    end
  end

  def index(conn, _params), do: error(conn, :not_found)

  def create(conn, %{"design_id" => design_id} = params) do
    case Sharing.create_comment(design_id, params, identity(conn)) do
      {:ok, comment} -> conn |> put_status(:created) |> json(Sharing.comment_json(comment))
      {:error, reason} -> error(conn, reason)
    end
  end

  def create(conn, _params), do: error(conn, :not_found)

  def update(conn, %{"id" => id} = params) do
    case Sharing.update_comment(id, params) do
      {:ok, comment} -> json(conn, Sharing.comment_json(comment))
      {:error, reason} -> error(conn, reason)
    end
  end

  def update(conn, _params), do: error(conn, :not_found)

  def delete(conn, %{"id" => id}) do
    case Sharing.delete_comment(id) do
      {:ok, _comment} -> send_resp(conn, :no_content, "")
      {:error, reason} -> error(conn, reason)
    end
  end

  def delete(conn, _params), do: error(conn, :not_found)

  defp identity(conn), do: %{profile: conn.assigns[:current_profile]}

  defp error(conn, reason) do
    {status, code, message} =
      case reason do
        :not_found ->
          {404, "not_found", "Design ou comentário não encontrado."}

        :invalid_parent ->
          {422, "invalid_parent",
           "A resposta precisa apontar para um comentário raiz deste design."}

        :invalid_anchor ->
          {422, "invalid_anchor",
           "A posição do comentário é inválida; x e y devem ser informados juntos."}

        :thread_root_only ->
          {422, "thread_root_only", "Somente comentários raiz podem ser resolvidos ou movidos."}

        %Ecto.Changeset{} ->
          {422, "invalid_input", "Os dados do comentário são inválidos."}

        _ ->
          {422, "invalid_input", "Os dados do comentário são inválidos."}
      end

    conn
    |> put_status(status)
    |> json(%{error: %{code: code, message: message}})
  end
end
