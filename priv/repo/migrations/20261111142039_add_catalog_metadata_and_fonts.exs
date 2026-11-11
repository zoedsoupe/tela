defmodule Tela.Repo.Migrations.AddCatalogMetadataAndFonts do
  use Ecto.Migration

  def change do
    alter table(:catalog_assets) do
      add :pack_slug, :string, null: false, default: "starter"
      add :pack_name, :string, null: false, default: "Elementos"
      add :style, :string, null: false, default: ""
      add :svg, :text, null: false, default: ""
      add :width, :integer, null: false, default: 128
      add :height, :integer, null: false, default: 128
      add :colors, :map, null: false, default: %{values: []}
      add :is_recolorable, :boolean, null: false, default: true
      add :license, :string, null: false, default: "AGPL-3.0-or-later"

      add :license_url, :string,
        null: false,
        default: "https://www.gnu.org/licenses/agpl-3.0.html"

      add :attribution, :string, null: false, default: "Tela contributors"
      add :source_url, :string, null: false, default: "https://github.com/zoedsoupe/tela"
      add :sort_order, :integer, null: false, default: 0
    end

    create table(:fonts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :family, :string, null: false
      add :normalized_name, :string, null: false
      add :category, :string, null: false
      add :scripts, :map, null: false, default: %{values: ["latin"]}
      add :is_variable, :boolean, null: false, default: false
      add :is_user_font, :boolean, null: false, default: false
      add :variants, :map, null: false, default: %{items: []}
      add :popularity, :integer, null: false, default: 9999
      add :unicode_ranges, :map

      timestamps(type: :utc_datetime)
    end

    create unique_index(:fonts, [:normalized_name])
    create index(:fonts, [:is_user_font, :category, :popularity])

    execute(
      """
      CREATE VIRTUAL TABLE fonts_fts USING fts5(
        id UNINDEXED,
        family,
        tokenize='unicode61 remove_diacritics 2'
      )
      """,
      "DROP TABLE fonts_fts"
    )

    execute(
      """
      CREATE TRIGGER fonts_fts_insert AFTER INSERT ON fonts BEGIN
        INSERT INTO fonts_fts(id, family) VALUES (new.id, new.family);
      END
      """,
      "DROP TRIGGER fonts_fts_insert"
    )

    execute(
      """
      CREATE TRIGGER fonts_fts_delete AFTER DELETE ON fonts BEGIN
        DELETE FROM fonts_fts WHERE id = old.id;
      END
      """,
      "DROP TRIGGER fonts_fts_delete"
    )

    execute(
      """
      CREATE TRIGGER fonts_fts_update AFTER UPDATE OF family ON fonts BEGIN
        DELETE FROM fonts_fts WHERE id = old.id;
        INSERT INTO fonts_fts(id, family) VALUES (new.id, new.family);
      END
      """,
      "DROP TRIGGER fonts_fts_update"
    )
  end
end
