defmodule TelaWeb.FontControllerTest do
  use TelaWeb.ConnCase, async: false

  alias Tela.Fonts
  alias TelaWeb.FontController

  setup do
    uploads_dir = Path.join(System.tmp_dir!(), "tela-font-controller-#{Ecto.UUID.generate()}")
    previous_uploads_dir = Application.get_env(:tela, :uploads_dir)
    Application.put_env(:tela, :uploads_dir, uploads_dir)
    Fonts.Seed.seed!()

    on_exit(fn ->
      if previous_uploads_dir do
        Application.put_env(:tela, :uploads_dir, previous_uploads_dir)
      else
        Application.delete_env(:tela, :uploads_dir)
      end

      File.rm_rf!(uploads_dir)
    end)

    {:ok, uploads_dir: uploads_dir}
  end

  test "lists font family JSON with pagination", %{conn: conn} do
    conn = %{conn | request_path: "/api/fonts"}
    conn = FontController.index(conn, %{"page" => "1", "page_size" => "1"})
    response = json_response(conn, 200)

    assert response["count"] == 12
    assert response["next"] == "/api/fonts?page=2&page_size=1"
    assert response["previous"] == nil
    assert [font] = response["results"]
    assert font["family"] == "Arial"
    assert font["category"] == "sans-serif"
    assert font["scripts"] == ["latin"]
    assert font["is_variable"] == false
    assert font["is_user_font"] == false
    assert font["variants"] == []
    assert font["popularity"] == 1
  end

  test "uploads a shared font and serves its stored file", %{conn: conn, uploads_dir: uploads_dir} do
    temp_path = Path.join(System.tmp_dir!(), "font-controller-upload-#{Ecto.UUID.generate()}")
    File.write!(temp_path, "wOFFcontroller font")
    on_exit(fn -> File.rm(temp_path) end)

    upload = %Plug.Upload{
      path: temp_path,
      filename: "Display-Regular.woff",
      content_type: "font/woff"
    }

    conn = FontController.create(conn, %{"files" => [upload], "category" => "display"})
    body = json_response(conn, 201)

    assert body["family"] == "Display"
    assert body["category"] == "display"
    assert body["is_user_font"]
    assert [variant] = body["variants"]
    assert variant["weight"] == 400
    assert variant["style"] == "normal"
    assert variant["url"] =~ "/api/fonts/files/"

    [file_id] =
      Regex.run(~r{/api/fonts/files/([0-9a-f-]+)}, variant["url"], capture: :all_but_first)

    assert {:ok, file_path, "font/woff"} = Fonts.get_file(file_id)
    assert String.starts_with?(file_path, Path.join(uploads_dir, "fonts"))

    file_conn = FontController.file(build_conn(), %{"id" => file_id})
    assert response(file_conn, 200) == "wOFFcontroller font"

    delete_conn = FontController.delete(build_conn(), %{"id" => body["id"]})
    assert response(delete_conn, 204) == ""
  end

  test "reports invalid font uploads in Portuguese", %{conn: conn} do
    temp_path = Path.join(System.tmp_dir!(), "invalid-font-upload-#{Ecto.UUID.generate()}")
    File.write!(temp_path, "bad!")
    on_exit(fn -> File.rm(temp_path) end)

    upload = %Plug.Upload{path: temp_path, filename: "Broken.woff2", content_type: "font/woff2"}
    conn = FontController.create(conn, %{"files" => [upload]})
    response = json_response(conn, 422)

    assert response["error"]["code"] == "invalid_font_file"
    assert response["error"]["message"] =~ "Envie um arquivo WOFF"
  end
end
