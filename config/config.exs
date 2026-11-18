# General application configuration
import Config

config :tela,
  ecto_repos: [Tela.Repo],
  generators: [timestamp_type: :utc_datetime]

# Serve the bundled Ogg Opus library with a media type browsers understand.
config :mime, :types, %{"audio/ogg" => ["oga", "ogg"]}

# Configure the endpoint
config :tela, TelaWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [json: TelaWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Tela.PubSub,
  live_view: [signing_salt: "fc9KbbEK"]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use JSON for JSON parsing in Phoenix
config :phoenix, :json_library, JSON
config :ecto_sqlite3, :json_library, JSON

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
