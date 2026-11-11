defmodule Tela.MediaTest do
  use Tela.DataCase, async: false
  import Tela.ProfilesFixtures
  alias Tela.Media

  setup do
    root = Path.join("tmp", "media-contract-#{System.unique_integer([:positive])}")
    previous = Application.get_env(:tela, :uploads_dir)
    Application.put_env(:tela, :uploads_dir, root)

    on_exit(fn ->
      File.rm_rf(root)

      if previous,
        do: Application.put_env(:tela, :uploads_dir, previous),
        else: Application.delete_env(:tela, :uploads_dir)
    end)

    %{profile: profile_fixture()}
  end

  test "stores a valid PNG and lists it for the shared workspace", %{profile: profile} do
    path = temporary_png()

    assert {:ok, media} =
             Media.upload(profile.id, %{
               temp_path: path,
               client_name: "pixel.png",
               content_type: "image/png"
             })

    assert media.created_by_id == profile.id
    assert media.source == "upload"
    assert media.content_type == "image/png"
    assert media.byte_size > 0
    assert media.width == 1
    assert media.height == 1
    assert File.exists?(media.storage_path)
    assert {:ok, [listed]} = Media.list_uploads()
    assert listed.id == media.id
  end

  test "rejects content spoofing instead of trusting the client MIME", %{profile: profile} do
    path = Path.join("tmp", "spoof-#{System.unique_integer([:positive])}.png")
    File.write!(path, "<svg xmlns=\"http://www.w3.org/2000/svg\"></svg>")
    on_exit(fn -> File.rm(path) end)

    assert {:error, :unsupported_media} =
             Media.upload(profile.id, %{
               temp_path: path,
               client_name: "fake.png",
               content_type: "image/png"
             })
  end

  test "does not allow client filenames to escape storage", %{profile: profile} do
    path = temporary_png()

    assert {:ok, media} =
             Media.upload(profile.id, %{
               temp_path: path,
               client_name: "../../pixel.png",
               content_type: "image/png"
             })

    assert Path.basename(media.storage_path) != ".."
    refute String.contains?(media.storage_path, "../")
  end

  defp temporary_png do
    path = Path.join("tmp", "pixel-#{System.unique_integer([:positive])}.png")
    File.mkdir_p!(Path.dirname(path))

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
