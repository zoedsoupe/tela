defmodule Tela.Repo.Migrations.AddShareLinkToken do
  use Ecto.Migration

  def change do
    alter table(:share_links) do
      add :token, :string
    end

    create unique_index(:share_links, [:token])
  end
end
