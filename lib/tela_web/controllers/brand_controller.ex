defmodule TelaWeb.BrandController do
  use TelaWeb, :controller

  alias Tela.Brands

  def index(conn, _params) do
    {:ok, kits} = Brands.list_kits()
    json(conn, Enum.map(kits, &Brands.to_api/1))
  end

  def create(conn, params) do
    profile = conn.assigns[:current_profile]
    profile_id = if profile, do: profile.id

    case Brands.create_kit(profile_id, params) do
      {:ok, kit} -> conn |> put_status(:created) |> json(Brands.to_api(kit))
      {:error, reason} -> error(conn, reason)
    end
  end

  def update(conn, %{"id" => id} = params) do
    case Brands.update_kit(id, params) do
      {:ok, kit} -> json(conn, Brands.to_api(kit))
      {:error, reason} -> error(conn, reason)
    end
  end

  def update(conn, _params), do: error(conn, :not_found)

  def delete(conn, %{"id" => id}) do
    case Brands.delete_kit(id) do
      {:ok, _kit} -> send_resp(conn, :no_content, "")
      {:error, :not_found} -> error(conn, :not_found)
    end
  end

  def delete(conn, _params), do: error(conn, :not_found)

  defp error(conn, reason) do
    {status, code, message} =
      case reason do
        :not_found ->
          {404, "not_found", "Kit de marca não encontrado."}

        :invalid_asset ->
          {422, "invalid_asset", "Um ou mais arquivos de logo não estão disponíveis."}

        :invalid_input ->
          {422, "invalid_input", "Os dados do kit de marca são inválidos."}

        %Ecto.Changeset{} ->
          {422, "invalid_input", "Os dados do kit de marca são inválidos."}

        _ ->
          {422, "invalid_input", "Os dados do kit de marca são inválidos."}
      end

    conn
    |> put_status(status)
    |> json(%{error: %{code: code, message: message}})
  end
end
