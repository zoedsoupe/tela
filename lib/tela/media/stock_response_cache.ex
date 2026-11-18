defmodule Tela.Media.StockResponseCache do
  @moduledoc "Persistent cache for stock-provider JSON responses."

  use Ecto.Schema
  import Ecto.Changeset

  alias Tela.Repo

  @ttl_seconds 24 * 60 * 60

  schema "media_stock_response_caches" do
    field :provider, :string
    field :cache_key, :string
    field :response_body, :string
    field :expires_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
          provider: String.t() | nil,
          cache_key: String.t() | nil,
          response_body: String.t() | nil,
          expires_at: DateTime.t() | nil
        }

  @spec fetch(atom(), String.t()) :: {:ok, String.t()} | :miss
  def fetch(provider, cache_key) when is_atom(provider) and is_binary(cache_key) do
    case Repo.get_by(__MODULE__, provider: Atom.to_string(provider), cache_key: cache_key) do
      nil ->
        :miss

      %__MODULE__{expires_at: expires_at} = entry ->
        if DateTime.compare(expires_at, now()) == :gt do
          {:ok, entry.response_body}
        else
          Repo.delete(entry)
          :miss
        end
    end
  end

  @spec store(atom(), String.t(), String.t()) :: :ok | {:error, Ecto.Changeset.t()}
  def store(provider, cache_key, response_body)
      when is_atom(provider) and is_binary(cache_key) and is_binary(response_body) do
    attrs = %{
      provider: Atom.to_string(provider),
      cache_key: cache_key,
      response_body: response_body,
      expires_at: DateTime.add(now(), @ttl_seconds, :second)
    }

    case %__MODULE__{}
         |> changeset(attrs)
         |> Repo.insert(on_conflict: :nothing, conflict_target: [:provider, :cache_key]) do
      {:ok, _entry} -> :ok
      {:error, changeset} -> {:error, changeset}
    end
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:provider, :cache_key, :response_body, :expires_at])
    |> validate_required([:provider, :cache_key, :response_body, :expires_at])
    |> unique_constraint([:provider, :cache_key],
      name: :media_stock_response_caches_provider_cache_key_index
    )
  end

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
end
