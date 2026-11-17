defmodule TelaWeb.SPAControllerTest do
  use TelaWeb.ConnCase, async: true

  test "mounts the SPA at the root and client-side editor paths", %{conn: conn} do
    for path <- ["/", "/design/example", "/s/shared-token", "/templates/serif-quote-card"] do
      response = get(conn, path)
      assert response.status in [200, 503]

      if response.status == 200 do
        assert response.resp_body =~ ~s(<div id="root"></div>)
      else
        assert response.resp_body =~ "Frontend não encontrado"
      end
    end
  end

  test "keeps unknown API routes in JSON", %{conn: conn} do
    response = get(conn, "/api/does-not-exist")

    assert json_response(response, 404) == %{
             "error" => %{"code" => "not_found", "message" => "Rota da API não encontrada."}
           }
  end
end
