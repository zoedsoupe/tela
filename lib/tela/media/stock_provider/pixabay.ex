defmodule Tela.Media.StockProvider.Pixabay do
  @moduledoc "Pixabay stock-photo API adapter."
  @behaviour Tela.Media.StockProvider

  alias Tela.Media.HTTPcClient
  alias Tela.Media.StockResponseCache

  @base_url "https://pixabay.com/api/"
  @per_page 20
  @image_type "all"

  @spec search(String.t(), pos_integer()) ::
          {:ok, %{items: [map()], next_page: pos_integer() | nil}} | {:error, term()}
  @impl true
  def search(query, page) do
    query = String.trim(query)
    cache_key = search_cache_key(query, page)

    with {:ok, api_key} <- api_key(),
         {:ok, response} <- cached_request(cache_key, %{key: api_key, q: query, page: page}),
         {:ok, %{"hits" => hits} = decoded} when is_list(hits) <- decode_response(response) do
      items = Enum.flat_map(hits, &normalize/1)
      total_hits = integer_value(decoded, "totalHits", 0)
      next_page = if items != [] and page * @per_page < total_hits, do: page + 1
      {:ok, %{items: items, next_page: next_page}}
    end
  end

  @spec resolve(String.t()) ::
          {:ok, %{url: String.t(), author: String.t() | nil}} | {:error, term()}
  @impl true
  def resolve(external_id) do
    with true <- numeric_id?(external_id),
         cache_key <- resolve_cache_key(external_id),
         {:ok, api_key} <- api_key(),
         {:ok, response} <- cached_request(cache_key, %{key: api_key, id: external_id}),
         {:ok, %{"hits" => [%{} = photo | _]}} <- decode_response(response),
         {:ok, url} <- first_binary(photo, ["largeImageURL", "vectorURL"]),
         {:ok, author} <- optional_binary(photo, "user") do
      {:ok, %{url: url, author: author}}
    else
      false -> {:error, :invalid_external_id}
      {:ok, %{"hits" => []}} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_provider_response}
    end
  end

  defp normalize(%{"id" => id} = photo) do
    with {:ok, full_url} <- first_binary(photo, ["largeImageURL", "vectorURL"]),
         {:ok, thumb_url} <- first_binary(photo, ["previewURL", "webformatURL"]),
         {:ok, author} <- optional_binary(photo, "user") do
      [
        %{
          external_id: to_string(id),
          provider: :pixabay,
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

  defp request(params) do
    url =
      @base_url <>
        "?" <>
        URI.encode_query(Map.put(params, :image_type, @image_type))

    case http_client().get(url, [], timeout: 10_000) do
      {:ok, %{status: status, body: body}} when status in 200..299 -> {:ok, body}
      {:ok, %{status: status}} -> {:error, {:provider_http_error, status}}
      {:error, reason} -> {:error, {:provider_request_failed, reason}}
    end
  end

  defp cached_request(cache_key, params) do
    case StockResponseCache.fetch(:pixabay, cache_key) do
      {:ok, response} ->
        {:ok, response}

      :miss ->
        with {:ok, response} <- request(params),
             :ok <- StockResponseCache.store(:pixabay, cache_key, response) do
          {:ok, response}
        end
    end
  end

  defp search_cache_key(query, page) do
    normalized_query = query |> String.trim() |> String.downcase()
    "search:" <> URI.encode_query(%{q: normalized_query, page: page, image_type: @image_type})
  end

  defp resolve_cache_key(external_id) do
    "resolve:" <> URI.encode_query(%{id: external_id, image_type: @image_type})
  end

  defp api_key do
    case Application.get_env(:tela, :pixabay_api_key) do
      key when is_binary(key) and key != "" -> {:ok, key}
      _ -> {:error, :missing_api_key}
    end
  end

  defp decode_response(body) when is_binary(body) do
    case JSON.decode(body) do
      {:ok, %{"hits" => hits} = decoded} when is_list(hits) -> {:ok, decoded}
      {:ok, decoded} when is_map(decoded) -> {:error, :invalid_provider_response}
      _ -> {:error, :invalid_provider_response}
    end
  end

  defp fetch_binary(map, key) do
    case Map.fetch(map, key) do
      {:ok, value} when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, :invalid_provider_response}
    end
  end

  defp first_binary(map, [key | rest]) do
    case fetch_binary(map, key) do
      {:ok, value} -> {:ok, value}
      _ -> first_binary(map, rest)
    end
  end

  defp first_binary(_map, []), do: {:error, :invalid_provider_response}

  defp optional_binary(map, key) do
    case Map.get(map, key) do
      value when is_binary(value) -> {:ok, value}
      nil -> {:ok, nil}
      _ -> {:error, :invalid_provider_response}
    end
  end

  defp integer_value(map, key, default) do
    case Map.get(map, key) do
      value when is_integer(value) and value >= 0 -> value
      _ -> default
    end
  end

  defp numeric_id?(id), do: is_binary(id) and Regex.match?(~r/\A\d+\z/, id)
  defp http_client, do: Application.get_env(:tela, :http_client, HTTPcClient)
end
