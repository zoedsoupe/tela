defmodule Tela.Brands.Kit do
  @moduledoc "A shared brand kit with optional authorship attribution."

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  @type t :: %__MODULE__{
          __meta__: Ecto.Schema.Metadata.t(),
          id: Ecto.UUID.t() | nil,
          created_by_id: Ecto.UUID.t() | nil,
          name: String.t() | nil,
          is_default: boolean(),
          colors: map() | nil,
          fonts: map() | nil,
          logos: map() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "brand_kits" do
    field :created_by_id, :binary_id
    field :name, :string
    field :is_default, :boolean, default: false
    field :colors, :map
    field :fonts, :map
    field :logos, :map

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(kit, attrs) do
    kit
    |> cast(attrs, [:name, :is_default, :colors, :fonts, :logos])
    |> update_change(:name, &String.trim/1)
    |> validate_required([:name, :is_default, :colors, :fonts, :logos])
    |> validate_length(:name, max: 120)
    |> validate_change(:colors, fn :colors, colors ->
      if valid_colors?(colors), do: [], else: [colors: "must contain a values list of hex colors"]
    end)
    |> validate_change(:fonts, fn :fonts, fonts ->
      if valid_fonts?(fonts), do: [], else: [fonts: "must include heading and body fonts"]
    end)
    |> validate_change(:logos, fn :logos, logos ->
      if valid_logos?(logos), do: [], else: [logos: "must contain an items list"]
    end)
  end

  defp valid_colors?(%{"values" => values}) when is_list(values),
    do: Enum.all?(values, &valid_hex_color?/1)

  defp valid_colors?(%{"items" => items}) when is_list(items),
    do: Enum.all?(items, &valid_brand_color?/1)

  defp valid_colors?(items) when is_list(items), do: Enum.all?(items, &valid_brand_color?/1)

  defp valid_colors?(_), do: false

  defp valid_hex_color?(value) when is_binary(value),
    do: Regex.match?(~r/^#[0-9A-Fa-f]{6}$/, value)

  defp valid_hex_color?(_), do: false

  defp valid_fonts?(%{"items" => items}) when is_list(items),
    do: Enum.all?(items, &valid_brand_font?/1)

  defp valid_fonts?(fonts) when is_map(fonts) do
    Enum.all?(["heading", "body"], fn role ->
      case Map.get(fonts, role) || Map.get(fonts, String.to_existing_atom(role)) do
        value when is_binary(value) -> String.trim(value) != ""
        _ -> false
      end
    end)
  end

  defp valid_fonts?(fonts) when is_list(fonts), do: Enum.all?(fonts, &valid_brand_font?/1)

  defp valid_fonts?(_), do: false

  defp valid_logos?(%{"items" => items}) when is_list(items), do: true
  defp valid_logos?(%{items: items}) when is_list(items), do: true
  defp valid_logos?(_), do: false

  defp valid_brand_color?(%{"hex" => hex}), do: valid_hex_color?(hex)
  defp valid_brand_color?(%{hex: hex}), do: valid_hex_color?(hex)
  defp valid_brand_color?(_), do: false

  defp valid_brand_font?(%{"role" => role, "family" => family}),
    do:
      role in ["heading", "subheading", "body"] and is_binary(family) and
        String.trim(family) != ""

  defp valid_brand_font?(%{role: role, family: family}),
    do: role in [:heading, :subheading, :body] and is_binary(family) and String.trim(family) != ""

  defp valid_brand_font?(_), do: false
end
