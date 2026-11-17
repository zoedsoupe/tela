defmodule TelaWeb.VersionController do
  use TelaWeb, :controller

  alias Tela.Designs
  alias TelaWeb.DesignController

  def index(conn, %{"design_id" => design_id}) do
    case Designs.list_versions(design_id) do
      {:ok, versions} -> json(conn, %{versions: Enum.map(versions, &summary/1)})
      {:error, :not_found} -> error(conn, :not_found, "not_found", "Design não encontrado.")
    end
  end

  def create(conn, %{"design_id" => design_id} = params) do
    label = Map.get(params, "label", "Versão salva")

    case Designs.create_version(design_id, label, profile_id(conn)) do
      {:ok, version} ->
        conn
        |> put_status(:created)
        |> json(%{version: summary(version)})

      {:error, reason} ->
        render_error(conn, reason)
    end
  end

  def show(conn, %{"design_id" => design_id, "id" => id}) do
    case Designs.get_version(design_id, id) do
      {:ok, version} ->
        json(conn, %{version: Map.put(summary(version), :document, version.document)})

      {:error, :not_found} ->
        error(conn, :not_found, "not_found", "Versão não encontrada.")
    end
  end

  def restore(conn, %{"design_id" => design_id, "id" => id}) do
    case Designs.restore_version(design_id, id, profile_id(conn)) do
      {:ok, design} -> json(conn, %{design: DesignController.detail(design)})
      {:error, reason} -> render_error(conn, reason)
    end
  end

  def summary(version) do
    %{
      id: version.id,
      design_id: version.design_id,
      label: version.label,
      is_auto: version.is_auto,
      page_count: version.page_count,
      thumbnail_url: Designs.thumbnail_url(version.thumbnail_path),
      created_by_id: version.created_by_id,
      created_at: datetime(version.inserted_at)
    }
  end

  defp profile_id(%{assigns: %{current_profile: %{id: id}}}), do: id
  defp profile_id(_conn), do: nil

  defp datetime(nil), do: nil
  defp datetime(value), do: DateTime.to_iso8601(value)

  defp render_error(conn, {:revision_conflict, revision}) do
    conn
    |> put_status(:conflict)
    |> json(%{
      error: %{
        code: "revision_conflict",
        message: "O design foi alterado por outra edição.",
        current_revision: revision
      }
    })
  end

  defp render_error(conn, :not_found),
    do: error(conn, :not_found, "not_found", "Design ou versão não encontrado.")

  defp render_error(conn, :invalid_document),
    do: error(conn, :unprocessable_entity, "invalid_document", "O documento salvo é inválido.")

  defp render_error(conn, :document_too_large),
    do: error(conn, :payload_too_large, "document_too_large", "O documento excede 12 MiB.")

  defp render_error(conn, :invalid_revision),
    do: error(conn, :bad_request, "invalid_revision", "Não foi possível aplicar a revisão.")

  defp render_error(conn, :trashed),
    do:
      error(conn, :conflict, "design_trashed", "Restaure o design antes de restaurar uma versão.")

  defp render_error(conn, %Ecto.Changeset{}),
    do: error(conn, :unprocessable_entity, "validation_error", "Os dados enviados são inválidos.")

  defp render_error(conn, _),
    do:
      error(conn, :unprocessable_entity, "invalid_request", "Não foi possível aplicar a versão.")

  defp error(conn, status, code, message) do
    conn
    |> put_status(status)
    |> json(%{error: %{code: code, message: message}})
  end
end
