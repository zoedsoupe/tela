defmodule Tela.BrandsTest do
  use Tela.DataCase, async: false
  import Tela.ProfilesFixtures
  alias Tela.Brands

  setup do
    %{profile: profile_fixture(), collaborator: profile_fixture()}
  end

  test "creates and lists brand kits for the shared workspace", %{
    profile: profile,
    collaborator: collaborator
  } do
    assert {:ok, kit} = Brands.create_kit(profile.id, valid_attributes())
    assert kit.created_by_id == profile.id
    assert kit.name == "Marca Principal"
    assert kit.colors == %{"values" => ["#DF6045", "#22211E"]}
    assert kit.fonts == %{"heading" => "DM Sans", "body" => "DM Sans"}
    assert {:ok, [listed]} = Brands.list_kits()
    assert listed.id == kit.id
    assert {:ok, updated} = Brands.update_kit(kit.id, %{name: "Editada por outro perfil"})
    assert updated.name == "Editada por outro perfil"
    assert collaborator.id != profile.id
  end

  test "validates colors and required font roles", %{profile: profile} do
    assert {:error, changeset} =
             Brands.create_kit(profile.id, %{valid_attributes() | colors: %{"values" => ["red"]}})

    assert %{colors: [_ | _]} = errors_on(changeset)

    assert {:error, changeset} =
             Brands.create_kit(profile.id, %{
               valid_attributes()
               | fonts: %{"heading" => "DM Sans"}
             })

    assert %{fonts: [_ | _]} = errors_on(changeset)
  end

  test "deletes a shared kit", %{profile: profile} do
    {:ok, kit} = Brands.create_kit(profile.id, valid_attributes())
    assert {:ok, _} = Brands.delete_kit(kit.id)
    assert {:ok, []} = Brands.list_kits()
  end

  defp valid_attributes do
    %{
      name: "Marca Principal",
      colors: %{"values" => ["#DF6045", "#22211E"]},
      fonts: %{"heading" => "DM Sans", "body" => "DM Sans"},
      logos: %{"items" => []}
    }
  end
end
