defmodule Tela.ProfilesFixtures do
  @moduledoc "Local profile fixtures for the shared trusted workspace."

  def profile_fixture(attrs \\ %{}) do
    {:ok, profile} =
      Tela.Profiles.create_profile(
        Map.merge(%{name: "Pessoa #{System.unique_integer([:positive])}"}, attrs)
      )

    profile
  end
end
