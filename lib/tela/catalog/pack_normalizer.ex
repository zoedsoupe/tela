defmodule Tela.Catalog.PackNormalizer do
  @moduledoc "Pure parsing, SVG safety checks, and normalization for catalog pack records."

  @max_svg_bytes 2 * 1024 * 1024
  @default_color "#7a64e0"
  @shape_color_attrs ~w(fill stroke stop-color flood-color lighting-color color)
  @hex_color ~r/#[0-9a-fA-F]{3}(?:[0-9a-fA-F]{3})?(?:[0-9a-fA-F]{2})?\b/

  @spec normalize_svg(binary(), map()) ::
          {:ok,
           %{svg: String.t(), width: pos_integer(), height: pos_integer(), colors: [String.t()]}}
          | {:error, term()}
  def normalize_svg(raw, normalize) when is_binary(raw) and is_map(normalize) do
    with :ok <- validate_size(raw),
         :ok <- safe_svg(raw),
         {:ok, viewbox} <- viewbox(raw),
         {:ok, sized_svg, width, height} <- set_size(raw, viewbox, normalize),
         {:ok, painted_svg} <- paint(sized_svg, normalize) do
      colors =
        painted_svg
        |> then(&Regex.scan(@hex_color, &1, capture: :first))
        |> List.flatten()
        |> Enum.map(&String.downcase/1)
        |> Enum.uniq()

      {:ok, %{svg: painted_svg, width: width, height: height, colors: colors}}
    end
  end

  def normalize_svg(_raw, _normalize), do: {:error, :invalid_svg}

  @spec normalize_iconify(binary(), map(), map()) :: {:ok, [map()]} | {:error, term()}
  def normalize_iconify(raw, pack, tag_table \\ %{})

  def normalize_iconify(raw, pack, tag_table) when is_binary(raw) and is_map(pack) do
    with {:ok, decoded} <- JSON.decode(raw),
         true <- is_map(decoded),
         icons when is_map(icons) and map_size(icons) <= 50_000 <- decoded["icons"] do
      aliases = iconify_aliases(decoded["aliases"], icons)
      defaults = positive_dimension(decoded["width"], 16)
      default_height = positive_dimension(decoded["height"], defaults)
      default_left = numeric_offset(decoded["left"], 0)
      default_top = numeric_offset(decoded["top"], 0)

      records =
        Enum.reduce(icons, [], fn {name, icon}, acc ->
          with true <- is_binary(name) and is_map(icon),
               false <- icon["hidden"] == true,
               body when is_binary(body) <- icon["body"],
               width <- positive_dimension(icon["width"], defaults),
               height <- positive_dimension(icon["height"], default_height),
               true <- width > 0 and height > 0 do
            left = numeric_offset(icon["left"], default_left)
            top = numeric_offset(icon["top"], default_top)

            svg =
              ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="#{left} #{top} #{width} #{height}">#{body}</svg>|

            tags = Map.get(tag_table, name, []) ++ Map.get(aliases, name, [])

            case normalize_asset(pack, name, svg, tags, nil) do
              {:ok, record} -> [record | acc]
              _ -> acc
            end
          else
            _ -> acc
          end
        end)

      if records == [], do: {:error, :empty_iconify_pack}, else: {:ok, Enum.reverse(records)}
    else
      _ -> {:error, :invalid_iconify_json}
    end
  end

  def normalize_iconify(_raw, _pack, _tag_table), do: {:error, :invalid_iconify_json}

  @spec normalize_asset(map(), String.t(), binary(), [String.t()], String.t() | nil) ::
          {:ok, map()} | {:skip, term()} | {:error, term()}
  def normalize_asset(pack, name, raw_svg, tags, source_url \\ nil) do
    normalized_name = strip_naming(name, pack.naming)
    key = slug_part(normalized_name)

    cond do
      key == "" ->
        {:skip, :empty_name}

      matches_rule?(pack.naming.skip, normalized_name) ->
        {:skip, :excluded_variant}

      matches_rule?(pack.naming.brand, normalized_name) ->
        {:skip, :brand_logo}

      true ->
        case normalize_svg(raw_svg, pack.normalize) do
          {:ok, normalized} ->
            slug = "#{pack.id}-#{key}"

            name_tags =
              normalized_name |> String.downcase() |> String.split(~r/[^a-z0-9]+/u, trim: true)

            tags = clean_tags(tags ++ name_tags)

            {:ok,
             %{
               slug: slug,
               title_pt: title(normalized_name),
               tags_pt: Enum.join(tags, " "),
               type: pack.kind,
               file_path: "inline:#{slug}",
               pack_slug: pack.id,
               pack_name: pack.name,
               style: pack.style,
               svg: normalized.svg,
               width: normalized.width,
               height: normalized.height,
               colors: %{values: normalized.colors},
               is_recolorable: pack.normalize.mode == "mono",
               license: pack.license.spdx,
               license_url: pack.license.url,
               attribution: pack.attribution,
               source_url: source_url || pack.homepage,
               sort_order: pack.sort_order
             }}

          {:error, reason} ->
            {:skip, reason}
        end
    end
  end

  @spec parse_tag_table(String.t(), binary()) :: {:ok, map()} | {:error, term()}
  def parse_tag_table("none", _data), do: {:ok, %{}}

  def parse_tag_table("phosphor-js", data) when is_binary(data), do: parse_phosphor(data)

  def parse_tag_table(format, data) when is_binary(data) do
    with {:ok, decoded} <- JSON.decode(data),
         {:ok, table} <- tags_for(format, decoded, data) do
      {:ok, table}
    else
      _ -> {:error, :invalid_tag_data}
    end
  end

  defp tags_for("json-map", decoded, _data) when is_map(decoded) do
    {:ok, Map.new(decoded, fn {name, tags} -> {name, clean_tags(List.wrap(tags))} end)}
  end

  defp tags_for("tabler", decoded, _data) when is_map(decoded) do
    table =
      Map.new(decoded, fn {name, entry} ->
        tags =
          if is_map(entry), do: List.wrap(entry["tags"]) ++ List.wrap(entry["category"]), else: []

        {name, clean_tags(tags)}
      end)

    {:ok, table}
  end

  defp tags_for("iconify-categories", decoded, _data) when is_map(decoded) do
    categories = decoded["categories"] || %{}

    if is_map(categories) do
      table =
        Enum.reduce(categories, %{}, fn {category, names}, acc ->
          Enum.reduce(List.wrap(names), acc, fn name, values ->
            if is_binary(name),
              do: Map.update(values, name, [category], &[category | &1]),
              else: values
          end)
        end)

      {:ok, Map.new(table, fn {name, tags} -> {name, clean_tags(tags)} end)}
    else
      {:error, :invalid_tag_data}
    end
  end

  defp tags_for("phosphor-js", _decoded, data), do: parse_phosphor(data)
  defp tags_for(_format, _decoded, _data), do: {:error, :invalid_tag_data}

  defp parse_phosphor(data) do
    source = data

    enum_pattern =
      ~r/(\w+)\s*=\s*\/\* @__PURE__ \*\/\s*\(\((\w+)\)\s*=>\s*\((.*?)\)\)\(\w+\s*\|\|\s*\{\}\)/s

    enums =
      Regex.scan(enum_pattern, source)
      |> Enum.reduce(%{}, fn [_whole, variable, _argument, body], acc ->
        members =
          Regex.scan(~r/\w+\.(\w+)\s*=\s*"([^"]*)"/, body, capture: :all_but_first)
          |> Map.new(fn [member, value] -> {member, value} end)

        Map.put(acc, variable, members)
      end)

    pattern =
      ~r/\{\s*name:\s*"(?<name>[^"]+)",\s*pascal_name:\s*"[^"]*",\s*(?:alias:\s*\{\s*name:\s*"(?<alias>[^"]+)"[^}]*\},\s*)?categories:\s*\[(?<categories>[^\]]*)\],[^\[\]]*?tags:\s*\[(?<tags>[^\]]*)\]/s

    table =
      Regex.scan(pattern, source, capture: ["name", "alias", "categories", "tags"])
      |> Enum.reduce(%{}, fn [name, alias_name, categories, tags], acc ->
        category_values =
          categories
          |> String.split(",")
          |> Enum.flat_map(fn reference ->
            case String.split(String.trim(reference), ".", parts: 2) do
              [variable, member] ->
                case get_in(enums, [variable, member]) do
                  nil -> []
                  value -> [value]
                end

              _ ->
                []
            end
          end)

        values = parse_js_strings(tags) ++ category_values

        values =
          if alias_name == "", do: values, else: [String.replace(alias_name, "-", " ") | values]

        Map.put(acc, name, clean_tags(values))
      end)

    if map_size(table) == 0, do: {:error, :invalid_tag_data}, else: {:ok, table}
  end

  defp parse_js_strings(value) do
    Regex.scan(~r/"((?:[^"\\]|\\.)*)"/, value, capture: :all_but_first)
    |> List.flatten()
  end

  defp iconify_aliases(aliases, icons) when is_map(aliases) do
    Enum.reduce(aliases, %{}, fn
      {alias_name, %{"parent" => parent}}, acc when is_binary(alias_name) ->
        if Map.has_key?(icons, parent) do
          Map.update(
            acc,
            parent,
            [String.replace(alias_name, "-", " ")],
            &[
              String.replace(alias_name, "-", " ") | &1
            ]
          )
        else
          acc
        end

      _entry, acc ->
        acc
    end)
  end

  defp iconify_aliases(_aliases, _icons), do: %{}

  defp positive_dimension(value, _fallback) when is_number(value) and value > 0, do: value
  defp positive_dimension(_value, fallback), do: fallback

  defp numeric_offset(value, _fallback) when is_number(value), do: value
  defp numeric_offset(_value, fallback), do: fallback

  defp validate_size(raw) when byte_size(raw) <= @max_svg_bytes, do: :ok
  defp validate_size(_raw), do: {:error, :svg_too_large}

  defp safe_svg(raw) do
    forbidden = [
      ~r/<!\s*(?:DOCTYPE|ENTITY)\b/i,
      ~r/<\s*script\b/i,
      ~r/<\s*foreignObject\b/i,
      ~r/\s+on[a-z0-9_-]+\s*=/i,
      ~r/javascript\s*:/i,
      ~r/@import\b/i
    ]

    external_href? =
      Regex.scan(~r/(?:xlink:)?href\s*=\s*(["'])(.*?)\1/is, raw, capture: :all_but_first)
      |> Enum.any?(fn [_quote, value] -> not String.starts_with?(String.trim(value), "#") end)

    external_url? =
      Regex.scan(~r/url\(\s*(["']?)(.*?)\1\s*\)/is, raw, capture: :all_but_first)
      |> Enum.any?(fn [_quote, value] -> not String.starts_with?(String.trim(value), "#") end)

    cond do
      Enum.any?(forbidden, &Regex.match?(&1, raw)) -> {:error, :unsafe_svg}
      external_href? or external_url? -> {:error, :external_reference}
      not Regex.match?(~r/<svg\b/i, raw) -> {:error, :not_svg}
      not xml_well_formed?(raw) -> {:error, :invalid_xml}
      true -> :ok
    end
  end

  defp xml_well_formed?(svg) do
    clean =
      svg
      |> String.replace(~r/<!--.*?-->/s, "")
      |> String.replace(~r/<\?xml.*?\?>/is, "")

    tags =
      Regex.scan(
        ~r/<(\/?)([A-Za-z_][A-Za-z0-9_.:-]*)(?:\s+[A-Za-z_:][A-Za-z0-9_.:-]*\s*=\s*(?:"[^"]*"|'[^']*'))*\s*(\/?)>/s,
        clean
      )

    less_than_count = clean |> String.graphemes() |> Enum.count(&(&1 == "<"))

    case tags do
      [[_whole, "", "svg", _self_closing] | _] when length(tags) == less_than_count ->
        balanced_tags?(tags)

      _ ->
        false
    end
  end

  defp balanced_tags?([[_whole, "", "svg", "/"]]), do: true

  defp balanced_tags?([[_whole, "", "svg", ""] | rest]) do
    balance_children(rest, ["svg"])
  end

  defp balanced_tags?(_tags), do: false

  defp balance_children([], []), do: true
  defp balance_children([], _stack), do: false

  defp balance_children([[_whole, closing, name, self_closing] | rest], stack) do
    cond do
      closing == "/" ->
        case stack do
          [^name | tail] -> balance_children(rest, tail)
          _ -> false
        end

      self_closing == "/" ->
        if stack == [], do: false, else: balance_children(rest, stack)

      stack == [] ->
        false

      true ->
        balance_children(rest, [name | stack])
    end
  end

  defp viewbox(svg) do
    case Regex.run(~r/\bviewBox\s*=\s*(["'])(.*?)\1/i, svg, capture: :all_but_first) do
      [_quote, raw] ->
        case raw |> String.replace(",", " ") |> String.split() |> Enum.map(&Float.parse/1) do
          [{x, ""}, {y, ""}, {width, ""}, {height, ""}] when width > 0 and height > 0 ->
            {:ok, {x, y, width, height}}

          _ ->
            {:error, :invalid_viewbox}
        end

      _ ->
        with {:ok, width} <- root_dimension(svg, "width"),
             {:ok, height} <- root_dimension(svg, "height"),
             true <- width > 0 and height > 0 do
          {:ok, {0.0, 0.0, width, height}}
        else
          _ -> {:error, :missing_dimensions}
        end
    end
  end

  defp root_dimension(svg, name) do
    case Regex.run(Regex.compile!("\\b#{name}\\s*=\\s*([\"'])([0-9.]+)(?:px)?\\1", "i"), svg,
           capture: :all_but_first
         ) do
      [_quote, value] ->
        case Float.parse(value) do
          {number, ""} -> {:ok, number}
          _ -> {:error, :invalid_dimension}
        end

      _ ->
        {:error, :invalid_dimension}
    end
  end

  defp set_size(svg, {x, y, view_width, view_height}, normalize) do
    size = normalize.size
    ratio = if is_number(size), do: size / max(view_width, view_height), else: 1.0
    width = view_width * ratio
    height = view_height * ratio
    viewbox = Enum.map_join([x, y, view_width, view_height], " ", &format_number/1)

    svg =
      svg
      |> replace_root_attribute("viewBox", viewbox)
      |> replace_root_attribute("width", format_number(width))
      |> replace_root_attribute("height", format_number(height))

    svg =
      if normalize.frame do
        frame =
          ~s|<rect x="#{format_number(x)}" y="#{format_number(y)}" width="#{format_number(view_width)}" height="#{format_number(view_height)}" fill="none"/>|

        Regex.replace(~r/(<svg\b[^>]*>)/i, svg, "\\1" <> frame, global: false)
      else
        svg
      end

    {:ok, svg, max(round(width), 1), max(round(height), 1)}
  end

  defp replace_root_attribute(svg, name, value) do
    root = Regex.run(~r/<svg\b[^>]*>/i, svg, capture: :first)

    case root do
      [tag] ->
        attr = Regex.compile!("\\s#{name}\\s*=\\s*([\"']).*?\\1", "i")

        updated =
          if Regex.match?(attr, tag) do
            Regex.replace(attr, tag, ~s( #{name}="#{value}"), global: false)
          else
            String.replace_suffix(tag, ">", ~s( #{name}="#{value}">))
          end

        String.replace(svg, tag, updated, global: false)

      _ ->
        svg
    end
  end

  defp paint(svg, %{mode: "mono"} = normalize) do
    color = normalize.color || @default_color

    painted =
      Enum.reduce(@shape_color_attrs, svg, fn attr, value ->
        regex = Regex.compile!("(\\b#{attr}\\s*=\\s*)([\"'])(.*?)\\2", "i")

        Regex.replace(regex, value, fn _full, prefix, quote, paint ->
          prefix <> quote <> normalize_paint(paint, color) <> quote
        end)
      end)

    style_attribute = ~r/(style\s*=\s*)(["'])(.*?)\2/is

    style_property =
      ~r/\b(fill|stroke|stop-color|flood-color|lighting-color|color)\s*:\s*([^;]+)(;?)/i

    painted =
      Regex.replace(style_attribute, painted, fn _full, prefix, quote, declarations ->
        normalized =
          Regex.replace(style_property, declarations, fn _property, name, value, semicolon ->
            "#{name}:#{normalize_paint(value, color)}#{semicolon}"
          end)

        prefix <> quote <> normalized <> quote
      end)

    root = Regex.run(~r/<svg\b[^>]*>/i, painted, capture: :first)

    case root do
      [tag] ->
        if Regex.match?(~r/\bfill\s*=/i, tag) do
          {:ok, painted}
        else
          {:ok, replace_root_attribute(painted, "fill", color)}
        end

      _ ->
        {:error, :not_svg}
    end
  end

  defp paint(svg, %{mode: "colour"}) do
    {:ok, svg}
  end

  defp paint(svg, _normalize), do: {:ok, svg}

  defp normalize_paint(paint, color) do
    if String.downcase(String.trim(paint)) in ["none", "transparent"] or
         String.starts_with?(String.trim(paint), "url(") do
      String.trim(paint)
    else
      color
    end
  end

  defp strip_naming(name, naming) do
    name
    |> String.trim_trailing(".svg")
    |> strip_prefix(naming.strip_prefix)
    |> strip_suffix(naming.strip_suffix)
  end

  defp strip_prefix(name, ""), do: name
  defp strip_prefix(name, prefix), do: String.trim_leading(name, prefix)
  defp strip_suffix(name, ""), do: name
  defp strip_suffix(name, suffix), do: String.trim_trailing(name, suffix)

  defp slug_part(name) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/u, "-")
    |> String.trim("-")
  end

  defp title(name) do
    name
    |> String.trim_trailing(".svg")
    |> String.replace(~r/[-_]+/u, " ")
    |> String.split()
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp clean_tags(tags) do
    tags
    |> Enum.filter(&is_binary/1)
    |> Enum.map(&String.downcase(String.trim(&1)))
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
    |> Enum.take(30)
  end

  defp matches_rule?("", _value), do: false

  defp matches_rule?(pattern, value) do
    case Regex.compile(pattern) do
      {:ok, regex} -> Regex.match?(regex, value)
      _ -> false
    end
  end

  defp format_number(value) do
    value
    |> Float.round(2)
    |> :erlang.float_to_binary(decimals: 2)
    |> String.trim_trailing("0")
    |> String.trim_trailing(".")
    |> case do
      "" -> "0"
      text -> text
    end
  end
end
