defmodule TelaWeb.AssetController do
  use TelaWeb, :controller

  alias Tela.Media

  def index(conn, params) do
    {:ok, uploads} = Media.list_uploads(Map.take(params, ["kind", "q", "ordering"]))
    json(conn, Enum.map(uploads, &Media.to_asset/1))
  end

  def create(conn, %{"file" => %Plug.Upload{} = file} = params) do
    attrs = %{
      temp_path: file.path,
      client_name: params["name"] || file.filename,
      content_type: file.content_type,
      kind: params["kind"],
      duration_ms: params["duration_ms"],
      width: params["width"],
      height: params["height"],
      metadata: params["metadata"],
      poster_temp_path: upload_path(params["poster"])
    }

    profile = conn.assigns[:current_profile]
    profile_id = if profile, do: profile.id

    case Media.upload(profile_id, attrs) do
      {:ok, upload} -> conn |> put_status(:created) |> json(Media.to_asset(upload))
      {:error, reason} -> error(conn, reason)
    end
  end

  def create(conn, _params), do: error(conn, :invalid_upload)

  def delete(conn, %{"id" => id}) do
    case Media.delete_upload(id) do
      {:ok, _upload} -> send_resp(conn, :no_content, "")
      {:error, :not_found} -> error(conn, :not_found)
    end
  end

  def delete(conn, _params), do: error(conn, :not_found)

  defp upload_path(%Plug.Upload{path: path}), do: path
  defp upload_path(_upload), do: nil

  defp error(conn, reason) do
    {status, code, message} =
      case reason do
        :not_found ->
          {404, "not_found", "Arquivo não encontrado."}

        :upload_too_large ->
          {413, "upload_too_large", "O arquivo excede o tamanho permitido."}

        :invalid_asset ->
          {422, "invalid_asset", "Um ou mais arquivos não estão disponíveis."}

        :invalid_upload_metadata ->
          {422, "invalid_upload_metadata", "Os metadados da mídia são inválidos."}

        :invalid_poster ->
          {422, "invalid_poster", "A imagem de capa é inválida."}

        _ ->
          {422, "invalid_upload", "O arquivo não é uma imagem, áudio ou vídeo compatível."}
      end

    conn
    |> put_status(status)
    |> json(%{error: %{code: code, message: message}})
  end
end
