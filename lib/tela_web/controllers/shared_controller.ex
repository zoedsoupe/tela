defmodule TelaWeb.SharedController do
  use TelaWeb, :controller

  alias Tela.Sharing
  alias TelaWeb.VersionController

  def show(conn, %{"token" => token}) do
    case Sharing.shared_document(token) do
      {:ok, document} -> json_no_store(conn, document)
      {:error, reason} -> error(conn, reason)
    end
  end

  def show(conn, _params), do: error(conn, :not_found)

  def update(conn, %{"token" => token} = params) do
    result =
      cond do
        has_key?(params, :document) and not has_key?(params, :title) ->
          Sharing.save_shared_document(token, params)

        has_key?(params, :title) and not has_key?(params, :document) ->
          Sharing.rename_shared_design(token, params)

        true ->
          {:error, :invalid_input}
      end

    case result do
      {:ok, design} ->
        json_no_store(conn, %{
          design_id: design.id,
          revision: design.revision,
          title: design.title,
          updated_at: DateTime.to_iso8601(design.updated_at)
        })

      {:error, {:revision_conflict, revision}} ->
        revision_conflict(conn, revision)

      {:error, :revision_conflict} ->
        conflict_with_current_revision(conn, token)

      {:error, reason} ->
        error(conn, reason)
    end
  end

  def update(conn, _params), do: error(conn, :not_found)

  def comments(conn, %{"token" => token}) do
    case Sharing.shared_comments(token) do
      {:ok, comments} -> json_no_store(conn, Enum.map(comments, &Sharing.comment_json/1))
      {:error, reason} -> error(conn, reason)
    end
  end

  def comments(conn, _params), do: error(conn, :not_found)

  def versions(conn, %{"token" => token}) do
    case Sharing.shared_versions(token) do
      {:ok, versions} ->
        json_no_store(conn, %{versions: Enum.map(versions, &VersionController.summary/1)})

      {:error, reason} ->
        error(conn, reason)
    end
  end

  def versions(conn, _params), do: error(conn, :not_found)

  def create_version(conn, %{"token" => token} = params) do
    label = Map.get(params, "label", "Versão salva")

    case Sharing.create_shared_version(token, label, profile_id(conn)) do
      {:ok, version} ->
        conn
        |> put_status(:created)
        |> json_no_store(%{version: VersionController.summary(version)})

      {:error, reason} ->
        error(conn, reason)
    end
  end

  def create_version(conn, _params), do: error(conn, :not_found)

  def create_comment(conn, %{"token" => token} = params) do
    case Sharing.create_shared_comment(token, params, %{profile: conn.assigns[:current_profile]}) do
      {:ok, comment} ->
        conn |> put_status(:created) |> json_no_store(Sharing.comment_json(comment))

      {:error, reason} ->
        error(conn, reason)
    end
  end

  def create_comment(conn, _params), do: error(conn, :not_found)

  def restore_version(conn, %{"token" => token, "id" => version_id} = params) do
    case Sharing.restore_shared_version(token, version_id, params) do
      {:ok, design} ->
        json_no_store(conn, %{
          design_id: design.id,
          revision: design.revision,
          title: design.title,
          updated_at: DateTime.to_iso8601(design.updated_at)
        })

      {:error, {:revision_conflict, revision}} ->
        revision_conflict(conn, revision)

      {:error, :revision_conflict} ->
        conflict_with_current_revision(conn, token)

      {:error, reason} ->
        error(conn, reason)
    end
  end

  def restore_version(conn, _params), do: error(conn, :not_found)

  defp has_key?(map, key), do: Map.has_key?(map, key) or Map.has_key?(map, Atom.to_string(key))

  defp profile_id(%{assigns: %{current_profile: %{id: id}}}), do: id
  defp profile_id(_conn), do: nil

  defp json_no_store(conn, payload) do
    conn
    |> put_resp_header("cache-control", "no-store")
    |> json(payload)
  end

  defp conflict_with_current_revision(conn, token) do
    case Sharing.shared_document(token) do
      {:ok, %{revision: revision}} -> revision_conflict(conn, revision)
      {:error, reason} -> error(conn, reason)
    end
  end

  defp revision_conflict(conn, revision) do
    conn
    |> put_status(409)
    |> json_no_store(%{
      error: %{
        code: "revision_conflict",
        message: "O design foi alterado desde que foi carregado."
      },
      current: %{revision: revision}
    })
  end

  defp error(conn, reason) do
    {status, code, message} =
      case reason do
        :not_found ->
          {404, "not_found", "O link ou os dados do design não estão disponíveis."}

        :read_only ->
          {403, "read_only", "Este link não permite editar o design."}

        :trashed ->
          {409, "design_trashed", "Restaure o design antes de criar uma versão."}

        :comments_disabled ->
          {403, "comments_disabled", "Este link não permite comentários."}

        :author_name_required ->
          {422, "author_name_required", "Informe um nome para comentar."}

        :revision_conflict ->
          {409, "revision_conflict", "O design foi alterado desde que foi carregado."}

        :invalid_parent ->
          {422, "invalid_parent",
           "A resposta precisa apontar para um comentário raiz deste design."}

        :invalid_anchor ->
          {422, "invalid_anchor",
           "A posição do comentário é inválida; x e y devem ser informados juntos."}

        :thread_root_only ->
          {422, "thread_root_only", "Somente comentários raiz podem ser resolvidos ou movidos."}

        %Ecto.Changeset{} ->
          {422, "invalid_input", "Os dados enviados são inválidos."}

        _ ->
          {422, "invalid_input", "Os dados enviados são inválidos."}
      end

    conn
    |> put_status(status)
    |> json_no_store(%{error: %{code: code, message: message}})
  end
end
