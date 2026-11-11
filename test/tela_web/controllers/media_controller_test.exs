defmodule TelaWeb.MediaControllerTest do
  use TelaWeb.ConnCase, async: false

  import Tela.ProfilesFixtures
  alias Tela.Media

  setup do
    root = Path.join("tmp", "served-media-#{System.unique_integer([:positive])}")
    Application.put_env(:tela, :uploads_dir, root)

    on_exit(fn ->
      File.rm_rf(root)
      Application.delete_env(:tela, :uploads_dir)
    end)
  end

  test "serves an uploaded image inline by its workspace id", %{conn: conn} do
    profile = profile_fixture()

    path =
      Path.join(System.tmp_dir!(), "tela-controller-#{System.unique_integer([:positive])}.png")

    File.write!(
      path,
      Base.decode64!(
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
      )
    )

    on_exit(fn -> File.rm(path) end)

    assert {:ok, media} =
             Media.upload(profile.id, %{
               temp_path: path,
               client_name: "pixel.png",
               client_type: "image/png"
             })

    conn = get(conn, ~p"/uploads/#{media.id}")
    assert response(conn, 200)
    assert get_resp_header(conn, "content-type") == ["image/png"]
    assert get_resp_header(conn, "content-disposition") == ["inline; filename=\"pixel.png\""]
  end

  test "does not expose arbitrary files for unknown upload ids", %{conn: conn} do
    assert response(get(conn, "/uploads/#{Ecto.UUID.generate()}"), 404)
  end
end
