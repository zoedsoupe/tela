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
          file_path: String.t() | nil,
          pack_slug: String.t() | nil,
          pack_name: String.t() | nil,
          style: String.t() | nil,
          svg: String.t() | nil,
          width: integer() | nil,
          height: integer() | nil,
          colors: map() | nil,
          is_recolorable: boolean() | nil,
          license: String.t() | nil,
          license_url: String.t() | nil,
          attribution: String.t() | nil,
          source_url: String.t() | nil,
          sort_order: integer() | nil
        }

  schema "catalog_assets" do
    field :slug, :string
    field :title_pt, :string
    field :tags_pt, :string
    field :type, :string
    field :file_path, :string
    field :pack_slug, :string
    field :pack_name, :string
    field :style, :string
    field :svg, :string
    field :width, :integer
    field :height, :integer
    field :colors, :map
    field :is_recolorable, :boolean
    field :license, :string
    field :license_url, :string
    field :attribution, :string
    field :source_url, :string
    field :sort_order, :integer
  end
end
