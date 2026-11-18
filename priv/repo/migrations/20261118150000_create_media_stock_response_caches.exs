defmodule Tela.Repo.Migrations.CreateMediaStockResponseCaches do
  use Ecto.Migration

  def change do
    create table(:media_stock_response_caches) do
      add :provider, :string, null: false
      add :cache_key, :text, null: false
      add :response_body, :text, null: false
      add :expires_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:media_stock_response_caches, [:provider, :cache_key],
             name: :media_stock_response_caches_provider_cache_key_index
           )

    create index(:media_stock_response_caches, [:expires_at])
  end
end
