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
end
