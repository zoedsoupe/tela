defmodule TelaWeb.EditorLiveTest do
  use TelaWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import Tela.ProfilesFixtures
  alias Tela.Designs

  setup do
    profile = profile_fixture()

    {:ok, design} =
      Designs.create(%{created_by_id: profile.id, title: "Editor", preset_id: "post-instagram"})

    %{design: design}
  end

  test "renders an isolated editor island and animation/export controls", %{
    conn: conn,
    design: design
  } do
    {:ok, view, _html} = live(conn, ~p"/designs/#{design.id}")
    assert has_element?(view, "#fabric-canvas[phx-hook='FabricCanvas'][phx-update='ignore']")
    assert has_element?(view, "#editor-title", design.title)
    assert has_element?(view, "#editor-animate")
    assert has_element?(view, "#editor-export")
    assert has_element?(view, "#editor-save-status")
  end

  test "initializes the hook only after it is ready", %{conn: conn, design: design} do
    {:ok, view, _html} = live(conn, ~p"/designs/#{design.id}")
    render_hook(view, "editor:ready")
    assert_push_event(view, "canvas:init", %{document: document, revision: 1})
    assert document["schemaVersion"] == 1
  end

  test "saves through the context and replies with the new revision", %{
    conn: conn,
    design: design
  } do
    {:ok, view, _html} = live(conn, ~p"/designs/#{design.id}")

    document =
      put_in(design.document, ["pages", Access.at(0), "objects"], [
        %{"id" => "title", "type" => "textbox", "text" => "Tela"}
      ])

    render_hook(view, "design:save", %{"document" => document, "expected_revision" => 1})
    assert_reply view, %{status: "saved", revision: 2}
    assert {:ok, saved} = Designs.get(design.id)
    assert saved.document == document
  end

  test "exposes animation controls and forwards animation and presentation commands", %{conn: conn, design: design} do
    {:ok, view, _html} = live(conn, ~p"/designs/#{design.id}")
    render_click(view, "editor:toggle-animation")
    assert has_element?(view, "#editor-animation-panel")
    assert has_element?(view, "#animation-enter-fade")
    assert has_element?(view, "#animation-play")

    render_hook(view, "editor:selection_changed", %{"selection" => %{"id" => "title", "type" => "textbox"}})
    render_hook(view, "canvas:animation_action", %{"action" => "set", "slot" => "enter", "preset" => "fade"})
    assert_push_event(view, "canvas:animation_action", %{action: "set", slot: "enter", preset: "fade"})
    render_hook(view, "canvas:present", %{"pages" => "all"})
    assert_push_event(view, "canvas:present", %{pages: "all"})
  end

  test "returns a conflict status for stale saves", %{conn: conn, design: design} do
    {:ok, view, _html} = live(conn, ~p"/designs/#{design.id}")
    document = design.document

    render_hook(view, "design:save", %{"document" => document, "expected_revision" => 1})
    assert_reply view, %{status: "saved", revision: 2}
    render_hook(view, "design:save", %{"document" => document, "expected_revision" => 1})
    assert_reply view, %{status: "conflict", revision: 2}
  end
end
