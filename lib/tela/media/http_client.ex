defmodule Tela.Media.HTTPClient do
  @moduledoc "Minimal HTTP boundary for stock providers and downloads."

  @type header :: {String.t(), String.t()}
  @type response :: %{status: non_neg_integer(), headers: [header()], body: binary()}

  @callback get(String.t(), [header()], keyword()) :: {:ok, response()} | {:error, term()}
end
