defmodule TelaWeb.DesignController do
  use TelaWeb, :controller

  alias Tela.Designs

  def index(conn, _params) do
    {:ok, designs} = Designs.list(conn.query_params)
    json(conn, %{designs: Enum.map(designs, &summary/1)})
  end

  def create(conn, params) do
    attrs = params |> body_attrs() |> Map.put("created_by_id", profile_id(conn))

    case Designs.create(attrs) do
      {:ok, design} ->
        conn
        |> put_status(:created)
        |> json(%{design: detail(design)})

      {:error, :unknown_preset} ->
        error(conn, :unprocessable_entity, "unknown_preset", "Preset não encontrado.")

      {:error, :not_found} ->
        error(conn, :not_found, "not_found", "Pasta ou template não encontrado.")

      {:error, reason} ->
        render_error(conn, reason)
    end
  end

  def show(conn, %{"id" => id}) do
    case Designs.get(id) do
      {:ok, design} -> json(conn, %{design: detail(design)})
      {:error, :not_found} -> error(conn, :not_found, "not_found", "Design não encontrado.")
    end
  end

  def update(conn, %{"id" => id} = params) do
    attrs =
      params |> Map.delete("id") |> body_attrs() |> Map.put("updated_by_id", profile_id(conn))

    case Designs.update(id, attrs) do
      {:ok, design} -> json(conn, %{design: detail(design)})
      {:error, reason} -> render_error(conn, reason)
    end
  end

  def delete(conn, %{"id" => id}) do
    permanent? = conn.query_params["permanent"] in ["1", "true", "yes"]
    result = if permanent?, do: Designs.permanently_delete(id), else: Designs.trash(id)

    case result do
      {:ok, _design} -> send_resp(conn, :no_content, "")
      {:error, reason} -> render_error(conn, reason)
    end
  end

  def duplicate(conn, %{"id" => id}) do
    case Designs.duplicate(id, profile_id(conn)) do
      {:ok, design} ->
        conn
        |> put_status(:created)
        |> json(%{design: detail(design)})

      {:error, reason} ->
        render_error(conn, reason)
    end
  end

  def restore(conn, %{"id" => id}) do
    case Designs.restore(id) do
      {:ok, design} -> json(conn, %{design: detail(design)})
      {:error, reason} -> render_error(conn, reason)
    end
  end

  def set_thumbnail(conn, %{"id" => id, "image" => upload}) do
    case Designs.set_thumbnail(id, upload) do
      {:ok, design} -> json(conn, %{thumbnail_url: Designs.thumbnail_url(design.thumbnail_path)})
      {:error, reason} -> render_error(conn, reason)
    end
  end

  def set_thumbnail(conn, _params),
    do: error(conn, :unprocessable_entity, "invalid_thumbnail", "Envie a imagem no campo image.")

  def thumbnail(conn, %{"id" => id}) do
    case Designs.get_thumbnail(id) do
      {:ok, %{path: path, content_type: content_type}} ->
        conn
        |> put_resp_header("content-type", content_type)
        |> put_resp_header("x-content-type-options", "nosniff")
        |> send_file(:ok, path)

      {:error, :not_found} ->
        error(conn, :not_found, "not_found", "Thumbnail não encontrada.")
    end
  end

  @doc false
  def summary(design) do
    %{
      id: design.id,
      title: design.title,
      width: design.width,
      height: design.height,
      preset_id: design.preset_id,
      category: design.category,
      page_count: design.page_count,
      thumbnail_url: Designs.thumbnail_url(design.thumbnail_path),
      folder_id: design.folder_id,
      starred: design.starred,
      revision: design.revision,
      created_by_id: design.created_by_id,
      updated_by_id: design.updated_by_id,
      created_at: datetime(design.inserted_at),
      updated_at: datetime(design.updated_at),
      trashed_at: datetime(design.trashed_at)
    }
  end

  @doc false
  def detail(design), do: Map.put(summary(design), :document, design.document)

  defp body_attrs(%{"design" => design}) when is_map(design), do: design
  defp body_attrs(params) when is_map(params), do: params
  defp body_attrs(_), do: %{}

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
    do: error(conn, :not_found, "not_found", "Design ou pasta não encontrado.")

  defp render_error(conn, :invalid_document),
    do: error(conn, :unprocessable_entity, "invalid_document", "O documento enviado é inválido.")

  defp render_error(conn, :document_too_large),
    do: error(conn, :payload_too_large, "document_too_large", "O documento excede 12 MiB.")

  defp render_error(conn, :invalid_revision),
    do:
      error(
        conn,
        :bad_request,
        "invalid_revision",
        "Informe expected_revision ao salvar o documento."
      )

  defp render_error(conn, :trashed),
    do: error(conn, :conflict, "design_trashed", "Restaure o design antes de editá-lo.")

  defp render_error(conn, :template_read_only),
    do:
      error(
        conn,
        :conflict,
        "template_read_only",
        "Templates não podem ser alterados como designs."
      )

  defp render_error(conn, :not_trashed),
    do:
      error(
        conn,
        :conflict,
        "not_trashed",
        "Somente designs na lixeira podem ser excluídos permanentemente."
      )

  defp render_error(conn, :unknown_preset),
    do: error(conn, :unprocessable_entity, "unknown_preset", "Preset não encontrado.")

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

  defp render_error(conn, :invalid_thumbnail),
    do:
      error(
        conn,
        :unprocessable_entity,
        "invalid_thumbnail",
        "A imagem precisa ser PNG, JPEG ou WebP."
      )

  defp render_error(conn, :thumbnail_too_large),
    do: error(conn, :payload_too_large, "thumbnail_too_large", "A thumbnail excede 2 MiB.")

  defp render_error(conn, :thumbnail_storage_failed),
    do:
      error(
        conn,
        :unprocessable_entity,
        "thumbnail_storage_failed",
        "Não foi possível salvar a thumbnail."
      )

  defp render_error(conn, %Ecto.Changeset{}),
    do: error(conn, :unprocessable_entity, "validation_error", "Os dados enviados são inválidos.")

  defp render_error(conn, _reason),
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
