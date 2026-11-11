defmodule TelaWeb.Router do
  use TelaWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug TelaWeb.ProfileSession
    plug :fetch_live_flash
    plug :put_root_layout, html: {TelaWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", TelaWeb do
    pipe_through :browser

    live "/", DashboardLive, :index
    post "/profiles", ProfileController, :create
  end

  if Application.compile_env(:tela, :dev_routes, false) do
    scope "/dev", TelaWeb do
      pipe_through :browser

      live "/styleguide", StyleguideLive, :index
    end
  end
end
