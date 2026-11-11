defmodule TelaWeb.MediaRangeControllerTest do
  use TelaWeb.ConnCase, async: false

  import Ecto.Query
  alias Tela.Media
  alias Tela.Media.MediaUpload
  alias Tela.Media.Storage.Local
  alias Tela.Repo
  alias TelaWeb.MediaController

  setup do
    root = Path.join("tmp", "media-range-#{System.unique_integer([:positive])}")
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

  test "sends a single byte range using sendfile headers", %{conn: conn} do
    upload = create_video()

    conn =
      conn |> put_req_header("range", "bytes=3-7") |> MediaController.show(%{"id" => upload.id})

    assert conn.status == 206
    assert get_resp_header(conn, "accept-ranges") == ["bytes"]
    assert get_resp_header(conn, "content-range") == ["bytes 3-7/#{upload.byte_size}"]
    assert get_resp_header(conn, "content-length") == ["5"]
    assert conn.resp_body == binary_part(video_body(), 3, 5)
  end

  test "supports suffix ranges and clips an end past the file size", %{conn: conn} do
    upload = create_video()

    suffix =
      conn |> put_req_header("range", "bytes=-4") |> MediaController.show(%{"id" => upload.id})

    assert suffix.status == 206

    assert suffix.resp_body ==
             binary_part(video_body(), byte_size(video_body()) - 4, 4)

    clipped =
      conn
      |> put_req_header("range", "bytes=2-9999")
      |> MediaController.show(%{"id" => upload.id})

    assert clipped.status == 206

    assert get_resp_header(clipped, "content-range") == [
             "bytes 2-#{upload.byte_size - 1}/#{upload.byte_size}"
           ]
  end

  test "rejects unsatisfiable and multi-range requests", %{conn: conn} do
    upload = create_video()

    for header <- ["bytes=#{upload.byte_size}-", "bytes=0-1,3-4", "bytes=-0", "items=0-1"] do
      response =
        conn |> put_req_header("range", header) |> MediaController.show(%{"id" => upload.id})

      assert response.status == 416
      assert get_resp_header(response, "content-range") == ["bytes */#{upload.byte_size}"]
      assert get_resp_header(response, "accept-ranges") == ["bytes"]
      assert %{"error" => %{"code" => "invalid_range"}} = json_response(response, 416)
    end
  end

  test "answers HEAD without returning the file body", %{conn: conn} do
    upload = create_video()
    conn = %{conn | method: "HEAD"} |> MediaController.show(%{"id" => upload.id})

    assert conn.status == 200
    assert conn.resp_body == ""
    assert get_resp_header(conn, "content-length") == [Integer.to_string(upload.byte_size)]
    assert get_resp_header(conn, "accept-ranges") == ["bytes"]
  end

  test "does not serve paths outside the upload directory", %{conn: conn} do
    upload = create_video()
    path = Path.join(System.tmp_dir!(), "tela-path-traversal-target")
    File.write!(path, "secret")
    on_exit(fn -> File.rm(path) end)

    Repo.update_all(from(media in MediaUpload, where: media.id == ^upload.id),
      set: [storage_path: path]
    )

    assert MediaController.show(conn, %{"id" => upload.id}).status == 404
    refute Local.regular_file?(path)
  end

  defp create_video do
    path = Path.join(System.tmp_dir!(), "tela-range-#{System.unique_integer([:positive])}.mp4")
    File.write!(path, video_body())
    on_exit(fn -> File.rm(path) end)

    {:ok, upload} =
      Media.upload(nil, %{
        temp_path: path,
        client_name: "clip.mp4",
        content_type: "video/mp4",
        kind: "video"
      })

    upload
  end

  defp video_body do
    <<32::unsigned-big-32, "ftyp", "isom", 0, 0, 2, 0, "isomiso2payload">>
  end
end
