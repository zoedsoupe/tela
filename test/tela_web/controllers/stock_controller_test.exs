defmodule TelaWeb.StockControllerTest do
  use TelaWeb.ConnCase, async: false

  import Mox
  import Tela.ProfilesFixtures
  alias Tela.Media.StockResponseCache
  alias Tela.Repo

  setup %{conn: conn} do
    keys = [:http_client, :pexels_api_key, :pixabay_api_key, :unsplash_access_key, :uploads_dir]
    previous = Map.new(keys, &{&1, Application.fetch_env(:tela, &1)})
    root = Path.join("tmp", "stock-controller-#{System.unique_integer([:positive])}")

    Application.put_env(:tela, :http_client, Tela.Media.HTTPClientMock)
    Application.delete_env(:tela, :pexels_api_key)
    Application.delete_env(:tela, :pixabay_api_key)
    Application.delete_env(:tela, :unsplash_access_key)
    Application.put_env(:tela, :uploads_dir, root)
    Repo.delete_all(StockResponseCache)

    on_exit(fn ->
      File.rm_rf(root)

      Enum.each(previous, fn
        {key, {:ok, value}} -> Application.put_env(:tela, key, value)
        {key, :error} -> Application.delete_env(:tela, key)
      end)

      Mox.set_mox_private()
    end)

    csrf_conn = get(conn, "/api/csrf")
    %{"csrf_token" => token} = json_response(csrf_conn, 200)

    {:ok, conn: recycle(csrf_conn) |> put_req_header("x-csrf-token", token)}
  end

  setup :verify_on_exit!

  test "searches stock images and returns the normalized success shape", %{conn: conn} do
    expect(Tela.Media.HTTPClientMock, :get, fn url, _headers, _options ->
      assert url =~ "commons.wikimedia.org"
      assert url =~ "gsroffset=20"

      {:ok,
       %{
         status: 200,
         headers: [],
         body:
           JSON.encode!(%{
             continue: %{gsroffset: 20},
             query: %{pages: [wikimedia_page()]}
           })
       }}
    end)

    assert %{
             "items" => [
               %{
                 "external_id" => "123",
                 "provider" => "wikimedia",
                 "thumb_url" => "https://upload.wikimedia.org/thumb.jpg",
                 "full_url" => "https://upload.wikimedia.org/full.jpg",
                 "author" => "Arquivo"
               }
             ],
             "next_page" => 3,
             "errors" => []
           } =
             conn
             |> get("/api/assets/stock?q=praia&provider=wikimedia&page=2")
             |> json_response(200)
  end

  test "returns partial results and sanitized provider errors", %{conn: conn} do
    Application.put_env(:tela, :pexels_api_key, "pexels-test")
    Mox.set_mox_global()

    expect(Tela.Media.HTTPClientMock, :get, 2, fn url, _headers, _options ->
      cond do
        url =~ "commons.wikimedia.org" ->
          {:ok,
           %{
             status: 200,
             headers: [],
             body: JSON.encode!(%{query: %{pages: [wikimedia_page()]}})
           }}

        url =~ "api.pexels.com" ->
          {:ok, %{status: 503, headers: [], body: "sensitive provider response"}}
      end
    end)

    response =
      conn
      |> get("/api/assets/stock?q=praia&provider=all&page=1")
      |> json_response(200)

    assert [%{"provider" => "wikimedia"}] = response["items"]
    assert response["next_page"] == nil
    assert [%{"provider" => "pexels", "code" => "provider_http_error"}] = response["errors"]
    refute JSON.encode!(response) =~ "sensitive provider response"
  end

  test "omits unconfigured providers from all and reports explicit missing-key errors", %{
    conn: conn
  } do
    Mox.set_mox_global()

    expect(Tela.Media.HTTPClientMock, :get, fn url, _headers, _options ->
      assert url =~ "commons.wikimedia.org"
      {:ok, %{status: 200, headers: [], body: JSON.encode!(%{query: %{pages: []}})}}
    end)

    assert %{"items" => [], "errors" => []} =
             conn
             |> get("/api/assets/stock?q=praia&provider=all")
             |> json_response(200)

    assert %{
             "items" => [],
             "errors" => [%{"provider" => "pixabay", "code" => "missing_api_key"}]
           } =
             conn
             |> recycle()
             |> get("/api/assets/stock?q=praia&provider=pixabay")
             |> json_response(200)
  end

  test "rejects missing queries, unsupported providers, and invalid bounded pages", %{conn: conn} do
    for path <- [
          "/api/assets/stock",
          "/api/assets/stock?q=%20%20",
          "/api/assets/stock?q=praia&provider=other",
          "/api/assets/stock?q=praia&page=0",
          "/api/assets/stock?q=praia&page=1001"
        ] do
      assert %{"error" => %{"code" => "invalid_search"}} =
               conn
               |> recycle()
               |> get(path)
               |> json_response(400)
    end
  end

  test "imports a local provider image and uses the current profile", %{conn: conn} do
    profile = profile_fixture()
    conn = post(conn, "/api/profiles/select", %{profile_id: profile.id}) |> recycle()
    Application.put_env(:tela, :pixabay_api_key, "pixabay-test")

    expect(Tela.Media.HTTPClientMock, :get, fn url, _headers, _options ->
      assert url =~ "pixabay.com/api/"
      assert url =~ "id=123"

      {:ok,
       %{
         status: 200,
         headers: [],
         body:
           JSON.encode!(%{
             hits: [
               %{
                 id: 123,
                 user: "Artista",
                 largeImageURL: "https://pixabay.com/full.jpg"
               }
             ]
           })
       }}
    end)

    expect(Tela.Media.HTTPClientMock, :get, fn "https://pixabay.com/full.jpg",
                                               _headers,
                                               _options ->
      {:ok, %{status: 200, headers: [], body: png()}}
    end)

    assert %{
             "asset" => %{
               "id" => id,
               "kind" => "image",
               "attribution" => %{"provider" => "pixabay", "author" => "Artista"}
             }
           } =
             conn
             |> post("/api/assets/stock/import", %{
               provider: "pixabay",
               external_id: "123"
             })
             |> json_response(200)

    assert {:ok, [upload]} = Tela.Media.list_uploads()
    assert upload.id == id
    assert upload.created_by_id == profile.id
  end

  test "returns an ephemeral Unsplash asset after tracking the selection", %{conn: conn} do
    Application.put_env(:tela, :unsplash_access_key, "unsplash-test")

    expect(Tela.Media.HTTPClientMock, :get, fn url, headers, _options ->
      assert url == "https://api.unsplash.com/photos/photo-123"

      assert {"authorization", "Client-ID unsplash-test"} =
               List.keyfind(headers, "authorization", 0)

      {:ok, %{status: 200, headers: [], body: JSON.encode!(unsplash_photo())}}
    end)

    expect(Tela.Media.HTTPClientMock, :get, fn url, headers, _options ->
      assert url == "https://api.unsplash.com/photos/photo-123/download"

      assert {"authorization", "Client-ID unsplash-test"} =
               List.keyfind(headers, "authorization", 0)

      {:ok, %{status: 200, headers: [], body: "{}"}}
    end)

    assert %{
             "asset" => %{
               "id" => "unsplash:photo-123",
               "kind" => "image",
               "url" => "https://images.unsplash.com/full.jpg",
               "thumb_url" => "https://images.unsplash.com/regular.jpg",
               "width" => 2400,
               "height" => 1600,
               "attribution" => %{
                 "provider" => "unsplash",
                 "author" => "Fotógrafa",
                 "author_url" => author_url,
                 "source_url" => source_url
               }
             }
           } =
             conn
             |> post("/api/assets/stock/import", %{
               provider: "unsplash",
               external_id: "photo-123"
             })
             |> json_response(200)

    assert author_url =~ "utm_source=tela"
    assert source_url =~ "utm_medium=referral"
    assert {:ok, []} = Tela.Media.list_uploads()
  end

  test "returns 404 when the Unsplash photo does not exist", %{conn: conn} do
    Application.put_env(:tela, :unsplash_access_key, "unsplash-test")

    expect(Tela.Media.HTTPClientMock, :get, fn url, headers, _options ->
      assert url == "https://api.unsplash.com/photos/missing-photo"

      assert {"authorization", "Client-ID unsplash-test"} =
               List.keyfind(headers, "authorization", 0)

      {:ok, %{status: 404, headers: [], body: "private provider body"}}
    end)

    response =
      conn
      |> post("/api/assets/stock/import", %{
        provider: "unsplash",
        external_id: "missing-photo"
      })
      |> json_response(404)

    assert %{"error" => %{"code" => "not_found"}} = response
    refute JSON.encode!(response) =~ "private provider body"
  end

  test "maps failed Pixabay image downloads to a 502 download_failed response", %{
    conn: conn
  } do
    Application.put_env(:tela, :pixabay_api_key, "pixabay-test")

    expect(Tela.Media.HTTPClientMock, :get, fn url, _headers, _options ->
      assert url =~ "id=123"

      {:ok,
       %{
         status: 200,
         headers: [],
         body:
           JSON.encode!(%{
             hits: [%{id: 123, user: "Artista", largeImageURL: "https://pixabay.com/full.jpg"}]
           })
       }}
    end)

    expect(Tela.Media.HTTPClientMock, :get, fn "https://pixabay.com/full.jpg",
                                               _headers,
                                               _options ->
      {:ok, %{status: 503, headers: [], body: "private image response"}}
    end)

    response =
      conn
      |> post("/api/assets/stock/import", %{provider: "pixabay", external_id: "123"})
      |> json_response(502)

    assert %{"error" => %{"code" => "download_failed"}} = response
    refute JSON.encode!(response) =~ "private image response"
  end

  test "returns useful import validation and provider errors", %{conn: conn} do
    assert %{"error" => %{"code" => "invalid_external_id"}} =
             conn
             |> post("/api/assets/stock/import", %{provider: "pixabay"})
             |> json_response(400)

    assert %{"error" => %{"code" => "unsupported_provider"}} =
             conn
             |> recycle()
             |> post("/api/assets/stock/import", %{provider: "other", external_id: "123"})
             |> json_response(400)

    Application.put_env(:tela, :pixabay_api_key, "pixabay-test")

    expect(Tela.Media.HTTPClientMock, :get, fn url, _headers, _options ->
      assert url =~ "id=404"
      {:ok, %{status: 200, headers: [], body: JSON.encode!(%{hits: []})}}
    end)

    assert %{"error" => %{"code" => "not_found"}} =
             conn
             |> recycle()
             |> post("/api/assets/stock/import", %{
               provider: "pixabay",
               external_id: "404"
             })
             |> json_response(404)

    expect(Tela.Media.HTTPClientMock, :get, fn _url, _headers, _options ->
      {:ok, %{status: 404, headers: [], body: "private provider body"}}
    end)

    response =
      conn
      |> recycle()
      |> post("/api/assets/stock/import", %{
        provider: "pixabay",
        external_id: "123"
      })
      |> json_response(502)

    assert %{"error" => %{"code" => "provider_http_error"}} = response
    refute JSON.encode!(response) =~ "private provider body"
  end

  defp wikimedia_page do
    %{
      pageid: 123,
      title: "File:Praia.jpg",
      imageinfo: [
        %{
          url: "https://upload.wikimedia.org/full.jpg",
          thumburl: "https://upload.wikimedia.org/thumb.jpg",
          extmetadata: %{Artist: %{value: "Arquivo"}}
        }
      ]
    }
  end

  defp unsplash_photo do
    %{
      id: "photo-123",
      width: 2400,
      height: 1600,
      urls: %{
        regular: "https://images.unsplash.com/regular.jpg",
        full: "https://images.unsplash.com/full.jpg"
      },
      user: %{
        name: "Fotógrafa",
        links: %{html: "https://unsplash.com/@fotografa"}
      },
      links: %{
        html: "https://unsplash.com/photos/photo-123",
        download_location: "https://api.unsplash.com/photos/photo-123/download"
      }
    }
  end

  defp png do
    Base.decode64!(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
    )
  end
end
