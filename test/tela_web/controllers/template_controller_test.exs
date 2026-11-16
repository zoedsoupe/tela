defmodule TelaWeb.TemplateControllerTest do
  use TelaWeb.ConnCase, async: false

  alias Tela.Content.Seed

  setup %{conn: conn} do
    assert Seed.seed!() == 10

    csrf_conn = get(conn, "/")

    [_, token] =
      Regex.run(~r/<meta name="csrf-token" content="([^"]+)"/, response(csrf_conn, 200))

    {:ok, conn: recycle(csrf_conn) |> put_req_header("x-csrf-token", token)}
  end

  test "lists categories and template summaries without documents", %{conn: conn} do
    categories = get(conn, "/api/template-categories") |> json_response(200)
    assert %{"slug" => "social-media", "name" => "Redes sociais"} in categories
    assert length(categories) == 8

    assert %{"templates" => templates} = get(conn, "/api/templates") |> json_response(200)
    assert length(templates) == 10

    template = Enum.find(templates, &(&1["slug"] == "serif-quote-card"))
    assert template["title"] == "Cartão de citação serifado"
    assert template["description"]

    assert template["tags"] == [
             "citação",
             "instagram",
             "minimalista",
             "preto",
             "tipografia",
             "inspiração"
           ]

    assert template["use_count"] == 0
    assert template["category"] == %{"slug" => "social-media", "name" => "Redes sociais"}
    assert template["thumbnail_url"] == "/template-assets/thumbs/serif-quote-card.webp"
    refute Map.has_key?(template, "document")
  end

  test "returns a template by slug with its document", %{conn: conn} do
    assert %{"template" => template} =
             get(conn, "/api/templates/modern-pitch-deck") |> json_response(200)

    assert template["slug"] == "modern-pitch-deck"
    assert template["document"]["pages"] != []

    assert template["tags"] == [
             "apresentação",
             "pitch",
             "startup",
             "material de apresentação",
             "negócios",
             "investidor",
             "série A"
           ]

    assert %{"error" => %{"code" => "not_found"}} =
             get(conn, "/api/templates/missing-template") |> json_response(404)
  end

  test "using a template returns a created design and increments its usage", %{conn: conn} do
    assert %{"design" => design} =
             conn
             |> post("/api/templates/serif-quote-card/use")
             |> json_response(201)

    assert design["id"]
    assert design["document"]["pages"] != []

    assert %{"templates" => [template]} =
             get(conn, "/api/templates", %{category: "social-media", search: "serif"})
             |> json_response(200)

    assert template["use_count"] == 1
  end

  test "returns the size preset tree with localized labels", %{conn: conn} do
    assert %{"version" => 1, "groups" => groups} =
             get(conn, "/api/size-presets") |> json_response(200)

    presentations = Enum.find(groups, &(&1["slug"] == "presentation"))
    assert presentations["label"] == "Apresentações"
    assert hd(presentations["children"])["label"] == "Slides para tela"
  end

  test "serves the bundled thumbnail and photo at public content paths", %{conn: conn} do
    thumbnail = get(conn, "/template-assets/thumbs/serif-quote-card.webp")
    assert thumbnail.status == 200
    assert get_resp_header(thumbnail, "content-type") == ["image/webp"]

    photo = get(conn, "/template-assets/photos/rooftop-friends.webp")
    assert photo.status == 200
    assert get_resp_header(photo, "content-type") == ["image/webp"]
  end
end
