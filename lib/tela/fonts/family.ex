defmodule Tela.Fonts.Family do
  @moduledoc "A bundled or workspace-shared font family."

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          family: String.t() | nil,
          normalized_name: String.t() | nil,
          category: String.t() | nil,
          scripts: map() | nil,
          is_variable: boolean() | nil,
          is_user_font: boolean() | nil,
          variants: map() | nil,
          popularity: integer() | nil,
          unicode_ranges: map() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "fonts" do
    field :family, :string
    field :normalized_name, :string
    field :category, :string
    field :scripts, :map, default: %{values: ["latin"]}
    field :is_variable, :boolean, default: false
    field :is_user_font, :boolean, default: false
    field :variants, :map, default: %{items: []}
    field :popularity, :integer, default: 9999
    field :unicode_ranges, :map

    timestamps(type: :utc_datetime)
  end

  def changeset(family, attrs) do
    family
    |> cast(attrs, [
      :family,
      :normalized_name,
      :category,
      :scripts,
      :is_variable,
      :is_user_font,
      :variants,
      :popularity,
      :unicode_ranges
    ])
    |> validate_required([:family, :normalized_name, :category, :scripts, :variants])
    |> validate_length(:family, min: 1, max: 80)
    |> validate_inclusion(:category, [
      "sans-serif",
      "serif",
      "display",
      "handwriting",
      "monospace"
    ])
    |> unique_constraint(:normalized_name)
  end
end
