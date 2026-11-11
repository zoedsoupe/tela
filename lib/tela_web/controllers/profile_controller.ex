defmodule TelaWeb.ProfileController do
  use TelaWeb, :controller

  alias Tela.Profiles
  alias TelaWeb.ProfileSession

  def create(conn, %{"profile" => profile_params}) when is_map(profile_params) do
    case Profiles.create_profile(profile_params) do
      {:ok, profile} ->
        case ProfileSession.put_current_profile(conn, profile.id) do
          {:ok, conn} -> redirect(conn, to: "/")
          {:error, :not_found} -> redirect(conn, to: "/")
        end

      {:error, _changeset} ->
        conn
        |> put_flash(
          :error,
          "Não foi possível criar seu perfil. Confira o nome e tente novamente."
        )
        |> redirect(to: "/")
    end
  end

  def create(conn, _params) do
    conn
    |> put_flash(:error, "Informe um nome para criar seu perfil.")
    |> redirect(to: "/")
  end
end
