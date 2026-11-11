defmodule Tela.Repo.Migrations.AddMediaKindsCommentsAndShareLinks do
  use Ecto.Migration

  def up do
    drop_if_exists table(:media_uploads)

    create table(:media_uploads, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :created_by_id, references(:profiles, type: :binary_id, on_delete: :nilify_all)
      add :kind, :string, null: false, default: "image"
      add :filename, :string, null: false
      add :storage_path, :string, null: false
      add :content_type, :string, null: false
      add :byte_size, :integer, null: false
      add :source, :string, null: false
      add :external_id, :string
      add :attribution, :string
      add :width, :integer
      add :height, :integer
      add :duration_ms, :integer
      add :poster_path, :string
      add :metadata, :map

      timestamps(type: :utc_datetime)
    end

    create index(:media_uploads, [:created_by_id])
    create unique_index(:media_uploads, [:source, :external_id])
    create index(:media_uploads, [:kind, :inserted_at])

    create table(:comments, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :design_id, references(:designs, type: :binary_id, on_delete: :delete_all), null: false
      add :parent_id, references(:comments, type: :binary_id, on_delete: :delete_all)
      add :profile_id, references(:profiles, type: :binary_id, on_delete: :nilify_all)
      add :author_name, :string, null: false
      add :body, :string, null: false
      add :page_id, :string
      add :x, :float
      add :y, :float
      add :resolved, :boolean, null: false, default: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:comments, [:design_id, :inserted_at, :id])
    create index(:comments, [:parent_id])

    create table(:share_links, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :design_id, references(:designs, type: :binary_id, on_delete: :delete_all), null: false
      add :token_digest, :string, null: false
      add :role, :string, null: false
      add :revoked_at, :utc_datetime
      add :last_accessed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:share_links, [:token_digest])
    create index(:share_links, [:design_id, :inserted_at])
  end

  def down do
    drop table(:share_links)
    drop table(:comments)
    drop table(:media_uploads)

    create table(:media_uploads, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :created_by_id, references(:profiles, type: :binary_id, on_delete: :nilify_all)
      add :filename, :string, null: false
      add :storage_path, :string, null: false
      add :content_type, :string, null: false
      add :byte_size, :integer, null: false
      add :source, :string, null: false
      add :external_id, :string
      add :attribution, :string
      add :width, :integer, null: false
      add :height, :integer, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:media_uploads, [:created_by_id])
    create unique_index(:media_uploads, [:source, :external_id])
  end
end
