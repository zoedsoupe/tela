defmodule TelaWeb.DesignControllerTest do
  use TelaWeb.ConnCase, async: false

  alias Tela.Designs

  setup %{conn: conn} do
    uploads_dir = Path.join("tmp", "design-thumbnails-#{System.unique_integer([:positive])}")
    Application.put_env(:tela, :uploads_dir, uploads_dir)

    on_exit(fn ->
      File.rm_rf(uploads_dir)
      Application.delete_env(:tela, :uploads_dir)
    end)

    csrf_conn = get(conn, "/")

    [_, token] =
      Regex.run(~r/<meta name="csrf-token" content="([^"]+)"/, response(csrf_conn, 200))

    {:ok, conn: recycle(csrf_conn) |> put_req_header("x-csrf-token", token)}
  end

  test "creates designs, lists summaries without documents, and reads details", %{conn: conn} do
    assert %{"design" => %{"id" => id, "revision" => 1, "document" => document}} =
             conn
             |> post("/api/designs", %{title: "Campanha", preset_id: "story"})
             |> json_response(201)

    assert document["unit"] == "px"
    assert document["width"] == 1080

    assert %{"designs" => [%{"id" => ^id} = summary]} =
             get(conn, "/api/designs") |> json_response(200)

    refute Map.has_key?(summary, "document")

    assert %{"design" => %{"id" => ^id, "document" => ^document}} =
             get(conn, "/api/designs/#{id}") |> json_response(200)
  end

  test "saves with optimistic revisions and reports the current revision on conflict", %{
    conn: conn
  } do
    design = create_design(conn)
    document = put_in(design["document"], ["meta", "customField"], "value")

    assert %{"design" => %{"revision" => 2}} =
             patch(conn, "/api/designs/#{design["id"]}", %{
               document: document,
               expected_revision: 1
             })
             |> json_response(200)

    assert %{"error" => %{"code" => "revision_conflict", "current_revision" => 2}} =
             patch(conn, "/api/designs/#{design["id"]}", %{
               document: document,
               expected_revision: 1
             })
             |> json_response(409)
  end

  test "duplicates, trashes, restores, and permanently deletes designs", %{conn: conn} do
    design = create_design(conn)

    assert %{"design" => %{"id" => copy_id, "revision" => 1}} =
             post(conn, "/api/designs/#{design["id"]}/duplicate") |> json_response(201)

    assert copy_id != design["id"]
    assert response(delete(conn, "/api/designs/#{design["id"]}"), 204)
    assert %{"designs" => [%{"id" => ^copy_id}]} = get(conn, "/api/designs") |> json_response(200)

    assert %{"designs" => [%{"id" => id}]} =
             get(conn, "/api/designs?trashed=true") |> json_response(200)

    assert id == design["id"]

    assert %{"design" => %{"trashed_at" => nil}} =
             post(conn, "/api/designs/#{design["id"]}/restore") |> json_response(200)

    assert response(delete(conn, "/api/designs/#{design["id"]}"), 204) == ""
    assert response(delete(conn, "/api/designs/#{design["id"]}?permanent=true"), 204) == ""

    assert %{"error" => %{"code" => "not_found"}} =
             get(conn, "/api/designs/#{design["id"]}") |> json_response(404)
  end

  test "applies bulk actions and empties only the trash cohort", %{conn: conn} do
    first = create_design(conn)
    second = create_design(conn)
    {:ok, folder} = Designs.create_folder(%{name: "Campanhas"})

    assert %{"affected" => 2} =
             post(conn, "/api/designs/bulk", %{
               ids: [first["id"], second["id"]],
               action: "star"
             })
             |> json_response(200)

    assert %{"affected" => 2} =
             post(conn, "/api/designs/bulk", %{
               ids: [first["id"], second["id"]],
               action: "move",
               folder: folder.id
             })
             |> json_response(200)

    assert %{"affected" => 1} =
             conn
             |> put_req_header("content-type", "application/json")
             |> post(
               "/api/designs/bulk",
               JSON.encode!(%{ids: [second["id"]], action: "move", folder: nil})
             )
             |> json_response(200)

    assert response(delete(conn, "/api/designs/#{first["id"]}"), 204)

    assert %{"error" => %{"code" => "design_trashed", "message" => message}} =
             post(conn, "/api/designs/bulk", %{
               ids: [first["id"], second["id"]],
               action: "trash"
             })
             |> json_response(409)

    assert is_binary(message)

    assert %{"affected" => 1} = delete(conn, "/api/designs/trash") |> json_response(200)

    assert %{"error" => %{"code" => "not_found"}} =
             get(conn, "/api/designs/#{first["id"]}") |> json_response(404)

    assert %{"design" => %{"id" => id}} =
             get(conn, "/api/designs/#{second["id"]}") |> json_response(200)

    assert id == second["id"]
  end

  test "returns structured validation errors for bulk input", %{conn: conn} do
    design = create_design(conn)

    assert %{"error" => %{"code" => "invalid_ids", "message" => message}} =
             post(conn, "/api/designs/bulk", %{ids: ["invalid"], action: "star"})
             |> json_response(422)

    assert is_binary(message)

    assert %{"error" => %{"code" => "invalid_folder"}} =
             post(conn, "/api/designs/bulk", %{ids: [design["id"]], action: "move"})
             |> json_response(422)

    assert %{"error" => %{"code" => "invalid_folder"}} =
             post(conn, "/api/designs/bulk", %{
               ids: [design["id"]],
               action: "move",
               folder: "invalid"
             })
             |> json_response(422)

    assert %{"error" => %{"code" => "not_found"}} =
             post(conn, "/api/designs/bulk", %{
               ids: [design["id"]],
               action: "move",
               folder: Ecto.UUID.generate()
             })
             |> json_response(404)

    assert %{"error" => %{"code" => "invalid_action"}} =
             post(conn, "/api/designs/bulk", %{ids: [design["id"]], action: "delete"})
             |> json_response(422)
  end

  test "returns structured validation and not-found errors", %{conn: conn} do
    assert %{"error" => %{"code" => "invalid_document"}} =
             post(conn, "/api/designs", %{document: %{}}) |> json_response(422)

    assert %{"error" => %{"code" => "not_found"}} =
             get(conn, "/api/designs/#{Ecto.UUID.generate()}") |> json_response(404)
  end

  test "stores a browser thumbnail at a safe local path", %{conn: conn} do
    design = create_design(conn)

    path =
      Path.join(System.tmp_dir!(), "tela-thumbnail-#{System.unique_integer([:positive])}.png")

    File.write!(
      path,
      Base.decode64!(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
      )
    )

    on_exit(fn -> File.rm(path) end)

    upload = %Plug.Upload{path: path, filename: "thumbnail.png", content_type: "image/png"}

    assert %{"thumbnail_url" => thumbnail_url} =
             put(conn, "/api/designs/#{design["id"]}/thumbnail", %{image: upload})
             |> json_response(200)

    assert thumbnail_url =~ "/uploads/design-thumbnails/"
    thumbnail_conn = get(conn, thumbnail_url)
    assert response(thumbnail_conn, 200)
    assert get_resp_header(thumbnail_conn, "content-type") == ["image/png"]
  end

  defp create_design(conn) do
    assert %{"design" => design} =
             conn
             |> post("/api/designs", %{title: "Documento", preset_id: "story"})
             |> json_response(201)

    design
  end
end
