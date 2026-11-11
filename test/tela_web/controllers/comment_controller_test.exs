defmodule TelaWeb.CommentControllerTest do
  use TelaWeb.ConnCase, async: false

  alias Tela.Designs
  alias TelaWeb.CommentController

  test "workspace comment endpoints support threads and administration", %{conn: conn} do
    {:ok, design} = Designs.create(%{title: "Comentários", preset_id: "story"})

    created =
      CommentController.create(conn, %{
        "design_id" => design.id,
        "body" => "Ponto importante",
        "page_id" => "page-1",
        "x" => 14,
        "y" => 28
      })

    assert created.status == 201
    root = json_response(created, 201)
    assert root["author_name"] == "Anônimo"
    assert root["x"] == 14

    reply =
      CommentController.create(conn, %{
        "design_id" => design.id,
        "body" => "Concordo",
        "parent_id" => root["id"],
        "author_name" => "Pessoa"
      })

    assert reply.status == 201
    assert json_response(reply, 201)["page_id"] == "page-1"

    listed = json_response(CommentController.index(conn, %{"design_id" => design.id}), 200)

    assert MapSet.new(Enum.map(listed, & &1["id"])) ==
             MapSet.new([root["id"], json_response(reply, 201)["id"]])

    patched = CommentController.update(conn, %{"id" => root["id"], "resolved" => true})
    assert json_response(patched, 200)["resolved"]
    assert CommentController.delete(conn, %{"id" => root["id"]}).status == 204
    assert json_response(CommentController.index(conn, %{"design_id" => design.id}), 200) == []
  end

  test "returns structured validation errors", %{conn: conn} do
    {:ok, design} = Designs.create(%{title: "Comentários", preset_id: "story"})

    response =
      CommentController.create(conn, %{"design_id" => design.id, "body" => "pin", "x" => 1})

    assert response.status == 422

    assert %{"error" => %{"code" => "invalid_anchor", "message" => message}} =
             json_response(response, 422)

    assert is_binary(message)
  end
end
