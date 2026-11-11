defmodule Tela.Repo.Migrations.CreateDesigns do
  use Ecto.Migration

  def change do
    create table(:designs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :created_by_id, references(:profiles, type: :binary_id, on_delete: :nilify_all)
      add :title, :string, null: false
      add :document, :map, null: false
      add :width, :integer, null: false
      add :height, :integer, null: false
      add :page_count, :integer, null: false
      add :preset_id, :string
      add :category, :string, null: false
      add :is_template, :boolean, null: false, default: false
      add :revision, :integer, null: false, default: 1
      add :thumbnail_path, :string

      timestamps(type: :utc_datetime)
    end

    create index(:designs, [:updated_at])
    create index(:designs, [:is_template, :category])
    create index(:designs, [:created_by_id])
  end
end
