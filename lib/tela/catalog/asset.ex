defmodule Tela.Catalog.Asset do
  @moduledoc "A searchable, bundled catalog asset."

  use Ecto.Schema

  @type t :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: integer() | nil,
          slug: String.t() | nil,
          title_pt: String.t() | nil,
          tags_pt: String.t() | nil,
          type: String.t() | nil,
          file_path: String.t() | nil
        }

  schema "catalog_assets" do
    field :slug, :string
    field :title_pt, :string
    field :tags_pt, :string
    field :type, :string
    field :file_path, :string
  end
end
