defmodule TelaWeb.VersionControllerTest do
  use TelaWeb.ConnCase, async: false

  setup %{conn: conn} do
    csrf_conn = get(conn, "/api/csrf")
    %{"csrf_token" => token} = json_response(csrf_conn, 200)

    {:ok, conn: recycle(csrf_conn) |> put_req_header("x-csrf-token", token)}
  end

  test "creates, lists, reads, and restores a version as a new revision", %{conn: conn} do
    assert %{"design" => %{"id" => design_id, "revision" => 1} = design} =
             post(conn, "/api/designs", %{title: "Histórico", preset_id: "story"})
             |> json_response(201)

    assert %{"version" => %{"id" => version_id, "label" => "Antes"}} =
             post(conn, "/api/designs/#{design_id}/versions", %{label: "Antes"})
             |> json_response(201)

    changed_document = put_in(design["document"], ["meta", "changed"], true)

    assert %{"design" => %{"revision" => 2}} =
             patch(conn, "/api/designs/#{design_id}", %{
               document: changed_document,
               expected_revision: 1
             })
             |> json_response(200)

    assert %{"versions" => [%{"id" => ^version_id}]} =
             get(conn, "/api/designs/#{design_id}/versions") |> json_response(200)

    assert %{"version" => %{"document" => original_document}} =
             get(conn, "/api/designs/#{design_id}/versions/#{version_id}") |> json_response(200)

    assert original_document == design["document"]

    assert %{"design" => %{"revision" => 3, "document" => ^original_document}} =
             post(conn, "/api/designs/#{design_id}/versions/#{version_id}/restore")
             |> json_response(200)
  end

  test "scopes versions to their design", %{conn: conn} do
    assert %{"error" => %{"code" => "not_found"}} =
             get(conn, "/api/designs/#{Ecto.UUID.generate()}/versions/#{Ecto.UUID.generate()}")
             |> json_response(404)
  end
end
