defmodule Tela.Repo.Migrations.AddBrandKitIsDefault do
  use Ecto.Migration

  def change do
    alter table(:brand_kits) do
      add :is_default, :boolean, null: false, default: false
    end
  end
end
