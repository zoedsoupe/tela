defmodule Tela.Media.Format do
  @moduledoc false

  import Bitwise

  @png_signature <<137, 80, 78, 71, 13, 10, 26, 10>>
  @webp_signature "WEBP"
  @jpeg_sof_markers [0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF]

  @type media_info :: %{
          content_type: String.t(),
          width: non_neg_integer(),
          height: non_neg_integer(),
          extension: String.t()
        }

  @spec inspect(binary()) :: {:ok, media_info()} | {:error, :unsupported_media}
  def inspect(
        <<@png_signature, 0, 0, 0, 13, "IHDR", width::unsigned-big-32, height::unsigned-big-32,
          _rest::binary>>
      )
      when width > 0 and height > 0 do
    {:ok, info("image/png", width, height, ".png")}
  end

  def inspect(<<0xFF, 0xD8, 0xFF, rest::binary>>) do
    case jpeg_dimensions(rest) do
      {:ok, width, height} -> {:ok, info("image/jpeg", width, height, ".jpg")}
      :error -> {:error, :unsupported_media}
    end
  end

  def inspect(<<"RIFF", _size::unsigned-little-32, @webp_signature, chunks::binary>>) do
    case webp_dimensions(chunks) do
      {:ok, width, height} -> {:ok, info("image/webp", width, height, ".webp")}
      :error -> {:error, :unsupported_media}
    end
  end

  def inspect(binary) when is_binary(binary) do
    case svg_dimensions(binary) do
      {:ok, width, height} -> {:ok, info("image/svg+xml", width, height, ".svg")}
      :error -> {:error, :unsupported_media}
    end
  end

  def inspect(_binary), do: {:error, :unsupported_media}

  defp info(content_type, width, height, extension) do
    %{content_type: content_type, width: width, height: height, extension: extension}
  end

  defp jpeg_dimensions(<<0xFF, marker, rest::binary>>)
       when marker not in [0x00, 0xFF, 0xD8, 0xD9] do
    if marker in @jpeg_sof_markers do
      case rest do
        <<_segment_length::unsigned-big-16, _precision, height::unsigned-big-16,
          width::unsigned-big-16, _::binary>>
        when width > 0 and height > 0 ->
          {:ok, width, height}

        _ ->
          :error
      end
    else
      skip_jpeg_segment(marker, rest)
    end
  end

  defp jpeg_dimensions(<<0xFF, marker, rest::binary>>) when marker in [0xD8, 0xD9, 0x01] do
    jpeg_dimensions(rest)
  end

  defp jpeg_dimensions(<<_byte, rest::binary>>), do: jpeg_dimensions(rest)
  defp jpeg_dimensions(<<>>), do: :error

  defp skip_jpeg_segment(marker, rest)
       when marker in [0xD0, 0xD1, 0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7] do
    jpeg_dimensions(rest)
  end

  defp skip_jpeg_segment(_marker, <<length::unsigned-big-16, segment::binary>>)
       when length >= 2 do
    segment_size = length - 2

    if byte_size(segment) >= segment_size do
      <<_segment::binary-size(^segment_size), rest::binary>> = segment
      jpeg_dimensions(rest)
    else
      :error
    end
  end

  defp skip_jpeg_segment(_marker, _rest), do: :error

  defp webp_dimensions(
         <<"VP8X", _chunk_size::unsigned-little-32, _flags, _reserved::binary-size(3),
           width::unsigned-little-24, height::unsigned-little-24, _::binary>>
       ) do
    {:ok, width + 1, height + 1}
  end

  defp webp_dimensions(
         <<"VP8L", _chunk_size::unsigned-little-32, 0x2F, b0, b1, b2, b3, _::binary>>
       ) do
    width = 1 + b0 + band(b1, 0x3F) * 256
    height = 1 + band(b1 >>> 6, 0x03) + b2 * 4 + band(b3, 0x0F) * 1024
    {:ok, width, height}
  end

  defp webp_dimensions(
         <<"VP8 ", _chunk_size::unsigned-little-32, _frame_tag::binary-size(3), 0x9D, 0x01, 0x2A,
           width::unsigned-little-16, height::unsigned-little-16, _::binary>>
       ) do
    {:ok, band(width, 0x3FFF), band(height, 0x3FFF)}
  end

  defp webp_dimensions(
         <<_chunk_type::binary-size(4), chunk_size::unsigned-little-32, rest::binary>>
       ) do
    padded_size = chunk_size + rem(chunk_size, 2)

    if byte_size(rest) >= padded_size do
      <<_chunk::binary-size(^padded_size), remaining::binary>> = rest
      webp_dimensions(remaining)
    else
      :error
    end
  end

  defp webp_dimensions(_binary), do: :error

  defp svg_dimensions(binary) do
    with true <- String.valid?(binary),
         true <- svg_document?(binary) do
      {width, height} = svg_attributes(binary)
      {:ok, width || 300, height || 150}
    else
      _ -> :error
    end
  end

  defp svg_document?(binary) do
    prefix = binary |> String.trim_leading("\uFEFF") |> String.trim_leading()

    Regex.match?(
      ~r/\A(?:<\?xml\b[^?]*\?>\s*|<!--.*?-->\s*)*<svg\b[^>]*(?:\/\s*>|>.*<\/svg\s*>)\s*\z/s,
      prefix
    )
  end

  defp svg_attributes(binary) do
    opening_tag =
      case Regex.run(~r/<svg\b[^>]*>/s, binary) do
        [tag] -> tag
        _ -> ""
      end

    width = attribute_dimension(opening_tag, "width")
    height = attribute_dimension(opening_tag, "height")

    case Regex.run(
           ~r/\bviewBox\s*=\s*(["'])\s*[-+\d.eE]+[\s,]+[-+\d.eE]+[\s,]+([\d.eE+\-]+)[\s,]+([\d.eE+\-]+)\s*\1/i,
           opening_tag
         ) do
      [_, _, viewbox_width, viewbox_height] ->
        {width || parse_dimension(viewbox_width), height || parse_dimension(viewbox_height)}

      _ ->
        {width, height}
    end
  end

  defp attribute_dimension(tag, name) do
    regex = Regex.compile!("\\b#{name}\\s*=\\s*(['\"])([^'\"]+)\\1", "i")

    case Regex.run(regex, tag) do
      [_, _, value] -> parse_dimension(value)
      _ -> nil
    end
  end

  defp parse_dimension(value) do
    case Regex.run(~r/^\s*(\d+(?:\.\d+)?)\s*(px|in|cm|mm|pt|pc)?\s*$/i, value) do
      [_, number, unit] ->
        case Float.parse(number) do
          {dimension, _} when dimension > 0 -> round(dimension * unit_scale(unit))
          _ -> nil
        end

      [_, number] ->
        case Float.parse(number) do
          {dimension, _} when dimension > 0 -> round(dimension)
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp unit_scale(unit) when unit in ["in", "IN"], do: 96
  defp unit_scale(unit) when unit in ["cm", "CM"], do: 96 / 2.54
  defp unit_scale(unit) when unit in ["mm", "MM"], do: 96 / 25.4
  defp unit_scale(unit) when unit in ["pt", "PT"], do: 96 / 72
  defp unit_scale(unit) when unit in ["pc", "PC"], do: 16
  defp unit_scale(_unit), do: 1
end
