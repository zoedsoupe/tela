import Config

# Configure your database
config :tela, Tela.Repo,
  database: Path.expand("../tela_dev.db", __DIR__),
  journal_mode: :wal,
  pool_size: 5,
  stacktrace: true,
  show_sensitive_data_on_connection_error: true

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we can use it
# to bundle .js and .css sources.
config :tela, TelaWeb.Endpoint,
  http: [ip: {0, 0, 0, 0}],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "r/zmqbdvxLk045ldPCNlWIlO0xJ1uF0/MxdWeyDBh/og4WfNO3x+3FksIFxCmCqV",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:tela, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:tela, ~w(--watch)]},
    npm: ["--prefix", "frontend", "run", "build", "--", "--watch"]
  ]

# Enable dev routes for dashboard and mailbox
config :tela, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :default_formatter, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  # Include debug annotations and locations in rendered markup.
  # Changing this configuration will require mix clean and a full recompile.
  debug_heex_annotations: true,
  debug_attributes: true,
  # Enable helpful, but potentially expensive runtime checks
  enable_expensive_runtime_checks: true
