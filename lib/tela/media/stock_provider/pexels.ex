defmodule Tela.Media.StockProvider.Pexels do
  @moduledoc "Pexels stock-photo API adapter."
  @behaviour Tela.Media.StockProvider

  alias Tela.Media.HTTPcClient

  @base_url "https://api.pexels.com/v1"

  @spec search(String.t(), pos_integer()) ::
          {:ok, %{items: [map()], next_page: pos_integer() | nil}} | {:error, term()}
  @impl true
  def search(query, page) do
    with {:ok, api_key} <- api_key(),
         {:ok, response} <-
           request(
             "#{@base_url}/search?#{URI.encode_query(%{query: query, page: page, per_page: 20})}",
             [{"authorization", api_key}]
           ),
         {:ok, %{"photos" => photos} = decoded} when is_list(photos) <- decode_response(response) do
      items = Enum.flat_map(photos, &normalize/1)
      next_page = next_page(decoded, items, page)
      {:ok, %{items: items, next_page: next_page}}
    else
      {:ok, _response} -> {:error, :invalid_provider_response}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec resolve(String.t()) ::
          {:ok, %{url: String.t(), author: String.t() | nil}} | {:error, term()}
  @impl true
  def resolve(external_id) do
    with true <- numeric_id?(external_id),
         {:ok, api_key} <- api_key(),
         {:ok, response} <-
           request("#{@base_url}/photos/#{external_id}", [{"authorization", api_key}]),
         {:ok, photo} <- decode_response(response),
         {:ok, source} <- fetch_map(photo, "src"),
         {:ok, url} <- fetch_binary(source, "original"),
         {:ok, author} <- optional_binary(photo, "photographer") do
      {:ok, %{url: url, author: author}}
    else
      false -> {:error, :invalid_external_id}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize(%{"id" => id, "photographer" => author, "src" => source})
       when (is_integer(id) or is_binary(id)) and is_binary(author) and is_map(source) do
    with {:ok, full_url} <- fetch_binary(source, "original"),
         {:ok, thumb_url} <- fetch_binary(source, "medium") do
      [
        %{
          external_id: to_string(id),
          provider: :pexels,
          thumb_url: thumb_url,
          full_url: full_url,
          author: author
        }
      ]
    else
      _ -> []
    end
  end

  defp normalize(_photo), do: []

  defp next_page(%{"next_page" => value}, _items, page) when is_binary(value) and value != "",
    do: page + 1

  defp next_page(%{"next_page" => nil}, _items, _page), do: nil
  defp next_page(_decoded, [], _page), do: nil
  defp next_page(_decoded, _items, page), do: page + 1

  defp api_key do
    case Application.get_env(:tela, :pexels_api_key) do
      key when is_binary(key) and key != "" -> {:ok, key}
      _ -> {:error, :missing_api_key}
    end
  end

  defp request(url, headers) do
    case http_client().get(url, headers, timeout: 10_000) do
      {:ok, %{status: status, body: body}} when status in 200..299 -> {:ok, body}
      {:ok, %{status: status}} -> {:error, {:provider_http_error, status}}
      {:error, reason} -> {:error, {:provider_request_failed, reason}}
    end
  end

  defp decode_response(body) when is_binary(body) do
    case JSON.decode(body) do
      {:ok, decoded} when is_map(decoded) -> {:ok, decoded}
      _ -> {:error, :invalid_provider_response}
    end
  end

  defp fetch_map(map, key) do
    case Map.fetch(map, key) do
      {:ok, value} when is_map(value) -> {:ok, value}
      _ -> {:error, :invalid_provider_response}
    end
  end

  defp fetch_binary(map, key) do
    case Map.fetch(map, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, :invalid_provider_response}
    end
  end

  defp optional_binary(map, key) do
    case Map.get(map, key) do
      value when is_binary(value) -> {:ok, value}
      nil -> {:ok, nil}
      _ -> {:error, :invalid_provider_response}
    end
  end

  defp numeric_id?(id), do: is_binary(id) and Regex.match?(~r/\A\d+\z/, id)
  defp http_client, do: Application.get_env(:tela, :http_client, HTTPcClient)
end
