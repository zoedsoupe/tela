defmodule TelaWeb.BrandControllerTest do
  use TelaWeb.ConnCase, async: false

  alias TelaWeb.BrandController

  test "accepts and returns the Doory brand-kit shape without profile ownership", %{conn: conn} do
    created = BrandController.create(conn, valid_input("Primeiro", true))
    assert created.status == 201
    first = json_response(created, 201)
    assert first["is_default"]
    assert [%{"id" => "c1", "hex" => "#123456"}] = first["colors"]
    assert [%{"role" => "heading", "family" => "DM Sans"}] = first["fonts"]
    assert first["logos"] == []

    second_response = BrandController.create(conn, valid_input("Segundo", true))
    second = json_response(second_response, 201)
    assert second["is_default"]

    listed = json_response(BrandController.index(conn, %{}), 200)
    first_in_list = Enum.find(listed, &(&1["id"] == first["id"]))
    refute first_in_list["is_default"]

    updated = BrandController.update(conn, %{"id" => second["id"], "name" => "Atualizado"})
    assert json_response(updated, 200)["name"] == "Atualizado"
    assert BrandController.delete(conn, %{"id" => first["id"]}).status == 204
  end

  test "reports invalid input and unknown ids with JSON errors", %{conn: conn} do
    invalid =
      BrandController.create(conn, %{
        "name" => "",
        "colors" => [],
        "fonts" => [],
        "logo_ids" => []
      })

    assert invalid.status == 422
    assert %{"error" => %{"code" => "invalid_input"}} = json_response(invalid, 422)

    missing = BrandController.update(conn, %{"id" => Ecto.UUID.generate(), "name" => "Nope"})
    assert missing.status == 404
    assert %{"error" => %{"code" => "not_found"}} = json_response(missing, 404)
  end

  defp valid_input(name, is_default) do
    %{
      "name" => name,
      "is_default" => is_default,
      "colors" => [%{"id" => "c1", "name" => "Azul", "hex" => "#123456"}],
      "fonts" => [%{"role" => "heading", "family" => "DM Sans"}],
      "logo_ids" => []
    }
  end
end
