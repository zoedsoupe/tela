defmodule Tela.Repo do
  use Ecto.Repo,
    otp_app: :tela,
    adapter: Ecto.Adapters.SQLite3
end
