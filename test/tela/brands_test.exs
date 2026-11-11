defmodule Tela.BrandsTest do
  use Tela.DataCase, async: false
  import Tela.ProfilesFixtures
  alias Tela.Brands
  alias Tela.Media.MediaUpload
  alias Tela.Brands.Kit

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

  test "keeps one global default while switching kits without changing their logos" do
    {:ok, asset} =
      %MediaUpload{}
      |> MediaUpload.changeset(%{
        kind: "image",
        filename: "logo.png",
        storage_path: "uploads/logo.png",
        content_type: "image/png",
        byte_size: 10,
        source: "upload",
        width: 1,
        height: 1
      })
      |> Repo.insert()

    first_attrs =
      valid_attributes()
      |> Map.put(:logo_ids, [asset.id])
      |> Map.put(:is_default, true)

    second_attrs = Map.put(valid_attributes(), :is_default, true)

    assert {:ok, first} = Brands.create_kit(nil, first_attrs)
    assert {:ok, second} = Brands.create_kit(nil, second_attrs)
    assert first.logos == %{"items" => [asset.id]}
    assert first.is_default
    refute Repo.get!(Kit, first.id).is_default
    assert Repo.get!(Kit, first.id).logos == first.logos
    assert Repo.get!(Kit, second.id).is_default

    assert {:ok, updated_first} = Brands.update_kit(first.id, %{is_default: true})
    assert updated_first.is_default
    refute Repo.get!(Kit, second.id).is_default
    assert Repo.get!(Kit, first.id).logos == first.logos

    assert {:ok, updated_second} = Brands.update_kit(second.id, %{is_default: true})
    assert updated_second.is_default
    refute Repo.get!(Kit, first.id).is_default
    assert Repo.get!(Kit, first.id).logos == first.logos
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
