defmodule TelaWeb.ProfileControllerTest do
  use TelaWeb.ConnCase, async: false
  import Tela.ProfilesFixtures

  setup %{conn: conn} do
    csrf_conn = get(conn, "/api/csrf")
    %{"csrf_token" => token} = json_response(csrf_conn, 200)

    {:ok, conn: recycle(csrf_conn) |> put_req_header("x-csrf-token", token)}
  end

  test "lists and creates profiles without credentials", %{conn: conn} do
    assert %{"profiles" => [], "current_profile" => nil} =
             conn |> get("/api/profiles") |> json_response(200)

    assert %{"profile" => %{"id" => id, "name" => "Zoey"}} =
             conn |> post("/api/profiles", %{name: "  Zoey  "}) |> json_response(201)

    assert is_binary(id)
    assert %{"profiles" => [%{"id" => ^id}]} = get(conn, "/api/profiles") |> json_response(200)
  end

  test "selects and clears a profile through the session", %{conn: conn} do
    profile = profile_fixture(%{name: "Pessoa"})
    [token] = get_req_header(conn, "x-csrf-token")

    selected_conn = post(conn, "/api/profiles/select", %{profile_id: profile.id})
    assert %{"current_profile" => %{"id" => id}} = json_response(selected_conn, 200)

    assert id == profile.id

    assert %{"current_profile" => %{"id" => ^id}} =
             selected_conn |> recycle() |> get("/api/profiles") |> json_response(200)

    assert %{"current_profile" => nil} =
             selected_conn
             |> recycle()
             |> put_req_header("x-csrf-token", token)
             |> delete("/api/profiles/select")
             |> json_response(200)
  end

  test "returns structured not-found and validation errors", %{conn: conn} do
    assert %{"error" => %{"code" => "not_found", "message" => _}} =
             conn
             |> post("/api/profiles/select", %{profile_id: Ecto.UUID.generate()})
             |> json_response(404)

    assert %{"error" => %{"code" => "validation_error"}} =
             conn |> post("/api/profiles", %{name: "   "}) |> json_response(422)
  end

  test "rejects workspace mutations without a valid CSRF token", %{conn: conn} do
    assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
      conn
      |> delete_req_header("x-csrf-token")
      |> put_private(:plug_skip_csrf_protection, false)
      |> post("/api/profiles", %{name: "Sem token"})
    end
  end

  test "gets a CSRF token and readable cookie on a fresh session before mutating", %{
    conn: _conn
  } do
    csrf_conn =
      build_conn()
      |> put_private(:plug_skip_csrf_protection, false)
      |> get("/api/csrf")

    assert %{"csrf_token" => token} = json_response(csrf_conn, 200)

    csrf_cookie =
      csrf_conn
      |> get_resp_header("set-cookie")
      |> Enum.find(&String.starts_with?(&1, "csrftoken="))

    assert csrf_cookie =~ "csrftoken=#{token}"
    assert String.contains?(String.downcase(csrf_cookie), "samesite=lax")
    refute String.contains?(String.downcase(csrf_cookie), "httponly")

    assert %{"profile" => %{"name" => "Com token"}} =
             csrf_conn
             |> recycle()
             |> put_private(:plug_skip_csrf_protection, false)
             |> put_req_header("x-csrf-token", token)
             |> post("/api/profiles", %{name: "Com token"})
             |> json_response(201)

    assert_raise Plug.CSRFProtection.InvalidCSRFTokenError, fn ->
      csrf_conn
      |> recycle()
      |> delete_req_header("x-csrf-token")
      |> put_private(:plug_skip_csrf_protection, false)
      |> post("/api/profiles", %{name: "Sem token"})
    end
  end
end
