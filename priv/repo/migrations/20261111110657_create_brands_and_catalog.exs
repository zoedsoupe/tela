defmodule Tela.Repo.Migrations.CreateBrandsAndCatalog do
  use Ecto.Migration

  def up do
    create table(:brand_kits, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :created_by_id, references(:profiles, type: :binary_id, on_delete: :nilify_all)
      add :name, :string, null: false
      add :colors, :map, null: false
      add :fonts, :map, null: false
      add :logos, :map, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:brand_kits, [:created_by_id])

    create table(:catalog_assets) do
      add :slug, :string, null: false
      add :title_pt, :string, null: false
      add :tags_pt, :string, null: false
      add :type, :string, null: false
      add :file_path, :string, null: false
    end

    create unique_index(:catalog_assets, [:slug])

    execute("""
    CREATE VIRTUAL TABLE catalog_assets_fts USING fts5(
      title_pt,
      tags_pt,
      content='catalog_assets',
      content_rowid='id',
      tokenize='unicode61 remove_diacritics 2'
    )
    """)

    execute("""
    CREATE TRIGGER catalog_assets_fts_insert AFTER INSERT ON catalog_assets BEGIN
      INSERT INTO catalog_assets_fts(rowid, title_pt, tags_pt)
      VALUES (new.id, new.title_pt, new.tags_pt);
    END
    """)

    execute("""
    CREATE TRIGGER catalog_assets_fts_delete AFTER DELETE ON catalog_assets BEGIN
      INSERT INTO catalog_assets_fts(catalog_assets_fts, rowid, title_pt, tags_pt)
      VALUES ('delete', old.id, old.title_pt, old.tags_pt);
    END
    """)

    execute("""
    CREATE TRIGGER catalog_assets_fts_update AFTER UPDATE ON catalog_assets BEGIN
      INSERT INTO catalog_assets_fts(catalog_assets_fts, rowid, title_pt, tags_pt)
      VALUES ('delete', old.id, old.title_pt, old.tags_pt);
      INSERT INTO catalog_assets_fts(rowid, title_pt, tags_pt)
      VALUES (new.id, new.title_pt, new.tags_pt);
    END
    """)
  end

  def down do
    execute("DROP TRIGGER catalog_assets_fts_insert")
    execute("DROP TRIGGER catalog_assets_fts_delete")
    execute("DROP TRIGGER catalog_assets_fts_update")
    execute("DROP TABLE catalog_assets_fts")
    drop table(:catalog_assets)
    drop table(:brand_kits)
  end
end
