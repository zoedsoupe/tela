defmodule Tela.Profiles do
  @moduledoc "Local workspace profiles for optional authorship attribution."

  import Ecto.Query
  alias Tela.Profiles.Profile
  alias Tela.Repo

  @spec create_profile(map()) :: {:ok, Profile.t()} | {:error, Ecto.Changeset.t()}
  def create_profile(attrs) when is_map(attrs) do
    %Profile{}
    |> Profile.changeset(attrs)
    |> Repo.insert()
  end

  @spec get_profile(binary()) :: {:ok, Profile.t()} | {:error, :not_found}
  def get_profile(profile_id) do
    with {:ok, id} <- Ecto.UUID.cast(profile_id),
         %Profile{} = profile <- Repo.get(Profile, id) do
      {:ok, profile}
    else
      _ -> {:error, :not_found}
    end
  end

  @spec list_profiles() :: {:ok, [Profile.t()]}
  def list_profiles do
    profiles =
      Profile
      |> order_by([profile], fragment("lower(?)", profile.name))
      |> order_by([profile], asc: profile.name, asc: profile.id)
      |> Repo.all()

    {:ok, profiles}
  end
end
