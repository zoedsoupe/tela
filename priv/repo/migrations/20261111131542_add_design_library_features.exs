defmodule Tela.Repo.Migrations.AddDesignLibraryFeatures do
  use Ecto.Migration

  def change do
    create table(:folders, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :name, :string, null: false
      add :parent_id, references(:folders, type: :binary_id, on_delete: :nilify_all)
      add :created_by_id, references(:profiles, type: :binary_id, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    create index(:folders, [:parent_id])
    create index(:folders, [:created_by_id])

    execute(
      "ALTER TABLE designs ADD COLUMN folder_id TEXT CONSTRAINT designs_folder_id_fkey REFERENCES folders(id) ON DELETE SET NULL",
      "ALTER TABLE designs DROP COLUMN folder_id"
    )

    execute(
      "ALTER TABLE designs ADD COLUMN updated_by_id TEXT CONSTRAINT designs_updated_by_id_fkey REFERENCES profiles(id) ON DELETE SET NULL",
      "ALTER TABLE designs DROP COLUMN updated_by_id"
    )

    alter table(:designs) do
      add :starred, :boolean, null: false, default: false
      add :trashed_at, :utc_datetime
    end

    create index(:designs, [:folder_id])
    create index(:designs, [:trashed_at, :updated_at])

    create table(:design_versions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :design_id, references(:designs, type: :binary_id, on_delete: :delete_all), null: false
      add :label, :string, null: false
      add :document, :map, null: false
      add :page_count, :integer, null: false
      add :thumbnail_path, :string
      add :is_auto, :boolean, null: false, default: false
      add :created_by_id, references(:profiles, type: :binary_id, on_delete: :nilify_all)

      add :inserted_at, :utc_datetime, null: false
    end

    create index(:design_versions, [:design_id, :inserted_at])
  end
end
