defmodule Tela.Designs.Folder do
  @moduledoc "A workspace folder with an optional parent."

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          name: String.t() | nil,
          parent_id: Ecto.UUID.t() | nil,
          created_by_id: Ecto.UUID.t() | nil,
          design_count: non_neg_integer(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "folders" do
    field :name, :string
    field :design_count, :integer, virtual: true, default: 0
    belongs_to :parent, __MODULE__
    belongs_to :created_by, Tela.Profiles.Profile

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(folder, attrs) do
    folder
    |> cast(attrs, [:name, :parent_id, :created_by_id])
    |> update_change(:name, &String.trim/1)
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 120)
    |> foreign_key_constraint(:parent_id)
    |> foreign_key_constraint(:created_by_id)
  end
end
