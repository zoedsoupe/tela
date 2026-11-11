defmodule Tela.Designs.Preset do
  @moduledoc "Built-in page size presets."

  @presets [
    %{
      id: "post-instagram",
      name: "Post do Instagram",
      width: 1080,
      height: 1350,
      category: "social"
    },
    %{id: "story", name: "Story", width: 1080, height: 1920, category: "social"},
    %{id: "a4", name: "A4", width: 794, height: 1123, category: "impresso"},
    %{
      id: "apresentacao-16-9",
      name: "Apresentação 16:9",
      width: 1920,
      height: 1080,
      category: "apresentacao"
    },
    %{id: "thumbnail", name: "Thumbnail", width: 1280, height: 720, category: "social"}
  ]

  @spec all() :: [map()]
  def all, do: @presets

  @spec fetch(String.t()) :: {:ok, map()} | {:error, :unknown_preset}
  def fetch(id) when is_binary(id) do
    case Enum.find(@presets, &(&1.id == id)) do
      nil -> {:error, :unknown_preset}
      preset -> {:ok, preset}
    end
  end
end
