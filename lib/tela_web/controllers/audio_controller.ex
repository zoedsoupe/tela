defmodule TelaWeb.AudioController do
  use TelaWeb, :controller

  def library(conn, _params) do
    path = Application.app_dir(:tela, "priv/content/audio/audio_library.json")

    with {:ok, body} <- File.read(path),
         {:ok, manifest} when is_map(manifest) <- Phoenix.json_library().decode(body),
         tracks when is_list(tracks) <- manifest["tracks"] do
      manifest = Map.put(manifest, "tracks", Enum.map(tracks, &add_audio_url/1))

      conn
      |> put_resp_header("cache-control", "public, max-age=3600")
      |> json(manifest)
    else
      _ ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{
          error: %{
            code: "audio_library_unavailable",
            message: "A biblioteca de áudio local não está disponível agora."
          }
        })
    end
  end

  defp add_audio_url(%{"file" => file} = track) when is_binary(file) do
    Map.put(track, "url", "/audio/" <> file)
  end

  defp add_audio_url(track), do: track
end
