defmodule Tela.Sharing.Comment do
  @moduledoc "An asynchronous comment or reply attached to a shared workspace design."

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @type t :: %__MODULE__{
          id: Ecto.UUID.t() | nil,
          design_id: Ecto.UUID.t() | nil,
          parent_id: Ecto.UUID.t() | nil,
          profile_id: Ecto.UUID.t() | nil,
          author_name: String.t() | nil,
          body: String.t() | nil,
          page_id: String.t() | nil,
          x: float() | nil,
          y: float() | nil,
          resolved: boolean(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "comments" do
    belongs_to :design, Tela.Designs.Design
    belongs_to :parent, __MODULE__
    belongs_to :profile, Tela.Profiles.Profile
    field :author_name, :string
    field :body, :string
    field :page_id, :string
    field :x, :float
    field :y, :float
    field :resolved, :boolean, default: false

    timestamps(type: :utc_datetime_usec)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:author_name, :body, :page_id, :x, :y, :resolved])
    |> update_change(:author_name, &String.trim/1)
    |> update_change(:body, &String.trim/1)
    |> validate_required([:author_name, :body])
    |> validate_length(:author_name, min: 1, max: 120)
    |> validate_length(:body, min: 1, max: 2000)
    |> validate_length(:page_id, max: 64)
    |> validate_format(:page_id, ~r/\A[A-Za-z0-9_.:-]{1,64}\z/)
    |> validate_number(:x, greater_than_or_equal_to: -1_000_000, less_than_or_equal_to: 1_000_000)
    |> validate_number(:y, greater_than_or_equal_to: -1_000_000, less_than_or_equal_to: 1_000_000)
    |> validate_xy_together()
    |> foreign_key_constraint(:design_id)
    |> foreign_key_constraint(:parent_id)
    |> foreign_key_constraint(:profile_id)
    |> check_constraint(:x, name: :comments_xy_together)
  end

  defp validate_xy_together(changeset) do
    x = get_field(changeset, :x)
    y = get_field(changeset, :y)

    if is_nil(x) == is_nil(y),
      do: changeset,
      else: add_error(changeset, :x, "x and y must be given together")
  end
end
