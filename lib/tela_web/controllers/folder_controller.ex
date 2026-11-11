defmodule TelaWeb.FolderController do
  use TelaWeb, :controller

  alias Tela.Designs

  def index(conn, _params) do
    {:ok, folders} = Designs.list_folders()
    json(conn, %{folders: Enum.map(folders, &folder_json/1)})
  end

  def create(conn, params) do
    attrs = params |> body_attrs() |> Map.put("created_by_id", profile_id(conn))

    case Designs.create_folder(attrs) do
      {:ok, folder} ->
        conn
        |> put_status(:created)
        |> json(%{folder: folder_json(folder)})

      {:error, reason} ->
        render_error(conn, reason)
    end
  end

  def update(conn, %{"id" => id} = params) do
    attrs = params |> Map.delete("id") |> body_attrs()

    case Designs.update_folder(id, attrs) do
      {:ok, folder} -> json(conn, %{folder: folder_json(folder)})
      {:error, reason} -> render_error(conn, reason)
    end
  end

  def delete(conn, %{"id" => id}) do
    case Designs.delete_folder(id) do
      {:ok, _folder} -> send_resp(conn, :no_content, "")
      {:error, reason} -> render_error(conn, reason)
    end
  end

  defp folder_json(folder) do
    %{
      id: folder.id,
      name: folder.name,
      parent_id: folder.parent_id,
      design_count: folder.design_count || 0,
      created_by_id: folder.created_by_id,
      created_at: datetime(folder.inserted_at),
      updated_at: datetime(folder.updated_at)
    }
  end

  defp body_attrs(%{"folder" => folder}) when is_map(folder), do: folder
  defp body_attrs(params) when is_map(params), do: params
  defp body_attrs(_), do: %{}

  defp profile_id(%{assigns: %{current_profile: %{id: id}}}), do: id
  defp profile_id(_conn), do: nil

  defp datetime(nil), do: nil
  defp datetime(value), do: DateTime.to_iso8601(value)

  defp render_error(conn, :not_found),
    do: error(conn, :not_found, "not_found", "Pasta ou pasta-pai não encontrada.")

  defp render_error(conn, :folder_cycle),
    do:
      error(
        conn,
        :unprocessable_entity,
        "folder_cycle",
        "Uma pasta não pode ser movida para dentro de si mesma."
      )

  defp render_error(conn, :folder_depth_exceeded),
    do:
      error(
        conn,
        :unprocessable_entity,
        "folder_depth_exceeded",
        "Pastas podem ter até cinco níveis."
      )

  defp render_error(conn, :folder_name_taken),
    do:
      error(
        conn,
        :unprocessable_entity,
        "folder_name_taken",
        "Já existe uma pasta com esse nome neste nível."
      )

  defp render_error(conn, :invalid_name),
    do: error(conn, :unprocessable_entity, "validation_error", "Informe um nome válido.")

  defp render_error(conn, %Ecto.Changeset{}),
    do: error(conn, :unprocessable_entity, "validation_error", "Os dados enviados são inválidos.")

  defp render_error(conn, _),
    do:
      error(
        conn,
        :unprocessable_entity,
        "invalid_request",
        "Não foi possível aplicar a alteração."
      )

  defp error(conn, status, code, message) do
    conn
    |> put_status(status)
    |> json(%{error: %{code: code, message: message}})
  end
end
