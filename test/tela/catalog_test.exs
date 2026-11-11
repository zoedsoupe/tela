defmodule Tela.CatalogTest do
  use Tela.DataCase, async: false
  alias Tela.Catalog

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
end
