defmodule Tela.Brands do
  @moduledoc "Shared workspace brand kits."

  import Ecto.Query
  alias Tela.Brands.Kit
  alias Tela.Repo

  @spec create_kit(Ecto.UUID.t() | nil, map()) :: {:ok, Kit.t()} | {:error, Ecto.Changeset.t()}
  def create_kit(created_by_id, attrs) when is_map(attrs) do
    %Kit{created_by_id: created_by_id}
    |> Kit.changeset(attrs)
    |> Ecto.Changeset.foreign_key_constraint(:created_by_id)
    |> Repo.insert()
  end

  @spec update_kit(Ecto.UUID.t(), map()) ::
          {:ok, Kit.t()} | {:error, Ecto.Changeset.t() | :not_found}
  def update_kit(id, attrs) when is_map(attrs) do
    with {:ok, id} <- Ecto.UUID.cast(id),
         %Kit{} = kit <- Repo.get(Kit, id) do
      kit
      |> Kit.changeset(attrs)
      |> Repo.update()
    else
      _ -> {:error, :not_found}
    end
  end

  @spec delete_kit(Ecto.UUID.t()) :: {:ok, Kit.t()} | {:error, Ecto.Changeset.t() | :not_found}
  def delete_kit(id) do
    with {:ok, id} <- Ecto.UUID.cast(id),
         %Kit{} = kit <- Repo.get(Kit, id) do
      Repo.delete(kit)
    else
      _ -> {:error, :not_found}
    end
  end

  @spec list_kits() :: {:ok, [Kit.t()]}
  def list_kits do
    kits = Repo.all(from kit in Kit, order_by: [asc: kit.name, asc: kit.id])
    {:ok, kits}
  end
end
