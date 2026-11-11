defmodule Tela.Media.MediaUpload do
  @moduledoc "A workspace-shared media file with optional creator attribution."

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          created_by_id: Ecto.UUID.t() | nil,
          kind: String.t() | nil,
          filename: String.t() | nil,
          storage_path: String.t() | nil,
          content_type: String.t() | nil,
          byte_size: non_neg_integer() | nil,
          source: String.t() | nil,
          external_id: String.t() | nil,
          attribution: String.t() | nil,
          width: non_neg_integer() | nil,
          height: non_neg_integer() | nil,
          duration_ms: non_neg_integer() | nil,
          poster_path: String.t() | nil,
          metadata: map() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "media_uploads" do
    field :kind, :string, default: "image"
    field :filename, :string
    field :storage_path, :string
    field :content_type, :string
    field :byte_size, :integer
    field :source, :string
    field :external_id, :string
    field :attribution, :string
    field :width, :integer
    field :height, :integer
    field :duration_ms, :integer
    field :poster_path, :string
    field :metadata, :map
    belongs_to :created_by, Tela.Profiles.Profile

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(media_upload, attrs) do
    media_upload
    |> cast(attrs, [
      :created_by_id,
      :kind,
      :filename,
      :storage_path,
      :content_type,
      :byte_size,
      :source,
      :external_id,
      :attribution,
      :width,
      :height,
      :duration_ms,
      :poster_path,
      :metadata
    ])
    |> validate_required([
      :filename,
      :storage_path,
      :content_type,
      :byte_size,
      :source
    ])
    |> validate_inclusion(:kind, ["image", "svg", "audio", "video"])
    |> validate_number(:byte_size, greater_than: 0)
    |> validate_number(:width, greater_than: 0)
    |> validate_number(:height, greater_than: 0)
    |> validate_number(:duration_ms, greater_than: 0)
    |> validate_change(:metadata, fn :metadata, metadata ->
      if is_map(metadata), do: [], else: [metadata: "must be a JSON object"]
    end)
    |> foreign_key_constraint(:created_by_id)
    |> unique_constraint([:source, :external_id], name: :media_uploads_source_external_id_index)
  end
end
