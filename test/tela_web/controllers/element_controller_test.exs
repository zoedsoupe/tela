defmodule TelaWeb.ElementControllerTest do
  use TelaWeb.ConnCase, async: false

  alias Tela.Catalog.Asset
  alias Tela.Repo
  alias TelaWeb.ElementController

  setup do
    Repo.insert!(element("shape-a", 0))
    Repo.insert!(element("shape-b", 1))
    :ok
  end

  test "returns editor element JSON and page links", %{conn: conn} do
    conn = %{conn | request_path: "/api/elements"}
    conn = ElementController.index(conn, %{"page" => "1", "page_size" => "1", "pack" => "shapes"})
    response = json_response(conn, 200)

    assert response["count"] == 2
    assert response["next"] == "/api/elements?pack=shapes&page=2&page_size=1"
    assert response["previous"] == nil
    assert [element] = response["results"]
    assert element["kind"] == "shape"
    assert element["style"] == "filled"
    assert element["pack"] == %{"id" => "shapes", "slug" => "shapes", "name" => "Formas"}
    assert element["tags"] == ["geometria", "teste"]
    assert String.starts_with?(element["svg_url"], "data:image/svg+xml;base64,")
    assert element["width"] == 24
    assert element["height"] == 16
    assert element["colors"] == ["#2255aa"]
    assert element["is_recolorable"]
  end

  test "returns pack license metadata", %{conn: conn} do
    conn = ElementController.packs(conn, %{})
    response = json_response(conn, 200)

    assert [pack] = response
    assert pack["id"] == "shapes"
    assert pack["kind"] == "shape"
    assert pack["element_count"] == 2
    assert pack["license"] == "AGPL-3.0-or-later"
    assert pack["license_url"] == "https://www.gnu.org/licenses/agpl-3.0.html"
    assert pack["attribution"] == "Tela contributors"
    assert pack["source_url"] == "https://github.com/zoedsoupe/tela"
  end

  defp element(slug, order) do
    %Asset{
      slug: slug,
      title_pt: "Forma #{slug}",
      tags_pt: "geometria teste",
      type: "shape",
      file_path: "/assets/catalog/#{slug}.svg",
      pack_slug: "shapes",
      pack_name: "Formas",
      style: "filled",
      svg:
        ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 16"><path fill="#2255aa" d="M0 0h24v16H0z"/></svg>|,
      width: 24,
      height: 16,
      colors: %{values: ["#2255aa"]},
      is_recolorable: true,
      license: "AGPL-3.0-or-later",
      license_url: "https://www.gnu.org/licenses/agpl-3.0.html",
      attribution: "Tela contributors",
      source_url: "https://github.com/zoedsoupe/tela",
      sort_order: order
    }
  end
end
