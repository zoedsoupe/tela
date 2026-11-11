defmodule Tela.Media.HTTPcClient do
  @moduledoc "httpc implementation of the external media HTTP boundary."
  @behaviour Tela.Media.HTTPClient

  @impl true
  def get(url, headers, options \\ []) do
    request_headers = Enum.map(headers, fn {name, value} -> {String.to_charlist(name), String.to_charlist(value)} end)

    http_options = [
      timeout: Keyword.get(options, :timeout, 10_000),
      connect_timeout: Keyword.get(options, :connect_timeout, 5_000),
      ssl: [verify: :verify_peer]
    ]

    case :httpc.request(:get, {String.to_charlist(url), request_headers}, http_options, body_format: :binary) do
      {:ok, {{_version, status, _reason}, response_headers, body}} ->
        headers = Enum.map(response_headers, fn {name, value} -> {to_string(name), to_string(value)} end)
        {:ok, %{status: status, headers: headers, body: body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
