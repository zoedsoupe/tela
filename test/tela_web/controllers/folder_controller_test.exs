defmodule TelaWeb.FolderControllerTest do
  use TelaWeb.ConnCase, async: false

  setup %{conn: conn} do
    csrf_conn = get(conn, "/")

    [_, token] =
      Regex.run(~r/<meta name="csrf-token" content="([^"]+)"/, response(csrf_conn, 200))

    {:ok, conn: recycle(csrf_conn) |> put_req_header("x-csrf-token", token)}
  end

  test "creates, updates, lists, and deletes nested folders", %{conn: conn} do
    assert %{"folder" => %{"id" => root_id, "name" => "Projetos"}} =
             post(conn, "/api/folders", %{name: "Projetos"}) |> json_response(201)

    assert %{"folder" => %{"id" => child_id, "parent_id" => ^root_id}} =
             post(conn, "/api/folders", %{name: "Campanhas", parent_id: root_id})
             |> json_response(201)

    assert %{"folder" => %{"name" => "Campanhas novas"}} =
             patch(conn, "/api/folders/#{child_id}", %{name: "Campanhas novas"})
             |> json_response(200)

    {:ok, _sibling} = Tela.Designs.create_folder(%{name: "Campanhas novas"})

    assert %{"folders" => folders} = get(conn, "/api/folders") |> json_response(200)
    assert Enum.any?(folders, &(&1["id"] == child_id and &1["parent_id"] == root_id))

    assert response(delete(conn, "/api/folders/#{root_id}"), 204) == ""

    assert %{"folders" => folders} = get(conn, "/api/folders") |> json_response(200)

    assert Enum.any?(folders, fn folder ->
             folder["id"] == child_id and folder["name"] == "Campanhas novas (2)" and
               is_nil(folder["parent_id"])
           end)
  end

  test "rejects cycles, excessive depth, and duplicate sibling names", %{conn: conn} do
    {:ok, root} = Tela.Designs.create_folder(%{name: "Raiz"})
    {:ok, child} = Tela.Designs.create_folder(%{name: "Filha", parent_id: root.id})

    assert %{"error" => %{"code" => "folder_cycle"}} =
             patch(conn, "/api/folders/#{root.id}", %{parent_id: child.id}) |> json_response(422)

    assert %{"error" => %{"code" => "folder_name_taken"}} =
             post(conn, "/api/folders", %{name: "raiz"}) |> json_response(422)

    assert {:ok, level_three} = Tela.Designs.create_folder(%{name: "N3", parent_id: child.id})

    assert {:ok, level_four} =
             Tela.Designs.create_folder(%{name: "N4", parent_id: level_three.id})

    assert {:ok, level_five} = Tela.Designs.create_folder(%{name: "N5", parent_id: level_four.id})

    assert %{"error" => %{"code" => "folder_depth_exceeded"}} =
             post(conn, "/api/folders", %{name: "N6", parent_id: level_five.id})
             |> json_response(422)
  end
end
