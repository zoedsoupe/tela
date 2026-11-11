defmodule Tela.Repo.Migrations.CreateMediaUploads do
  use Ecto.Migration

  def change do
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
