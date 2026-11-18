defmodule Tela.Catalog.PackSource do
  @moduledoc "HTTP boundary for retrieving a pinned element-pack resource."

  @callback fetch(term(), String.t()) :: {:ok, binary()} | {:error, term()}

  defmodule HTTP do
    @moduledoc false
    @behaviour Tela.Catalog.PackSource

    @max_redirects 3

    @impl true
    def fetch(_state, url), do: request(url, 0)

    defp request(url, redirects) when redirects <= @max_redirects do
      uri = URI.parse(url)

      if uri.scheme != "https" or uri.host not in Tela.Catalog.PackManifest.download_hosts() do
        {:error, {:refused_url, url}}
      else
        :inets.start()
        :ssl.start()

        options = [
          timeout: 60_000,
          connect_timeout: 10_000,
          autoredirect: false,
          ssl: [
            verify: :verify_peer,
            cacerts: :public_key.cacerts_get(),
            server_name_indication: String.to_charlist(uri.host),
            customize_hostname_check: [
              match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
            ]
          ]
        ]

        case :httpc.request(:get, {String.to_charlist(url), []}, options, body_format: :binary) do
          {:ok, {{_version, status, _reason}, _headers, body}} when status in 200..299 ->
            {:ok, body}

          {:ok, {{_version, status, _reason}, headers, _body}}
          when status in [301, 302, 303, 307, 308] ->
            case header(headers, "location") do
              nil -> {:error, {:http_status, status}}
              location -> request(URI.merge(url, location) |> URI.to_string(), redirects + 1)
            end

          {:ok, {{_version, status, _reason}, _headers, _body}} ->
            {:error, {:http_status, status}}

          {:error, reason} ->
            {:error, reason}
        end
      end
    end

    defp request(_url, _redirects), do: {:error, :too_many_redirects}

    defp header(headers, name) do
      Enum.find_value(headers, fn {key, value} ->
        if String.downcase(to_string(key)) == name, do: to_string(value)
      end)
    end
  end
end
