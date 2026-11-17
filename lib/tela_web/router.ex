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

  pipeline :workspace do
    plug :accepts, ["json"]
    plug :fetch_session
    plug TelaWeb.ProfileSession
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :shared_api do
    plug :accepts, ["json"]
    plug :fetch_session
    plug TelaWeb.ProfileSession
    plug :put_secure_browser_headers
  end

  scope "/", TelaWeb do
    pipe_through :browser

    get "/uploads/design-thumbnails/:id", DesignController, :thumbnail
    get "/uploads/:id", MediaController, :show
    get "/template-assets/:kind/:filename", TemplateController, :asset
    get "/harness", SPAController, :index
    get "/presenter-view.html", SPAController, :presenter
    get "/", SPAController, :index
    post "/profiles", ProfileController, :create
  end

  scope "/api", TelaWeb do
    pipe_through :workspace

    get "/csrf", ProfileController, :csrf
    get "/profiles", ProfileController, :index
    post "/profiles", ProfileController, :create_json
    post "/profiles/select", ProfileController, :select
    delete "/profiles/select", ProfileController, :clear

    get "/designs", DesignController, :index
    post "/designs", DesignController, :create
    post "/designs/bulk", DesignController, :bulk
    delete "/designs/trash", DesignController, :empty_trash
    get "/designs/:design_id/versions", VersionController, :index
    post "/designs/:design_id/versions", VersionController, :create
    get "/designs/:design_id/versions/:id", VersionController, :show
    post "/designs/:design_id/versions/:id/restore", VersionController, :restore
    post "/designs/:id/duplicate", DesignController, :duplicate
    post "/designs/:id/restore", DesignController, :restore
    put "/designs/:id/thumbnail", DesignController, :set_thumbnail
    get "/designs/:id", DesignController, :show
    patch "/designs/:id", DesignController, :update
    delete "/designs/:id", DesignController, :delete

    get "/folders", FolderController, :index
    post "/folders", FolderController, :create
    patch "/folders/:id", FolderController, :update
    delete "/folders/:id", FolderController, :delete

    get "/template-categories", TemplateController, :categories
    get "/templates", TemplateController, :index
    post "/templates/:slug/use", TemplateController, :use_template
    get "/templates/:slug", TemplateController, :show
    get "/size-presets", TemplateController, :size_presets

    get "/elements/packs", ElementController, :packs
    get "/elements", ElementController, :index
    get "/fonts", FontController, :index
    get "/fonts/mine", FontController, :mine
    post "/fonts/mine", FontController, :create
    delete "/fonts/mine/:id", FontController, :delete
    get "/fonts/files/:id", FontController, :file

    get "/assets", AssetController, :index
    post "/assets", AssetController, :create
    delete "/assets/:id", AssetController, :delete

    get "/brand_kits", BrandController, :index
    post "/brand_kits", BrandController, :create
    patch "/brand_kits/:id", BrandController, :update
    delete "/brand_kits/:id", BrandController, :delete

    get "/designs/:design_id/comments", CommentController, :index
    post "/designs/:design_id/comments", CommentController, :create
    patch "/comments/:id", CommentController, :update
    delete "/comments/:id", CommentController, :delete

    get "/designs/:design_id/share_links", ShareController, :index
    post "/designs/:design_id/share_links", ShareController, :create
    patch "/share_links/:id", ShareController, :update
    delete "/share_links/:id", ShareController, :delete
  end

  scope "/api", TelaWeb do
    pipe_through :api

  end

  scope "/api/shared", TelaWeb do
    pipe_through :shared_api

    get "/:token", SharedController, :show
    patch "/:token", SharedController, :update
    get "/:token/comments", SharedController, :comments
    post "/:token/comments", SharedController, :create_comment
    post "/:token/versions/:id/restore", SharedController, :restore_version
  end

  scope "/api", TelaWeb do
    pipe_through :api

    match :*, "/*path", SPAController, :api_not_found
  end

  scope "/", TelaWeb do
    pipe_through :browser

    get "/*path", SPAController, :index
  end
end
