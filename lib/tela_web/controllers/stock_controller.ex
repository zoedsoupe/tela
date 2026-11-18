defmodule TelaWeb.StockController do
  use TelaWeb, :controller

  alias Tela.Media

  @providers %{
    "pixabay" => :pixabay,
    "wikimedia" => :wikimedia,
    "pexels" => :pexels,
    "unsplash" => :unsplash
  }
  @max_page 1_000

  def search(conn, params) do
    with {:ok, query} <- search_query(params["q"]),
         {:ok, provider} <- search_provider(params["provider"]),
         {:ok, page} <- search_page(params["page"]) do
      case Media.search_external(query, provider, page) do
        {:ok, results} ->
          json(conn, %{
            items: Enum.map(results.items, &search_item/1),
            next_page: results.next_page,
            errors: Enum.map(results.errors, &search_error/1)
          })

        {:error, _reason} ->
          invalid_search(conn)
      end
    else
      :error -> invalid_search(conn)
    end
  end

  def import_asset(conn, %{"provider" => provider_name, "external_id" => external_id}) do
    with {:ok, provider} <- import_provider(provider_name),
         {:ok, external_id} <- external_id(external_id) do
      profile = conn.assigns[:current_profile]
      profile_id = if profile, do: profile.id

      case Media.select_external(profile_id, provider, external_id) do
        {:ok, asset} -> json(conn, %{asset: asset})
        {:error, reason} -> import_error(conn, reason)
      end
    else
      {:error, reason} -> import_error(conn, reason)
    end
  end

  def import_asset(conn, _params), do: import_error(conn, :invalid_external_id)

  defp search_query(query) when is_binary(query) do
    query = String.trim(query)
    if query == "", do: :error, else: {:ok, query}
  end

  defp search_query(_query), do: :error

  defp search_provider(nil), do: {:ok, :all}
  defp search_provider("all"), do: {:ok, :all}

  defp search_provider(provider) when is_binary(provider) do
    case Map.fetch(@providers, provider) do
      {:ok, provider} -> {:ok, provider}
      :error -> :error
    end
  end

  defp search_provider(_provider), do: :error

  defp search_page(nil), do: {:ok, 1}
  defp search_page(page) when is_integer(page) and page in 1..@max_page, do: {:ok, page}

  defp search_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {page, ""} when page in 1..@max_page -> {:ok, page}
      _ -> :error
    end
  end

  defp search_page(_page), do: :error

  defp import_provider(provider) when is_binary(provider) do
    case Map.fetch(@providers, provider) do
      {:ok, provider} -> {:ok, provider}
      :error -> {:error, :unsupported_provider}
    end
  end

  defp import_provider(_provider), do: {:error, :unsupported_provider}

  defp external_id(id) when is_binary(id) do
    id = String.trim(id)
    if id == "", do: {:error, :invalid_external_id}, else: {:ok, id}
  end

  defp external_id(_id), do: {:error, :invalid_external_id}

  defp search_item(item) do
    %{
      external_id: item.external_id,
      provider: provider_name(item.provider),
      thumb_url: item.thumb_url,
      full_url: item.full_url,
      author: item.author
    }
    |> maybe_put(:author_url, Map.get(item, :author_url))
    |> maybe_put(:source_url, Map.get(item, :source_url))
  end

  defp search_error(%{provider: provider, reason: reason}) do
    %{provider: provider_name(provider), code: error_code(reason)}
  end

  defp provider_name(provider) when provider in [:pixabay, :wikimedia, :pexels, :unsplash],
    do: Atom.to_string(provider)

  defp provider_name(_provider), do: "unknown"

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp error_code(:missing_api_key), do: "missing_api_key"
  defp error_code(:unsupported_provider), do: "unsupported_provider"
  defp error_code(:invalid_external_id), do: "invalid_external_id"
  defp error_code(:not_found), do: "not_found"
  defp error_code(:invalid_download_url), do: "invalid_download_url"
  defp error_code(:unsupported_media), do: "unsupported_media"
  defp error_code(:hotlinked_provider), do: "hotlinked_provider"
  defp error_code(:invalid_provider_response), do: "invalid_provider_response"
  defp error_code(:provider_request_failed), do: "provider_request_failed"
  defp error_code({:provider_request_failed, _reason}), do: "provider_request_failed"
  defp error_code({:provider_http_error, _status}), do: "provider_http_error"
  defp error_code({:download_failed, _status}), do: "download_failed"
  defp error_code(_reason), do: "provider_error"

  defp invalid_search(conn) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: %{code: "invalid_search", message: "Query, provider, or page is invalid."}})
  end

  defp import_error(conn, reason) do
    {status, code, message} = import_error_details(reason)

    conn
    |> put_status(status)
    |> json(%{error: %{code: code, message: message}})
  end

  defp import_error_details(:invalid_external_id),
    do: {:bad_request, "invalid_external_id", "A provider and external ID are required."}

  defp import_error_details(:unsupported_provider),
    do: {:bad_request, "unsupported_provider", "The requested provider is not supported."}

  defp import_error_details(:not_found),
    do: {:not_found, "not_found", "The stock image was not found."}

  defp import_error_details(:missing_api_key),
    do: {:unprocessable_entity, "missing_api_key", "The provider is not configured."}

  defp import_error_details(:hotlinked_provider),
    do: {:unprocessable_entity, "hotlinked_provider", "This provider requires a hotlinked asset."}

  defp import_error_details(:invalid_download_url),
    do:
      {:unprocessable_entity, "invalid_download_url",
       "The provider returned an invalid image URL."}

  defp import_error_details(:unsupported_media),
    do:
      {:unprocessable_entity, "unsupported_media", "The provider returned an unsupported image."}

  defp import_error_details(:invalid_provider_response),
    do: {:bad_gateway, "invalid_provider_response", "The provider returned an invalid response."}

  defp import_error_details({:provider_http_error, _status}),
    do: {:bad_gateway, "provider_http_error", "The provider request failed."}

  defp import_error_details({:download_failed, _status}),
    do: {:bad_gateway, "download_failed", "The provider image download failed."}

  defp import_error_details({:provider_request_failed, _reason}),
    do: {:bad_gateway, "provider_request_failed", "The provider request failed."}

  defp import_error_details(_reason),
    do: {:bad_gateway, "provider_error", "The provider could not complete the request."}
end
