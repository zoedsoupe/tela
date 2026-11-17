defmodule Tela.Release do
  @moduledoc false

  @app :tela

  @doc "Runs all pending Ecto migrations."
  def migrate do
    load_app()

    Enum.each(repos(), fn repo ->
      {:ok, _, _} =
        Ecto.Migrator.with_repo(
          repo,
          fn repo ->
            Ecto.Migrator.run(repo, Ecto.Migrator.migrations_path(repo), :up, all: true)
          end,
          pool_size: 1
        )
    end)
  end

  @doc "Seeds the bundled templates, catalog assets, and system fonts."
  def seed do
    load_app()

    {:ok, _, _} =
      Ecto.Migrator.with_repo(
        Tela.Repo,
        fn _repo ->
          Tela.Content.Seed.seed!()
          Tela.Catalog.Seed.seed!()
          Tela.Fonts.Seed.seed!()
        end,
        pool_size: 1
      )
  end

  defp load_app do
    Application.load(@app)
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end
end
