defmodule Tela.Media.StockProvider.Wikimedia do
  @moduledoc "Wikimedia Commons stock-photo API adapter."
  @behaviour Tela.Media.StockProvider

  alias Tela.Media.HTTPcClient

  @api_url "https://commons.wikimedia.org/w/api.php"
  @per_page 20

  @spec search(String.t(), pos_integer()) ::
          {:ok, %{items: [map()], next_page: pos_integer() | nil}} | {:error, term()}
  @impl true
  def search(query, page) do
    params = %{
      action: "query",
      generator: "search",
      gsrsearch: query,
      gsrnamespace: 6,
      gsrlimit: @per_page,
      gsroffset: (page - 1) * @per_page,
      prop: "imageinfo",
      iiprop: "url|extmetadata",
      iiurlwidth: 480,
      format: "json",
      formatversion: 2,
      uselang: "pt-br"
    }

    with {:ok, response} <- request(params),
         {:ok, decoded} <- decode_response(response) do
      pages = pages(decoded)
      items = Enum.flat_map(pages, &normalize/1)
      next_page = if items != [] and Map.has_key?(decoded, "continue"), do: page + 1
      {:ok, %{items: items, next_page: next_page}}
    end
  end

  @spec resolve(String.t()) ::
          {:ok, %{url: String.t(), author: String.t() | nil}} | {:error, term()}
  @impl true
  def resolve(external_id) do
    with true <- numeric_id?(external_id),
         {:ok, response} <-
           request(%{
             action: "query",
             pageids: external_id,
             prop: "imageinfo",
             iiprop: "url|extmetadata",
             format: "json",
             formatversion: 2
           }),
         {:ok, decoded} <- decode_response(response),
         [%{} = page | _] <- pages(decoded),
         {:ok, [image_info | _]} <- fetch_list(page, "imageinfo"),
         {:ok, url} <- fetch_binary(image_info, "url"),
         {:ok, author} <- author(image_info) do
      {:ok, %{url: url, author: author}}
    else
      false -> {:error, :invalid_external_id}
      [] -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_provider_response}
    end
  end

  defp normalize(%{"pageid" => page_id, "title" => title, "imageinfo" => [image_info | _]}) do
    with {:ok, full_url} <- fetch_binary(image_info, "url"),
         {:ok, thumb_url} <- optional_binary(image_info, "thumburl"),
         {:ok, author} <- author(image_info) do
      thumb_url = thumb_url || full_url

      [
        %{
          external_id: to_string(page_id),
          provider: :wikimedia,
          thumb_url: thumb_url,
          full_url: full_url,
          author: author || title
        }
      ]
    else
      _ -> []
    end
  end

  defp normalize(_page), do: []

  defp request(params) do
    url = @api_url <> "?" <> URI.encode_query(params)

    case http_client().get(url, [{"user-agent", "Tela/1.0 (Wikimedia Commons image search)"}],
           timeout: 15_000
         ) do
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

  defp pages(%{"query" => %{"pages" => pages}}) when is_list(pages), do: pages

  defp pages(%{"query" => %{"pages" => pages}}) when is_map(pages) do
    pages
    |> Map.values()
    |> Enum.sort_by(&Map.get(&1, "index", 0))
  end

  defp pages(_decoded), do: []

  defp fetch_list(map, key) do
    case Map.fetch(map, key) do
      {:ok, value} when is_list(value) -> {:ok, value}
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
      value when is_binary(value) and value != "" -> {:ok, value}
      nil -> {:ok, nil}
      _ -> {:error, :invalid_provider_response}
    end
  end

  defp author(image_info) do
    metadata = Map.get(image_info, "extmetadata", %{})

    case Map.get(metadata, "Artist") do
      %{"value" => value} when is_binary(value) -> {:ok, strip_html(value)}
      _ -> {:ok, nil}
    end
  end

  defp strip_html(value), do: Regex.replace(~r/<[^>]*>/, value, "") |> String.trim()

  defp numeric_id?(id), do: is_binary(id) and Regex.match?(~r/\A\d+\z/, id)
  defp http_client, do: Application.get_env(:tela, :http_client, HTTPcClient)
end
