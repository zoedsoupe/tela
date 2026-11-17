import Config

if System.get_env("PHX_SERVER") do
  config :tela, TelaWeb.Endpoint, server: true
end

config :tela, TelaWeb.Endpoint, http: [port: String.to_integer(System.get_env("PORT", "4000"))]

config :tela,
  pexels_api_key: System.get_env("PEXELS_API_KEY"),
  pixabay_api_key: System.get_env("PIXABAY_API_KEY"),
  uploads_dir: System.get_env("UPLOADS_DIR", "uploads")

if config_env() == :dev do
  # Reload browser tabs when matching files change.
  config :tela, TelaWeb.Endpoint,
    live_reload: [
      web_console_logger: true,
      patterns: [
        # Static assets, except user uploads
        ~r"priv/static/(?!uploads/).*\.(js|css|png|jpeg|jpg|gif|svg)$"E,
        # Router, Controllers
        ~r"lib/tela_web/router\.ex$"E,
        ~r"lib/tela_web/controllers/.*\.(ex|heex)$"E
      ]
    ]
end

if config_env() == :prod do
  database_path =
    System.get_env("DATABASE_PATH") ||
      raise """
      environment variable DATABASE_PATH is missing.
      For example: /etc/tela/tela.db
      """

  config :tela, Tela.Repo,
    database: database_path,
    pool_size: String.to_integer(System.get_env("POOL_SIZE") || "5")

  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"

  config :tela, TelaWeb.Endpoint,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    secret_key_base: secret_key_base
end
