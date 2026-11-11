defmodule Tela.Designs.PresetTest do
  use ExUnit.Case, async: true
  alias Tela.Designs.Preset

  test "ships the five MVP formats" do
    assert Enum.map(Preset.all(), & &1.id) == [
             "post-instagram",
             "story",
             "a4",
             "apresentacao-16-9",
             "thumbnail"
           ]
  end

  test "fetches dimensions and rejects unknown formats" do
    assert {:ok, %{width: 1920, height: 1080, category: "apresentacao"}} =
             Preset.fetch("apresentacao-16-9")

    assert {:error, :unknown_preset} = Preset.fetch("unknown")
  end
end
