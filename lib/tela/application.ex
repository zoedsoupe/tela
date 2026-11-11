defmodule Tela.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Tela.Repo,
      {Ecto.Migrator, repos: ecto_repos(), skip: skip_migrations?()},
      {Phoenix.PubSub, name: Tela.PubSub},
      TelaWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Tela.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp ecto_repos do
    Application.fetch_env!(:tela, :ecto_repos)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    TelaWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp skip_migrations?() do
    # By default, sqlite migrations are run when using a release
    System.get_env("RELEASE_NAME") == nil
  end
end
