defmodule Tela.Sharing.ShareLink do
  @moduledoc "A revocable bearer capability for one design."

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @roles ~w(view comment edit)

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          design_id: Ecto.UUID.t() | nil,
          token: String.t() | nil,
          token_digest: String.t() | nil,
          role: String.t() | nil,
          expires_at: DateTime.t() | nil,
          revoked_at: DateTime.t() | nil,
          last_accessed_at: DateTime.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "share_links" do
    belongs_to :design, Tela.Designs.Design
    field :token, :string
    field :token_digest, :string
    field :role, :string
    field :expires_at, :utc_datetime
    field :revoked_at, :utc_datetime
    field :last_accessed_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(link, attrs) do
    link
    |> cast(attrs, [:role, :expires_at])
    |> validate_required([:role])
    |> validate_inclusion(:role, @roles)
    |> foreign_key_constraint(:design_id)
    |> unique_constraint(:token_digest)
    |> check_constraint(:role, name: :share_links_role_valid)
  end

  @spec roles() :: [String.t()]
  def roles, do: @roles
end
