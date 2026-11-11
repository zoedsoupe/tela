defmodule Tela.Fonts.Seed do
  @moduledoc "Seeds the offline catalog with common device-provided font families."

  alias Tela.Fonts.Family
  alias Tela.Repo

  @families [
    {"Arial", "sans-serif"},
    {"Helvetica", "sans-serif"},
    {"Verdana", "sans-serif"},
    {"Tahoma", "sans-serif"},
    {"Trebuchet MS", "sans-serif"},
    {"Georgia", "serif"},
    {"Times New Roman", "serif"},
    {"Palatino Linotype", "serif"},
    {"Garamond", "serif"},
    {"Courier New", "monospace"},
    {"Impact", "display"},
    {"Comic Sans MS", "handwriting"}
  ]

  @doc "Idempotently inserts the device font fallback list."
  def seed! do
    Enum.with_index(@families, 1)
    |> Enum.each(fn {{family, category}, popularity} ->
      Repo.insert!(
        Family.changeset(%Family{}, %{
          family: family,
          normalized_name: Tela.Fonts.normalized_name(family),
          category: category,
          scripts: %{values: ["latin"]},
          is_variable: false,
          is_user_font: false,
          variants: %{items: []},
          popularity: popularity
        }),
        on_conflict: :nothing,
        conflict_target: :normalized_name
      )
    end)

    %{system: length(@families)}
  end
end
