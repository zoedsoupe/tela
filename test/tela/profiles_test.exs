defmodule Tela.ProfilesTest do
  use Tela.DataCase, async: false
  alias Tela.Profiles

  test "creates local profiles without credentials and lists them alphabetically" do
    assert {:ok, zoey} = Profiles.create_profile(%{name: "  Zoey  "})
    assert zoey.name == "Zoey"
    refute Map.has_key?(zoey, :hashed_password)
    {:ok, alice} = Profiles.create_profile(%{name: "Alice"})
    assert {:ok, [listed_alice, listed_zoey]} = Profiles.list_profiles()
    assert listed_alice.id == alice.id
    assert listed_zoey.id == zoey.id
    assert {:ok, found} = Profiles.get_profile(zoey.id)
    assert found.id == zoey.id
  end

  test "requires a nonblank name and returns not found for unknown profiles" do
    assert {:error, changeset} = Profiles.create_profile(%{name: "   "})
    assert %{name: [_ | _]} = errors_on(changeset)
    assert {:error, :not_found} = Profiles.get_profile(Ecto.UUID.generate())
  end
end
