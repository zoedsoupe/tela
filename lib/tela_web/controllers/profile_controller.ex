defmodule TelaWeb.ProfileController do
  use TelaWeb, :controller

  alias Tela.Profiles
  alias TelaWeb.ProfileSession

  def csrf(conn, _params) do
    token = Plug.CSRFProtection.get_csrf_token()

    conn
    |> put_resp_cookie("csrftoken", token, http_only: false, same_site: "Lax", path: "/")
    |> json(%{csrf_token: token})
  end

  def index(conn, _params) do
    {:ok, profiles} = Profiles.list_profiles()

    json(conn, %{
      profiles: Enum.map(profiles, &profile_json/1),
      current_profile: profile_json(conn.assigns.current_profile)
    })
  end

  def create_json(conn, params) do
    profile_params = Map.get(params, "profile", params)

    if is_map(profile_params) do
      case Profiles.create_profile(profile_params) do
        {:ok, profile} ->
          conn
          |> put_status(:created)
          |> json(%{profile: profile_json(profile)})

        {:error, _changeset} ->
          invalid_profile_error(conn)
      end
    else
      invalid_profile_error(conn)
    end
  end

  def select(conn, %{"profile_id" => profile_id}) when is_binary(profile_id) do
    case ProfileSession.put_current_profile(conn, profile_id) do
      {:ok, conn} -> json(conn, %{current_profile: profile_json(conn.assigns.current_profile)})
      {:error, :not_found} -> error(conn, :not_found, "not_found", "Perfil não encontrado.")
    end
  end

  def select(conn, %{"id" => profile_id}) when is_binary(profile_id),
    do: select(conn, %{"profile_id" => profile_id})

  def select(conn, _params),
    do:
      error(
        conn,
        :bad_request,
        "invalid_request",
        "Informe o profile_id para selecionar um perfil."
      )

  def clear(conn, _params) do
    {:ok, conn} = ProfileSession.put_current_profile(conn, nil)
    json(conn, %{current_profile: nil})
  end

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

  defp profile_json(nil), do: nil

  defp profile_json(profile) do
    %{
      id: profile.id,
      name: profile.name,
      created_at: datetime(profile.inserted_at),
      updated_at: datetime(profile.updated_at)
    }
  end

  defp datetime(nil), do: nil
  defp datetime(value), do: DateTime.to_iso8601(value)

  defp invalid_profile_error(conn),
    do:
      error(
        conn,
        :unprocessable_entity,
        "validation_error",
        "Informe um nome válido para o perfil."
      )

  defp error(conn, status, code, message) do
    conn
    |> put_status(status)
    |> json(%{error: %{code: code, message: message}})
  end
end
