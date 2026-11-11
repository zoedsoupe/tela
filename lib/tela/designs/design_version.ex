defmodule Tela.Designs.DesignVersion do
  @moduledoc "A manually saved snapshot of a workspace design."

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          design_id: Ecto.UUID.t() | nil,
          label: String.t() | nil,
          document: map() | nil,
          page_count: integer() | nil,
          thumbnail_path: String.t() | nil,
          is_auto: boolean(),
          created_by_id: Ecto.UUID.t() | nil,
          inserted_at: DateTime.t() | nil
        }

  schema "design_versions" do
    field :label, :string
    field :document, :map
    field :page_count, :integer
    field :thumbnail_path, :string
    field :is_auto, :boolean, default: false
    belongs_to :design, Tela.Designs.Design
    belongs_to :created_by, Tela.Profiles.Profile

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(version, attrs) do
    version
    |> cast(attrs, [
      :design_id,
      :created_by_id,
      :label,
      :document,
      :page_count,
      :thumbnail_path,
      :is_auto
    ])
    |> validate_required([:design_id, :label, :document, :page_count])
    |> validate_length(:label, max: 120)
    |> validate_number(:page_count, greater_than: 0)
    |> foreign_key_constraint(:design_id)
    |> foreign_key_constraint(:created_by_id)
  end
end
