defmodule Tela.Repo.Migrations.AddTemplateMetadata do
  use Ecto.Migration

  def change do
    alter table(:designs) do
      add :slug, :string
      add :description, :text
      add :tags, :string, null: false, default: "[]"
      add :use_count, :integer, null: false, default: 0
      add :is_featured, :boolean, null: false, default: false
    end

    create unique_index(:designs, [:slug])
  end
end
