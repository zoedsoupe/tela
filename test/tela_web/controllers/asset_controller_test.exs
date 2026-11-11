defmodule TelaWeb.AssetControllerTest do
  use TelaWeb.ConnCase, async: false

  alias TelaWeb.AssetController

  setup do
    root = Path.join("tmp", "asset-controller-#{System.unique_integer([:positive])}")
    previous = Application.get_env(:tela, :uploads_dir)
    Application.put_env(:tela, :uploads_dir, root)

    on_exit(fn ->
      File.rm_rf(root)

      if previous,
        do: Application.put_env(:tela, :uploads_dir, previous),
        else: Application.delete_env(:tela, :uploads_dir)
    end)

    :ok
  end

  test "creates, lists, and deletes a workspace asset", %{conn: conn} do
    path = temporary_png()
    upload = %Plug.Upload{path: path, filename: "pixel.png", content_type: "image/png"}
    created = AssetController.create(conn, %{"file" => upload})
    assert created.status == 201
    asset = json_response(created, 201)
    assert asset["kind"] == "image"
    assert asset["url"] == "/uploads/#{asset["id"]}"
    assert asset["width"] == 1

    listed = AssetController.index(conn, %{})
    assert [listed_asset] = json_response(listed, 200)
    assert listed_asset["id"] == asset["id"]

    assert AssetController.delete(conn, %{"id" => asset["id"]}).status == 204
    assert json_response(AssetController.index(conn, %{}), 200) == []
  end

  test "returns consistent JSON errors for unsupported and missing assets", %{conn: conn} do
    response = AssetController.create(conn, %{})
    assert response.status == 422

    assert %{"error" => %{"code" => "invalid_upload", "message" => message}} =
             json_response(response, 422)

    assert is_binary(message)

    missing = AssetController.delete(conn, %{"id" => Ecto.UUID.generate()})
    assert missing.status == 404
    assert %{"error" => %{"code" => "not_found"}} = json_response(missing, 404)
  end

  defp temporary_png do
    path = Path.join(System.tmp_dir!(), "tela-asset-#{System.unique_integer([:positive])}.png")

    File.write!(
      path,
      Base.decode64!(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
      )
    )

    on_exit(fn -> File.rm(path) end)
    path
  end
end
