defmodule TelaWeb.ProfileSessionTest do
  use TelaWeb.ConnCase, async: false
  import Tela.ProfilesFixtures
  alias TelaWeb.ProfileSession

  test "persists the selected local profile in the session", %{conn: conn} do
    profile = profile_fixture()
    assert {:ok, conn} = ProfileSession.put_current_profile(conn, profile.id)
    assert get_session(conn, :profile_id) == profile.id

    conn =
      build_conn()
      |> init_test_session(%{profile_id: profile.id})
      |> ProfileSession.call([])

    assert conn.assigns.current_profile.id == profile.id
  end

  test "rejects unknown profiles and clears stale session selections", %{conn: conn} do
    assert {:error, :not_found} = ProfileSession.put_current_profile(conn, Ecto.UUID.generate())

    conn =
      build_conn()
      |> init_test_session(%{profile_id: Ecto.UUID.generate()})
      |> ProfileSession.call([])

    assert is_nil(conn.assigns.current_profile)
    assert is_nil(get_session(conn, :profile_id))
  end
end
