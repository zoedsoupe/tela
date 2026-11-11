defmodule TelaWeb.DashboardLiveTest do
  use TelaWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import Tela.ProfilesFixtures
  alias Tela.Designs

  test "shows workspace formats and an empty project state", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, "#workspace-designs")
    assert has_element?(view, "#preset-post-instagram")
    assert has_element?(view, "#preset-apresentacao-16-9")
    assert has_element?(view, "#designs-empty")
    assert has_element?(view, "#profile-selection")
  end

  test "lists every design in the shared workspace", %{conn: conn} do
    profile = profile_fixture(%{name: "Autora"})
    {:ok, design} = Designs.create(%{created_by_id: profile.id, title: "Peça compartilhada", preset_id: "story"})
    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, "#design-#{design.id}")
    assert has_element?(view, "#design-#{design.id} [data-design-format='story']")
  end

  test "creates and selects a local profile through an HTTP session", %{conn: conn} do
    conn = post(conn, ~p"/profiles", %{profile: %{name: "Zoey"}})
    assert redirected_to(conn) == "/"
    profile_id = get_session(conn, :profile_id)
    assert is_binary(profile_id)
    assert {:ok, profile} = Tela.Profiles.get_profile(profile_id)
    assert profile.name == "Zoey"

    {:ok, view, _html} = live(recycle(conn), ~p"/")
    assert has_element?(view, "#current-profile[data-profile-id='#{profile.id}']")
  end
end
