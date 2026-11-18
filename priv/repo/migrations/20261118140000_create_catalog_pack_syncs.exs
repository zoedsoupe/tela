defmodule Tela.Repo.Migrations.CreateCatalogPackSyncs do
  use Ecto.Migration

  def change do
    create table(:catalog_pack_syncs) do
      add :pack_slug, :string, null: false
      add :fingerprint, :string, null: false
      add :source_ref, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:catalog_pack_syncs, [:pack_slug])
    create index(:catalog_assets, [:pack_slug, :type, :sort_order, :id])
  end
end
