defmodule Tela.MediaExternalTest do
  use Tela.DataCase, async: false
  import Mox
  import Tela.ProfilesFixtures
  alias Tela.Media
  alias Tela.Media.StockResponseCache
  alias Tela.Repo

  @photo %{
    id: 123,
    photographer: "Fotógrafa Brasileira",
    src: %{
      original: "https://images.pexels.com/full.jpg",
      medium: "https://images.pexels.com/thumb.jpg"
    }
  }

  setup do
    root = Path.join("tmp", "external-media-#{System.unique_integer([:positive])}")
    Application.put_env(:tela, :http_client, Tela.Media.HTTPClientMock)
    Application.put_env(:tela, :pexels_api_key, "test-key")
    Application.delete_env(:tela, :pixabay_api_key)
    Application.delete_env(:tela, :unsplash_access_key)
    Application.put_env(:tela, :uploads_dir, root)
    Repo.delete_all(StockResponseCache)

    on_exit(fn ->
      File.rm_rf(root)
      Application.delete_env(:tela, :http_client)
      Application.delete_env(:tela, :pexels_api_key)
      Application.delete_env(:tela, :pixabay_api_key)
      Application.delete_env(:tela, :unsplash_access_key)
      Application.delete_env(:tela, :uploads_dir)
      Mox.set_mox_private()
    end)

    %{profile: profile_fixture()}
  end

  setup :verify_on_exit!

  test "normalizes Pexels search results", %{profile: _profile} do
    expect(Tela.Media.HTTPClientMock, :get, fn url, headers, _options ->
      assert url =~ "api.pexels.com"
      assert url =~ "praia"
      assert {"authorization", "test-key"} = List.keyfind(headers, "authorization", 0)
      {:ok, %{status: 200, headers: [], body: JSON.encode!(%{photos: [@photo]})}}
    end)

    assert {:ok, %{items: [photo], next_page: 2, errors: []}} =
             Media.search_external("praia", :pexels, 1)

    assert photo.external_id == "123"
    assert photo.provider == :pexels
    assert photo.thumb_url == "https://images.pexels.com/thumb.jpg"
    assert photo.full_url == "https://images.pexels.com/full.jpg"
    assert photo.author == "Fotógrafa Brasileira"
  end

  test "keeps successful providers when other providers are unavailable" do
    Mox.set_mox_global()
    Application.delete_env(:tela, :pexels_api_key)

    expect(Tela.Media.HTTPClientMock, :get, fn url, _headers, _options ->
      assert url =~ "commons.wikimedia.org"

      body =
        JSON.encode!(%{
          query: %{
            pages: [
              %{
                pageid: 456,
                title: "File:Praia.jpg",
                imageinfo: [
                  %{
                    url: "https://upload.wikimedia.org/praia.jpg",
                    thumburl: "https://upload.wikimedia.org/thumb.jpg"
                  }
                ]
              }
            ]
          }
        })

      {:ok, %{status: 200, headers: [], body: body}}
    end)

    assert {:ok, %{items: [item], errors: errors}} = Media.search_external("praia", :all, 1)
    assert item.provider == :wikimedia
    assert errors == []
  end

  test "normalizes Pixabay vectors and resolves their vector URL" do
    Application.put_env(:tela, :pixabay_api_key, "pixabay-test")

    vector = %{
      id: 456,
      user: "Artista",
      vectorURL: "https://pixabay.com/vector.svg",
      previewURL: "https://pixabay.com/vector-preview.png"
    }

    expect(Tela.Media.HTTPClientMock, :get, fn url, _headers, _options ->
      assert url =~ "image_type=all"
      assert url =~ "q=vector"
      {:ok, %{status: 200, headers: [], body: JSON.encode!(%{hits: [vector], totalHits: 1})}}
    end)

    assert {:ok, %{items: [item]}} = Media.search_external("vector", :pixabay, 1)
    assert item.full_url == "https://pixabay.com/vector.svg"

    expect(Tela.Media.HTTPClientMock, :get, fn url, _headers, _options ->
      assert url =~ "image_type=all"
      assert url =~ "id=456"

      {:ok,
       %{
         status: 200,
         headers: [],
         body: JSON.encode!(%{hits: [Map.drop(vector, [:previewURL])]})
       }}
    end)

    assert {:ok, %{url: "https://pixabay.com/vector.svg"}} =
             Tela.Media.StockProvider.Pixabay.resolve("456")
  end

  test "caches successful Pixabay search and resolve responses for 24 hours" do
    Application.put_env(:tela, :pixabay_api_key, "pixabay-test")

    expect(Tela.Media.HTTPClientMock, :get, fn url, _headers, _options ->
      assert url =~ "q=Vector"
      assert url =~ "image_type=all"

      {:ok,
       %{
         status: 200,
         headers: [],
         body:
           JSON.encode!(%{
             hits: [
               %{
                 id: 456,
                 user: "Artista",
                 largeImageURL: "https://pixabay.com/vector.png",
                 previewURL: "https://pixabay.com/vector-thumb.png"
               }
             ],
             totalHits: 1
           })
       }}
    end)

    assert {:ok, %{items: [first_search_item]}} =
             Media.search_external("  Vector ", :pixabay, 1)

    assert {:ok, %{items: [second_search_item]}} =
             Media.search_external("vector", :pixabay, 1)

    assert second_search_item == first_search_item

    expect(Tela.Media.HTTPClientMock, :get, fn url, _headers, _options ->
      assert url =~ "id=456"
      assert url =~ "image_type=all"

      {:ok,
       %{
         status: 200,
         headers: [],
         body:
           JSON.encode!(%{
             hits: [%{id: 456, user: "Artista", largeImageURL: "https://pixabay.com/vector.png"}]
           })
       }}
    end)

    assert {:ok, first_photo} = Tela.Media.StockProvider.Pixabay.resolve("456")
    assert {:ok, ^first_photo} = Tela.Media.StockProvider.Pixabay.resolve("456")

    caches = Repo.all(StockResponseCache)
    assert length(caches) == 2
    search_cache = Enum.find(caches, &String.starts_with?(&1.cache_key, "search:"))
    resolve_cache = Enum.find(caches, &String.starts_with?(&1.cache_key, "resolve:"))
    assert search_cache
    assert resolve_cache

    for cache <- [search_cache, resolve_cache] do
      assert DateTime.diff(cache.expires_at, cache.inserted_at, :second) in 86_399..86_401
      assert cache.provider == "pixabay"
      refute cache.cache_key =~ "pixabay-test"
      refute cache.response_body =~ "pixabay-test"
    end

    assert search_cache.cache_key ==
             "search:" <>
               URI.encode_query(%{q: "vector", page: 1, image_type: "all"})

    assert resolve_cache.cache_key ==
             "resolve:" <> URI.encode_query(%{id: "456", image_type: "all"})
  end

  test "expires Pixabay cache entries before fetching again" do
    Application.put_env(:tela, :pixabay_api_key, "pixabay-test")

    response = %{
      hits: [
        %{
          id: 789,
          user: "Artista",
          largeImageURL: "https://pixabay.com/image.png",
          previewURL: "https://pixabay.com/thumb.png"
        }
      ],
      totalHits: 1
    }

    expect(Tela.Media.HTTPClientMock, :get, 2, fn _url, _headers, _options ->
      {:ok, %{status: 200, headers: [], body: JSON.encode!(response)}}
    end)

    assert {:ok, _result} = Media.search_external("expiring", :pixabay, 1)
    assert [entry] = Repo.all(StockResponseCache)

    expired_at = DateTime.utc_now() |> DateTime.add(-1, :second) |> DateTime.truncate(:second)

    assert {:ok, _entry} =
             Repo.update(StockResponseCache.changeset(entry, %{expires_at: expired_at}))

    assert {:ok, _result} = Media.search_external("expiring", :pixabay, 1)
    assert [replacement] = Repo.all(StockResponseCache)
    assert DateTime.compare(replacement.expires_at, DateTime.utc_now()) == :gt
  end

  test "searches Unsplash and adds referral attribution links" do
    Application.put_env(:tela, :unsplash_access_key, "unsplash-test")

    expect(Tela.Media.HTTPClientMock, :get, fn url, headers, _options ->
      assert url =~ "api.unsplash.com/search/photos"
      assert url =~ "per_page=20"

      assert {"authorization", "Client-ID unsplash-test"} =
               List.keyfind(headers, "authorization", 0)

      {:ok,
       %{
         status: 200,
         headers: [],
         body: JSON.encode!(%{results: [unsplash_photo()], total_pages: 2})
       }}
    end)

    assert {:ok, %{items: [item], next_page: 2}} =
             Media.search_external("praia", :unsplash, 1)

    assert item.provider == :unsplash
    assert item.external_id == "unsplash-photo-1"
    assert item.thumb_url == "https://images.unsplash.com/regular.jpg"
    assert item.full_url == "https://images.unsplash.com/full.jpg"
    assert item.author == "Fotógrafa"
    assert item.author_url =~ "utm_source=tela"
    assert item.author_url =~ "utm_medium=referral"
    assert item.source_url =~ "utm_source=tela"
    assert item.source_url =~ "utm_medium=referral"
  end

  test "drops Unsplash search results without both attribution links" do
    Application.put_env(:tela, :unsplash_access_key, "unsplash-test")
    missing_photographer_link = put_in(unsplash_photo(), [:user, :links], %{})
    missing_photo_link = put_in(unsplash_photo(), [:links, :html], nil)

    expect(Tela.Media.HTTPClientMock, :get, fn _url, _headers, _options ->
      {:ok,
       %{
         status: 200,
         headers: [],
         body:
           JSON.encode!(%{
             results: [missing_photographer_link, missing_photo_link],
             total_pages: 1
           })
       }}
    end)

    assert {:ok, %{items: [], next_page: nil}} =
             Media.search_external("praia", :unsplash, 1)
  end

  test "selects Unsplash by tracking the download without storing a local upload" do
    Application.put_env(:tela, :unsplash_access_key, "unsplash-test")
    profile = profile_fixture()

    expect(Tela.Media.HTTPClientMock, :get, fn url, headers, _options ->
      assert url == "https://api.unsplash.com/photos/unsplash-photo-1"

      assert {"authorization", "Client-ID unsplash-test"} =
               List.keyfind(headers, "authorization", 0)

      {:ok, %{status: 200, headers: [], body: JSON.encode!(unsplash_photo())}}
    end)

    expect(Tela.Media.HTTPClientMock, :get, fn url, headers, _options ->
      assert url == "https://api.unsplash.com/photos/unsplash-photo-1/download"

      assert {"authorization", "Client-ID unsplash-test"} =
               List.keyfind(headers, "authorization", 0)

      {:ok, %{status: 200, headers: [], body: "{}"}}
    end)

    assert {:ok, asset} = Media.select_external(profile.id, :unsplash, "unsplash-photo-1")
    assert asset.id == "unsplash:unsplash-photo-1"
    assert asset.url == "https://images.unsplash.com/full.jpg"
    assert asset.thumb_url == "https://images.unsplash.com/regular.jpg"
    assert asset.width == 2400
    assert asset.height == 1600
    assert asset.attribution.author == "Fotógrafa"
    assert asset.attribution.author_url =~ "utm_source=tela"
    assert asset.attribution.source_url =~ "utm_medium=referral"

    assert {:ok, []} = Media.list_uploads()

    assert {:error, :hotlinked_provider} =
             Media.import_external(profile.id, :unsplash, "unsplash-photo-1")
  end

  test "rejects Unsplash image URLs outside the image host allowlist" do
    Application.put_env(:tela, :unsplash_access_key, "unsplash-test")
    photo = put_in(unsplash_photo(), [:urls, :full], "https://example.com/full.jpg")
    photo = put_in(photo, [:urls, :raw], "https://example.com/raw.jpg")

    expect(Tela.Media.HTTPClientMock, :get, fn _url, _headers, _options ->
      {:ok, %{status: 200, headers: [], body: JSON.encode!(photo)}}
    end)

    assert {:error, :invalid_provider_response} =
             Media.select_external(nil, :unsplash, "unsplash-photo-1")

    assert {:ok, []} = Media.list_uploads()
  end

  test "rejects a resolved download outside the provider allowlist", %{profile: profile} do
    photo = put_in(@photo, [:src, :original], "https://example.com/not-pexels.jpg")

    expect(Tela.Media.HTTPClientMock, :get, fn _url, _headers, _options ->
      {:ok, %{status: 200, headers: [], body: JSON.encode!(photo)}}
    end)

    assert {:error, :invalid_download_url} = Media.import_external(profile.id, :pexels, "123")
    assert {:ok, []} = Media.list_uploads()
  end

  test "resolves, downloads, and caches an external photo", %{profile: profile} do
    expect(Tela.Media.HTTPClientMock, :get, fn url, _headers, _options ->
      assert url =~ "/v1/photos/123"
      {:ok, %{status: 200, headers: [], body: JSON.encode!(@photo)}}
    end)

    expect(Tela.Media.HTTPClientMock, :get, fn "https://images.pexels.com/full.jpg",
                                               _headers,
                                               _options ->
      {:ok, %{status: 200, headers: [], body: png()}}
    end)

    assert {:ok, media} = Media.import_external(profile.id, :pexels, "123")
    assert media.source == "pexels"
    assert media.external_id == "123"
    assert media.attribution == "Fotógrafa Brasileira"
    assert media.content_type == "image/png"
    assert media.width == 1
    assert File.exists?(media.storage_path)

    assert {:ok, cached} = Media.import_external(profile.id, :pexels, "123")
    assert cached.id == media.id
  end

  defp png do
    Base.decode64!(
      "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
    )
  end

  defp unsplash_photo do
    %{
      id: "unsplash-photo-1",
      width: 2400,
      height: 1600,
      urls: %{
        regular: "https://images.unsplash.com/regular.jpg",
        full: "https://images.unsplash.com/full.jpg",
        raw: "https://images.unsplash.com/raw.jpg"
      },
      user: %{
        name: "Fotógrafa",
        links: %{html: "https://unsplash.com/@fotografa"}
      },
      links: %{
        html: "https://unsplash.com/photos/unsplash-photo-1",
        download_location: "https://api.unsplash.com/photos/unsplash-photo-1/download"
      }
    }
  end
end
