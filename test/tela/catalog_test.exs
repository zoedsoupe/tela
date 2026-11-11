defmodule Tela.CatalogTest do
  use Tela.DataCase, async: false
  alias Tela.Catalog
  alias Tela.Catalog.Asset

  setup do
    Repo.query!(
      "INSERT INTO catalog_assets (slug, title_pt, tags_pt, type, file_path) VALUES (?, ?, ?, ?, ?)",
      [
        "heart",
        "Coração Vermelho",
        "amor curtida romance sentimento",
        "icon",
        "/assets/catalog/heart.svg"
      ]
    )

    Repo.query!(
      "INSERT INTO catalog_assets (slug, title_pt, tags_pt, type, file_path) VALUES (?, ?, ?, ?, ?)",
      ["star", "Estrela Amarela", "favorito destaque", "sticker", "/assets/catalog/star.svg"]
    )

    :ok
  end

  test "searches Portuguese assets with or without accents" do
    assert {:ok, accented} = Catalog.search("coração")
    assert {:ok, plain} = Catalog.search("coracao")
    assert Enum.map(accented, & &1.slug) == ["heart"]
    assert Enum.map(plain, & &1.slug) == ["heart"]
  end

  test "searches tags and applies type and limit filters" do
    assert {:ok, [%{slug: "star", type: "sticker"}]} =
             Catalog.search("favorito", %{type: "sticker", limit: 1})

    assert {:ok, []} = Catalog.search("amor", %{type: "sticker", limit: 10})
  end

  test "treats FTS operators as user text" do
    assert {:ok, results} = Catalog.search("coração OR estrela")
    assert Enum.any?(results, &(&1.slug == "heart"))
    assert {:ok, _} = Catalog.search("\" OR *")
  end

  test "paginates and returns the element fields consumed by the editor" do
    Repo.insert!(%Asset{
      slug: "shape-diamond",
      title_pt: "Losango azul",
      tags_pt: "losango geometria azul",
      type: "shape",
      file_path: "/assets/catalog/shape-diamond.svg",
      pack_slug: "shapes",
      pack_name: "Formas",
      style: "filled",
      svg:
        ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 80"><path fill="#3355aa" d="M50 0 100 40 50 80 0 40z"/></svg>|,
      width: 100,
      height: 80,
      colors: %{values: ["#3355aa"]},
      is_recolorable: true,
      license: "AGPL-3.0-or-later",
      license_url: "https://www.gnu.org/licenses/agpl-3.0.html",
      attribution: "Tela contributors",
      source_url: "https://github.com/zoedsoupe/tela",
      sort_order: 1
    })

    assert {:ok, page} =
             Catalog.list_elements(%{
               "q" => "losango",
               "kind" => "shape",
               "style" => "filled",
               "pack" => "shapes",
               "page" => "1",
               "page_size" => "1"
             })

    assert page.count == 1
    assert [element] = Enum.map(page.results, &Catalog.to_api/1)
    assert element.id == "shape-diamond"
    assert element.pack == %{id: "shapes", slug: "shapes", name: "Formas"}
    assert element.tags == ["losango", "geometria", "azul"]
    assert element.svg_url == "data:image/svg+xml;base64," <> Base.encode64(element_svg())
    assert element.width == 100
    assert element.height == 80
    assert element.colors == ["#3355aa"]
    assert element.is_recolorable
  end

  test "lists pack license and attribution metadata" do
    Repo.insert!(%Asset{
      slug: "icon-license-check",
      title_pt: "Ícone de licença",
      tags_pt: "licença",
      type: "icon",
      file_path: "/assets/catalog/icon-license-check.svg",
      pack_slug: "icons",
      pack_name: "Ícones",
      style: "filled",
      svg: "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 10 10\"></svg>",
      width: 10,
      height: 10,
      colors: %{values: []},
      is_recolorable: true,
      license: "AGPL-3.0-or-later",
      license_url: "https://www.gnu.org/licenses/agpl-3.0.html",
      attribution: "Tela contributors",
      source_url: "https://github.com/zoedsoupe/tela",
      sort_order: 1
    })

    assert {:ok, packs} = Catalog.list_packs()
    assert pack = Enum.find(packs, &(&1.id == "icons"))
    assert pack.id == "icons"
    assert pack.kind == "icon"
    assert pack.license == "AGPL-3.0-or-later"
    assert pack.license_url == "https://www.gnu.org/licenses/agpl-3.0.html"
    assert pack.attribution == "Tela contributors"
    assert pack.source_url == "https://github.com/zoedsoupe/tela"
  end

  test "seeds offline elements with complete pack data" do
    assert counts = Tela.Catalog.Seed.seed!()
    assert Enum.sum(Map.values(counts)) == 16

    assert {:ok, packs} = Catalog.list_packs()

    assert %{slug: "icons", name: "Ícones", element_count: 5} =
             pack = Enum.find(packs, &(&1.id == "icons"))

    assert pack.license == "AGPL-3.0-or-later"
    assert pack.attribution == "Tela contributors"
    assert {:ok, [%{slug: "icon-heart", svg: svg}]} = Catalog.search("coracao", %{pack: "icons"})
    assert svg =~ "<svg"
  end

  defp element_svg do
    ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 80"><path fill="#3355aa" d="M50 0 100 40 50 80 0 40z"/></svg>|
  end
end
