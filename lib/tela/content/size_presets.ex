defmodule Tela.Content.SizePresets do
  @moduledoc "Loads the bundled Portuguese size-preset tree."

  @spec all() :: map()
  def all do
    path = :tela |> :code.priv_dir() |> List.to_string() |> Path.join("content/size_presets.json")

    path
    |> File.read!()
    |> JSON.decode!()
  end
end
