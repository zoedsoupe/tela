defmodule Tela.MediaUploadKindsTest do
  use Tela.DataCase, async: false

  alias Tela.Media
  alias Tela.Media.Format

  setup do
    root = Path.join("tmp", "media-kinds-#{System.unique_integer([:positive])}")
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

  test "stores audio with a checked container signature and client duration" do
    path = temporary_file("wav", <<"RIFF", 8::unsigned-little-32, "WAVE", "fmt ">>)

    assert {:ok, upload} =
             Media.upload(nil, %{
               temp_path: path,
               client_name: "voice.wav",
               content_type: "audio/wav",
               duration_ms: "1250",
               metadata: %{"audio" => %{"sample_rate" => 48_000}}
             })

    assert upload.kind == "audio"
    assert upload.width == nil
    assert upload.height == nil
    assert upload.duration_ms == 1250
    assert upload.metadata == %{"audio" => %{"sample_rate" => 48_000}}
    assert File.exists?(upload.storage_path)
  end

  test "stores an original video and does not inspect its codecs" do
    path =
      temporary_file(
        "mp4",
        <<32::unsigned-big-32, "ftyp", "isom", 0, 0, 2, 0, "isomiso2payload">>
      )

    assert {:ok, upload} =
             Media.upload(nil, %{
               temp_path: path,
               client_name: "clip.mp4",
               content_type: "video/mp4",
               width: "640",
               height: "360",
               duration_ms: "1800",
               metadata: %{"video" => %{"fps" => 24, "filmstrip" => nil}}
             })

    assert upload.kind == "video"
    assert upload.width == 640
    assert upload.height == 360
    assert upload.duration_ms == 1800
    assert Media.to_asset(upload).video == %{"fps" => 24, "filmstrip" => nil}
  end

  test "rejects containers that do not match the requested media kind" do
    path = temporary_file("webm", <<0x1A, 0x45, 0xDF, 0xA3, "container">>)

    assert {:error, :unsupported_media} =
             Media.upload(nil, %{
               temp_path: path,
               client_name: "clip.webm",
               content_type: "audio/webm",
               kind: "image"
             })
  end

  test "rejects active SVG content while accepting inert vector images" do
    safe =
      temporary_file(
        "svg",
        ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><rect width="10" height="10"/></svg>|
      )

    unsafe =
      temporary_file(
        "svg",
        ~s|<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>|
      )

    assert {:ok, info} = Format.inspect_upload(safe, "svg")
    assert info.kind == "svg"
    assert {:error, :unsupported_media} = Format.inspect_upload(unsafe, "svg")
  end

  test "rejects metadata that is not a bounded JSON object" do
    path = temporary_file("wav", <<"RIFF", 8::unsigned-little-32, "WAVE", "fmt ">>)

    assert {:error, :invalid_upload_metadata} =
             Media.upload(nil, %{
               temp_path: path,
               client_name: "voice.wav",
               content_type: "audio/wav",
               metadata: "[]"
             })
  end

  test "enforces the per-upload byte limit before inspecting content" do
    path =
      Path.join(System.tmp_dir!(), "tela-oversized-#{System.unique_integer([:positive])}.mp4")

    {:ok, file} = File.open(path, [:write, :binary])
    {:ok, _position} = :file.position(file, 50_000_001)
    :ok = :file.write(file, <<0>>)
    :ok = File.close(file)
    on_exit(fn -> File.rm(path) end)

    assert {:error, :upload_too_large} =
             Media.upload(nil, %{
               temp_path: path,
               client_name: "oversized.mp4",
               content_type: "video/mp4"
             })
  end

  test "stores an optional browser-generated poster separately from the original video" do
    video_path =
      temporary_file("mp4", <<32::unsigned-big-32, "ftyp", "isom", 0, 0, 2, 0, "payload">>)

    poster_path =
      temporary_file(
        "png",
        Base.decode64!(
          "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
        )
      )

    assert {:ok, upload} =
             Media.upload(nil, %{
               temp_path: video_path,
               client_name: "clip.mp4",
               content_type: "video/mp4",
               poster_temp_path: poster_path
             })

    assert is_binary(upload.poster_path)
    assert File.exists?(upload.poster_path)
    assert Media.to_asset(upload).poster_url == "/uploads/#{upload.id}?variant=poster"
  end

  defp temporary_file(extension, contents) do
    path =
      Path.join(System.tmp_dir!(), "tela-kind-#{System.unique_integer([:positive])}.#{extension}")

    File.write!(path, contents)
    on_exit(fn -> File.rm(path) end)
    path
  end
end
