defmodule Tela.Media.StockProvider.Unsplash do
  @moduledoc "Unsplash stock-photo API adapter."
  @behaviour Tela.Media.StockProvider

  alias Tela.Media.HTTPcClient

  @base_url "https://api.unsplash.com"
  @per_page 20

  @spec search(String.t(), pos_integer()) ::
          {:ok, %{items: [map()], next_page: pos_integer() | nil}} | {:error, term()}
  @impl true
  def search(query, page) do
    with {:ok, api_key} <- api_key(),
         {:ok, response} <-
           request(
             "#{@base_url}/search/photos?#{URI.encode_query(%{query: query, page: page, per_page: @per_page})}",
             api_key
           ),
         {:ok, %{"results" => photos} = decoded} when is_list(photos) <-
           decode_response(response) do
      items = Enum.flat_map(photos, &normalize/1)
      next_page = next_page(decoded, items, page)
      {:ok, %{items: items, next_page: next_page}}
    else
      {:ok, _response} -> {:error, :invalid_provider_response}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec resolve(String.t()) :: {:ok, map()} | {:error, term()}
  @impl true
  def resolve(external_id) do
    with true <- valid_id?(external_id),
         {:ok, api_key} <- api_key(),
         {:ok, response} <- request("#{@base_url}/photos/#{external_id}", api_key),
         {:ok, photo} <- decode_response(response),
         {:ok, details} <- photo_details(photo) do
      {:ok, details}
    else
      false -> {:error, :invalid_external_id}
      {:error, {:provider_http_error, 404}} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec select(String.t()) :: {:ok, map()} | {:error, term()}
  def select(external_id) do
    with {:ok, photo} <- resolve(external_id),
         {:ok, api_key} <- api_key(),
         :ok <- track_download(photo.download_location, api_key) do
      {:ok, photo}
    end
  end

  defp normalize(photo) do
    with {:ok, id} <- photo_id(photo),
         {:ok, urls} <- fetch_map(photo, "urls"),
         {:ok, thumb_url} <- first_image_url(urls, ["regular", "small", "thumb"]),
         {:ok, full_url} <- first_image_url(urls, ["full", "raw", "regular"]),
         {:ok, user} <- fetch_map(photo, "user"),
         {:ok, author} <- fetch_binary(user, "name"),
         {:ok, author_links} <- fetch_map(user, "links"),
         {:ok, author_url} <- attribution_url(author_links, "html"),
         {:ok, links} <- fetch_map(photo, "links"),
         {:ok, source_url} <- attribution_url(links, "html") do
      [
        %{
          external_id: id,
          provider: :unsplash,
          thumb_url: thumb_url,
          full_url: full_url,
          author: author,
          author_url: author_url,
          source_url: source_url
        }
      ]
    else
      _ -> []
    end
  end

  defp photo_details(photo) do
    with {:ok, id} <- photo_id(photo),
         {:ok, urls} <- fetch_map(photo, "urls"),
         {:ok, url} <- first_image_url(urls, ["full", "raw"]),
         {:ok, thumb_url} <- first_image_url(urls, ["regular", "small", "thumb"]),
         {:ok, user} <- fetch_map(photo, "user"),
         {:ok, author} <- fetch_binary(user, "name"),
         {:ok, author_links} <- fetch_map(user, "links"),
         {:ok, author_url} <- attribution_url(author_links, "html"),
         {:ok, links} <- fetch_map(photo, "links"),
         {:ok, source_url} <- attribution_url(links, "html"),
         {:ok, download_location} <- fetch_binary(links, "download_location"),
         :ok <- validate_api_url(download_location) do
      {:ok,
       %{
         external_id: id,
         url: url,
         thumb_url: thumb_url,
         width: positive_integer(photo, "width"),
         height: positive_integer(photo, "height"),
         author: author,
         author_url: author_url,
         source_url: source_url,
         download_location: download_location
       }}
    end
  end

  defp next_page(%{"total_pages" => total_pages}, _items, page)
       when is_integer(total_pages) and total_pages > page,
       do: page + 1

  defp next_page(_decoded, _items, _page), do: nil

  defp track_download(url, api_key) do
    with :ok <- validate_api_url(url),
         {:ok, _response} <- request(url, api_key) do
      :ok
    end
  end

  defp api_key do
    case Application.get_env(:tela, :unsplash_access_key) do
      key when is_binary(key) ->
        if String.trim(key) == "", do: {:error, :missing_api_key}, else: {:ok, key}

      _ ->
        {:error, :missing_api_key}
    end
  end

  defp request(url, api_key) do
    headers = [{"authorization", "Client-ID " <> api_key}]

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

  defp photo_id(%{"id" => id}) when is_binary(id) and id != "" do
    if valid_id?(id), do: {:ok, id}, else: {:error, :invalid_provider_response}
  end

  defp photo_id(%{"id" => id}) when is_integer(id) and id > 0,
    do: {:ok, Integer.to_string(id)}

  defp photo_id(_photo), do: {:error, :invalid_provider_response}

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

  defp first_image_url(map, [key | rest]) do
    case fetch_binary(map, key) do
      {:ok, url} ->
        if valid_image_url?(url), do: {:ok, url}, else: first_image_url(map, rest)

      _ ->
        first_image_url(map, rest)
    end
  end

  defp first_image_url(_map, []), do: {:error, :invalid_provider_response}

  defp attribution_url(map, key) do
    with {:ok, url} <- fetch_binary(map, key) do
      if valid_attribution_url?(url),
        do: {:ok, with_utm_params(url)},
        else: {:error, :invalid_provider_response}
    end
  end

  defp with_utm_params(url) do
    uri = URI.parse(url)

    params =
      uri.query |> then(&URI.decode_query(&1 || "")) |> Map.drop(["utm_source", "utm_medium"])

    base_query = URI.encode_query(params)
    query = Enum.reject([base_query, "utm_source=tela", "utm_medium=referral"], &(&1 == ""))
    URI.to_string(%{uri | query: Enum.join(query, "&")})
  end

  defp validate_api_url(url) when is_binary(url) do
    uri = URI.parse(url)

    if uri.scheme == "https" and uri.host == "api.unsplash.com" and is_nil(uri.userinfo) and
         uri.port in [nil, 443] do
      :ok
    else
      {:error, :invalid_provider_response}
    end
  end

  defp validate_api_url(_url), do: {:error, :invalid_provider_response}

  defp valid_image_url?(url) do
    uri = URI.parse(url)

    uri.scheme == "https" and uri.host == "images.unsplash.com" and is_nil(uri.userinfo) and
      uri.port in [nil, 443]
  end

  defp valid_attribution_url?(url) do
    uri = URI.parse(url)

    uri.scheme == "https" and uri.host in ["unsplash.com", "www.unsplash.com"] and
      is_nil(uri.userinfo) and uri.port in [nil, 443]
  end

  defp valid_id?(id) when is_binary(id),
    do: Regex.match?(~r/\A[a-zA-Z0-9_-]+\z/, id)

  defp valid_id?(_id), do: false

  defp positive_integer(map, key) do
    case Map.get(map, key) do
      value when is_integer(value) and value > 0 -> value
      _ -> 0
    end
  end

  defp http_client, do: Application.get_env(:tela, :http_client, HTTPcClient)
end
