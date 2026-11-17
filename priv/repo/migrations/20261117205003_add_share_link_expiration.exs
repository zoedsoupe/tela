defmodule Tela.Repo.Migrations.AddShareLinkExpiration do
  use Ecto.Migration

  def change do
    alter table(:share_links) do
      add :expires_at, :utc_datetime
    end
  end
end
