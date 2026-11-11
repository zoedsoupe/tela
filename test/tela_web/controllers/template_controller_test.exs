defmodule TelaWeb.TemplateControllerTest do
  use TelaWeb.ConnCase, async: false

  test "lists presets and returns an empty template catalog without documents in summaries", %{
    conn: conn
  } do
    assert %{"presets" => presets} = get(conn, "/api/presets") |> json_response(200)
    assert Enum.any?(presets, &(&1["id"] == "story"))

    assert %{"templates" => []} = get(conn, "/api/templates") |> json_response(200)

    assert %{"error" => %{"code" => "not_found"}} =
             get(conn, "/api/templates/#{Ecto.UUID.generate()}") |> json_response(404)
  end
end
