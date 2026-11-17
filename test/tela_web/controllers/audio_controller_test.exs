defmodule TelaWeb.AudioControllerTest do
  use TelaWeb.ConnCase, async: true

  test "returns the local audio manifest with static URLs and CC0 metadata", %{conn: conn} do
    response = conn |> get("/api/audio/library") |> json_response(200)

    assert response["schema"] == 1
    assert response["release"] == "2026.10.1"
    assert response["license"]["spdx"] == "CC0-1.0"
    assert response["license"]["holder"] == "Doory contributors"
    assert length(response["tracks"]) == 112
    assert Enum.count(response["tracks"], &(&1["kind"] == "music")) == 24
    assert Enum.count(response["tracks"], &(&1["kind"] == "sfx")) == 88

    assert Enum.all?(response["tracks"], fn track ->
             track["url"] == "/audio/" <> track["file"]
           end)
  end

  test "serves a bundled audio file", %{conn: conn} do
    conn = get(conn, "/audio/music/sunrise-run.ogg")
    assert get_resp_header(conn, "content-type") == ["audio/ogg"]
    body = response(conn, 200)

    assert String.starts_with?(body, "OggS")
    assert byte_size(body) > 1_000
  end
end
