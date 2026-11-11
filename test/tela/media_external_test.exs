defmodule Tela.MediaExternalTest do
  use Tela.DataCase, async: false
  import Mox
  import Tela.ProfilesFixtures
  alias Tela.Media

  @photo %{
    id: 123,
    photographer: "Fotógrafa Brasileira",
    src: %{original: "https://images.pexels.com/full.jpg", medium: "https://images.pexels.com/thumb.jpg"}
  }

  setup :verify_on_exit!

  setup do
    root = Path.join("tmp", "external-media-#{System.unique_integer([:positive])}")
    Application.put_env(:tela, :http_client, Tela.Media.HTTPClientMock)
    Application.put_env(:tela, :pexels_api_key, "test-key")
    Application.put_env(:tela, :uploads_dir, root)
    on_exit(fn ->
      File.rm_rf(root)
      Application.delete_env(:tela, :http_client)
      Application.delete_env(:tela, :pexels_api_key)
      Application.delete_env(:tela, :uploads_dir)
    end)
    %{profile: profile_fixture()}
  end

  test "normalizes Pexels search results", %{profile: _profile} do
    expect(Tela.Media.HTTPClientMock, :get, fn url, headers, _options ->
      assert url =~ "api.pexels.com"
      assert url =~ "praia"
      assert {"authorization", "test-key"} = List.keyfind(headers, "authorization", 0)
      {:ok, %{status: 200, headers: [], body: JSON.encode!(%{photos: [@photo]})}}
    end)

    assert {:ok, %{items: [photo], next_page: 2, errors: []}} = Media.search_external("praia", :pexels, 1)
    assert photo.external_id == "123"
    assert photo.provider == :pexels
    assert photo.thumb_url == "https://images.pexels.com/thumb.jpg"
    assert photo.full_url == "https://images.pexels.com/full.jpg"
    assert photo.author == "Fotógrafa Brasileira"
  end

  test "resolves, downloads, and caches an external photo", %{profile: profile} do
    expect(Tela.Media.HTTPClientMock, :get, fn url, _headers, _options ->
      assert url =~ "/v1/photos/123"
      {:ok, %{status: 200, headers: [], body: JSON.encode!(@photo)}}
    end)

    expect(Tela.Media.HTTPClientMock, :get, fn "https://images.pexels.com/full.jpg", _headers, _options ->
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
    Base.decode64!("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=")
  end
end
