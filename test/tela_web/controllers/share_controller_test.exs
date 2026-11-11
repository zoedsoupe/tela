defmodule TelaWeb.ShareControllerTest do
  use TelaWeb.ConnCase, async: false

  alias Tela.Designs
  alias TelaWeb.ShareController
  alias TelaWeb.SharedController

  test "workspace share-link endpoints create, change role, and revoke", %{conn: conn} do
    {:ok, design} = Designs.create(%{title: "Link", preset_id: "story"})
    created = ShareController.create(conn, %{"design_id" => design.id, "role" => "comment"})
    assert created.status == 201
    body = json_response(created, 201)
    assert body["role"] == "comment"
    assert is_binary(body["token"])
    assert body["url"] == "/s/#{body["token"]}"

    list = json_response(ShareController.index(conn, %{"design_id" => design.id}), 200)
    assert [%{"id" => id, "token" => listed_token, "is_active" => true}] = list
    assert id == body["id"]
    assert listed_token == body["token"]

    updated = ShareController.update(conn, %{"id" => body["id"], "role" => "edit"})
    assert json_response(updated, 200)["role"] == "edit"
    assert ShareController.delete(conn, %{"id" => body["id"]}).status == 204

    unavailable = SharedController.show(conn, %{"token" => body["token"]})
    assert unavailable.status == 404
    assert %{"error" => %{"code" => "not_found"}} = json_response(unavailable, 404)
  end

  test "rejects unsupported roles using the common error envelope", %{conn: conn} do
    {:ok, design} = Designs.create(%{title: "Role", preset_id: "story"})
    response = ShareController.create(conn, %{"design_id" => design.id, "role" => "admin"})

    assert response.status == 422

    assert %{"error" => %{"code" => "invalid_role", "message" => message}} =
             json_response(response, 422)

    assert is_binary(message)
  end
end
