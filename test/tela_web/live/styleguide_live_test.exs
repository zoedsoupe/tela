defmodule TelaWeb.StyleguideLiveTest do
  use TelaWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  test "renders semantic foundations and component examples", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/dev/styleguide")
    assert has_element?(view, "#tokens-heading")
    assert has_element?(view, "#actions-heading")
    assert has_element?(view, "#forms-heading")
    assert has_element?(view, "#overlays-heading")
  end
end
