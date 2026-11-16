defmodule Tela.Designs.Design do
  @moduledoc "A design shared by the workspace with optional creator attribution."

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          title: String.t() | nil,
          document: map() | nil,
          width: integer() | nil,
          height: integer() | nil,
          page_count: integer() | nil,
          preset_id: String.t() | nil,
          category: String.t() | nil,
          slug: String.t() | nil,
          description: String.t() | nil,
          tags: String.t(),
          use_count: non_neg_integer(),
          is_featured: boolean(),
          folder_id: Ecto.UUID.t() | nil,
          starred: boolean(),
          trashed_at: DateTime.t() | nil,
          is_template: boolean(),
          revision: integer(),
          thumbnail_path: String.t() | nil,
          created_by_id: Ecto.UUID.t() | nil,
          created_by: Tela.Profiles.Profile.t() | Ecto.Association.NotLoaded.t() | nil,
          updated_by_id: Ecto.UUID.t() | nil,
          updated_by: Tela.Profiles.Profile.t() | Ecto.Association.NotLoaded.t() | nil,
          folder: Tela.Designs.Folder.t() | Ecto.Association.NotLoaded.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "designs" do
    field :title, :string
    field :document, :map
    field :width, :integer
    field :height, :integer
    field :page_count, :integer
    field :preset_id, :string
    field :category, :string
    field :slug, :string
    field :description, :string
    field :tags, :string, default: "[]"
    field :use_count, :integer, default: 0
    field :is_featured, :boolean, default: false
    field :starred, :boolean, default: false
    field :trashed_at, :utc_datetime
    field :is_template, :boolean, default: false
    field :revision, :integer, default: 1
    field :thumbnail_path, :string
    belongs_to :created_by, Tela.Profiles.Profile
    belongs_to :updated_by, Tela.Profiles.Profile
    belongs_to :folder, Tela.Designs.Folder

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(design, attrs) do
    design
    |> cast(attrs, [
      :created_by_id,
      :updated_by_id,
      :title,
      :document,
      :width,
      :height,
      :page_count,
      :preset_id,
      :category,
      :slug,
      :description,
      :tags,
      :use_count,
      :is_featured,
      :is_template,
      :revision,
      :thumbnail_path,
      :folder_id,
      :starred,
      :trashed_at
    ])
    |> update_change(:title, &String.trim/1)
    |> validate_required([:title, :document, :width, :height, :page_count, :category, :revision])
    |> validate_length(:title, min: 1, max: 200)
    |> validate_number(:width, greater_than: 0)
    |> validate_number(:height, greater_than: 0)
    |> validate_number(:page_count, greater_than: 0)
    |> validate_number(:revision, greater_than: 0)
    |> validate_number(:use_count, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:created_by_id)
    |> foreign_key_constraint(:updated_by_id)
    |> foreign_key_constraint(:folder_id)
  end
end
