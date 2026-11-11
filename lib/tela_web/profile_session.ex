defmodule TelaWeb.ProfileSession do
  @moduledoc "Loads an optional local profile from the Phoenix session."

  @behaviour Plug

  import Plug.Conn
  alias Tela.Profiles

  @session_key :profile_id

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    case get_session(conn, @session_key) do
      profile_id when is_binary(profile_id) ->
        case Profiles.get_profile(profile_id) do
          {:ok, profile} ->
            assign(conn, :current_profile, profile)

          {:error, :not_found} ->
            conn
            |> delete_session(@session_key)
            |> assign(:current_profile, nil)
        end

      _ ->
        assign(conn, :current_profile, nil)
    end
  end

  @spec put_current_profile(Plug.Conn.t(), binary() | nil) ::
          {:ok, Plug.Conn.t()} | {:error, :not_found}
  def put_current_profile(conn, nil) do
    conn =
      conn
      |> ensure_session()
      |> delete_session(@session_key)
      |> assign(:current_profile, nil)

    {:ok, conn}
  end

  def put_current_profile(conn, profile_id) when is_binary(profile_id) do
    case Profiles.get_profile(profile_id) do
      {:ok, profile} ->
        conn =
          conn
          |> ensure_session()
          |> put_session(@session_key, profile.id)
          |> assign(:current_profile, profile)

        {:ok, conn}

      {:error, :not_found} ->
        {:error, :not_found}
    end
  end

  defp ensure_session(%Plug.Conn{private: %{plug_session: _session}} = conn), do: conn
  defp ensure_session(conn), do: Plug.Conn.put_private(conn, :plug_session, %{})
end
