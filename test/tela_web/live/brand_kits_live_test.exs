defmodule TelaWeb.BrandKitsLiveTest do
  use TelaWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import Tela.ProfilesFixtures
  alias Tela.Brands

  setup do
    %{profile: profile_fixture()}
  end

  test "creates a shared brand kit with colors and typography", %{conn: conn, profile: profile} do
    {:ok, view, _html} = live(conn, ~p"/brand-kits")
    assert has_element?(view, "#brand-kit-form")

    view
    |> form("#brand-kit-form",
      brand: %{
        name: "Feira de domingo",
        colors: "#A94330, #3859A8",
        heading_font: "Instrument Serif",
        body_font: "DM Sans"
      }
    )
    |> render_submit()

    assert has_element?(view, "[data-brand-kit-name='Feira de domingo']")
    assert {:ok, [kit]} = Brands.list_kits()
    assert kit.created_by_id == profile.id
    assert kit.colors == %{"values" => ["#A94330", "#3859A8"]}
    assert kit.fonts == %{"heading" => "Instrument Serif", "body" => "DM Sans"}
  end

  test "validates colors before saving", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/brand-kits")

    view
    |> form("#brand-kit-form",
      brand: %{
        name: "Inválida",
        colors: "coral",
        heading_font: "Instrument Serif",
        body_font: "DM Sans"
      }
    )
    |> render_submit()

    assert has_element?(view, "#brand-kit-colors-error")
    assert {:ok, []} = Brands.list_kits()
  end
end
