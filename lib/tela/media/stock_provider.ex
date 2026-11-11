defmodule Tela.Media.StockProvider do
  @moduledoc "Behaviour for remote stock-photo providers."

  @callback search(String.t(), pos_integer()) ::
              {:ok, %{items: [map()], next_page: pos_integer() | nil}} | {:error, term()}
  @callback resolve(String.t()) ::
              {:ok, %{url: String.t(), author: String.t() | nil}} | {:error, term()}
end
