defmodule Qiroex.Render.PNG do
  @moduledoc """
  Renders a QR code as a PNG binary.

  Produces a minimal valid PNG file using only Erlang stdlib (`:zlib` for
  DEFLATE compression, `:erlang.crc32` for CRC-32). The image uses an
  indexed color palette.

  ## Options
    - `:module_size` - size of each module in pixels (default: 10)
    - `:quiet_zone` - number of quiet zone modules (default: 4)
    - `:dark_color` - `{r, g, b}` tuple 0-255 (default: `{0, 0, 0}`)
    - `:light_color` - `{r, g, b}` tuple 0-255 (default: `{255, 255, 255}`)
    - `:style` - a `%Qiroex.Style{}` struct for finder pattern colors (optional)
  """

  alias Qiroex.Matrix
  alias Qiroex.Matrix.Regions
  alias Qiroex.Style

  @png_signature <<137, 80, 78, 71, 13, 10, 26, 10>>

  @default_opts %{
    module_size: 10,
    quiet_zone: 4,
    dark_color: {0, 0, 0},
    light_color: {255, 255, 255},
    style: nil
  }

  @doc """
  Renders a QR matrix as a PNG binary.

  ## Parameters
    - `matrix` - a `%Qiroex.Matrix{}` struct
    - `opts` - keyword list of rendering options

  ## Returns
    A PNG binary that can be written directly to a file.
  """
  @spec render(Matrix.t(), keyword()) :: binary()
  def render(%Matrix{} = matrix, opts \\ []) do
    config = parse_opts(opts)
    build_png(matrix, config)
  end

  @doc """
  Renders and writes the PNG directly to a file.

  ## Returns
    `:ok` or `{:error, reason}`
  """
  @spec save(Matrix.t(), Path.t(), keyword()) :: :ok | {:error, term()}
  def save(%Matrix{} = matrix, path, opts \\ []) do
    File.write(path, render(matrix, opts))
  end

  defp parse_opts(opts) do
    %{
      module_size: Keyword.get(opts, :module_size, @default_opts.module_size),
      quiet_zone: Keyword.get(opts, :quiet_zone, @default_opts.quiet_zone),
      dark_color: Keyword.get(opts, :dark_color, @default_opts.dark_color),
      light_color: Keyword.get(opts, :light_color, @default_opts.light_color),
      style: Keyword.get(opts, :style, @default_opts.style)
    }
  end

  defp build_png(matrix, config) do
    %{module_size: mod, quiet_zone: qz, dark_color: dark, light_color: light, style: style} =
      config

    total_modules = matrix.size + 2 * qz
    width = total_modules * mod
    height = total_modules * mod

    if Style.custom_finder?(style) do
      build_styled_png(matrix, width, height, mod, qz, dark, light, style)
    else
      build_simple_png(matrix, width, height, mod, qz, dark, light)
    end
  end

  # Simple 2-color PNG (original path)
  defp build_simple_png(matrix, width, height, mod, qz, dark, light) do
    ihdr = build_ihdr(width, height)
    plte = build_plte([light, dark])
    idat = build_idat_simple(matrix, width, height, mod, qz)
    iend = build_iend()

    IO.iodata_to_binary([@png_signature, ihdr, plte, idat, iend])
  end

  # Multi-color PNG with finder pattern styling
  defp build_styled_png(matrix, width, height, mod, qz, dark, light, style) do
    # Palette: 0=light, 1=dark, 2=finder_outer, 3=finder_inner, 4=finder_eye
    finder_outer = parse_css_color(Style.finder_color(style, :outer, nil), dark)
    finder_inner = parse_css_color(Style.finder_color(style, :inner, nil), light)
    finder_eye = parse_css_color(Style.finder_color(style, :eye, nil), dark)

    palette = [light, dark, finder_outer, finder_inner, finder_eye]

    ihdr = build_ihdr(width, height)
    plte = build_plte(palette)
    region_map = Regions.build_map(matrix)
    idat = build_idat_styled(matrix, region_map, width, height, mod, qz)
    iend = build_iend()

    IO.iodata_to_binary([@png_signature, ihdr, plte, idat, iend])
  end

  # Parse a CSS hex color to {r, g, b} tuple, or use the default tuple
  defp parse_css_color(nil, default_tuple), do: default_tuple

  defp parse_css_color("#" <> hex, _default) when byte_size(hex) == 6 do
    {r, ""} = Integer.parse(String.slice(hex, 0, 2), 16)
    {g, ""} = Integer.parse(String.slice(hex, 2, 2), 16)
    {b, ""} = Integer.parse(String.slice(hex, 4, 2), 16)
    {r, g, b}
  end

  defp parse_css_color(_, default_tuple), do: default_tuple

  # IHDR chunk
  defp build_ihdr(width, height) do
    data = <<
      width::32,
      height::32,
      8::8,
      3::8,
      0::8,
      0::8,
      0::8
    >>

    build_chunk("IHDR", data)
  end

  # PLTE chunk: supports variable number of palette entries
  defp build_plte(colors) do
    data =
      colors
      |> Enum.map(fn {r, g, b} -> <<r::8, g::8, b::8>> end)
      |> IO.iodata_to_binary()

    build_chunk("PLTE", data)
  end

  # Simple IDAT: 2-color indexed
  defp build_idat_simple(matrix, _width, _height, mod, qz) do
    raw_data = build_raw_image_data_simple(matrix, mod, qz)
    compress_idat(raw_data)
  end

  # Styled IDAT: multi-color indexed with region awareness
  defp build_idat_styled(matrix, region_map, _width, _height, mod, qz) do
    raw_data = build_raw_image_data_styled(matrix, region_map, mod, qz)
    compress_idat(raw_data)
  end

  defp compress_idat(raw_data) do
    z = :zlib.open()
    :zlib.deflateInit(z)
    compressed = :zlib.deflate(z, raw_data, :finish)
    :zlib.deflateEnd(z)
    :zlib.close(z)

    build_chunk("IDAT", IO.iodata_to_binary(compressed))
  end

  # Build raw image data for simple 2-color mode
  defp build_raw_image_data_simple(matrix, mod, qz) do
    total_modules = matrix.size + 2 * qz

    module_rows =
      for mr <- 0..(total_modules - 1) do
        row_bytes =
          for mc <- 0..(total_modules - 1) do
            r = mr - qz
            c = mc - qz

            if r >= 0 and r < matrix.size and c >= 0 and c < matrix.size do
              if Matrix.dark?(matrix, {r, c}), do: 1, else: 0
            else
              0
            end
          end

        scaled_row = Enum.flat_map(row_bytes, fn byte -> List.duplicate(byte, mod) end)
        pixel_row = [0 | scaled_row] |> :binary.list_to_bin()
        List.duplicate(pixel_row, mod)
      end

    IO.iodata_to_binary(module_rows)
  end

  # Build raw image data with region-aware palette indices
  defp build_raw_image_data_styled(matrix, region_map, mod, qz) do
    total_modules = matrix.size + 2 * qz

    module_rows =
      for mr <- 0..(total_modules - 1) do
        row_bytes =
          for mc <- 0..(total_modules - 1) do
            r = mr - qz
            c = mc - qz

            if r >= 0 and r < matrix.size and c >= 0 and c < matrix.size do
              region = Map.get(region_map, {r, c}, :data)
              is_dark = Matrix.dark?(matrix, {r, c})
              region_to_palette_index(region, is_dark)
            else
              0
            end
          end

        scaled_row = Enum.flat_map(row_bytes, fn byte -> List.duplicate(byte, mod) end)
        pixel_row = [0 | scaled_row] |> :binary.list_to_bin()
        List.duplicate(pixel_row, mod)
      end

    IO.iodata_to_binary(module_rows)
  end

  # Map region + dark/light state to palette index
  # 0=light, 1=dark, 2=finder_outer, 3=finder_inner, 4=finder_eye
  defp region_to_palette_index(:finder_outer, true), do: 2
  defp region_to_palette_index(:finder_outer, false), do: 0
  defp region_to_palette_index(:finder_inner, _), do: 3
  defp region_to_palette_index(:finder_eye, true), do: 4
  defp region_to_palette_index(:finder_eye, false), do: 3
  defp region_to_palette_index(_, true), do: 1
  defp region_to_palette_index(_, false), do: 0

  defp build_iend do
    build_chunk("IEND", <<>>)
  end

  defp build_chunk(type, data) do
    type_bin = type
    length = byte_size(data)
    crc = :erlang.crc32(<<type_bin::binary, data::binary>>)

    <<length::32, type_bin::binary, data::binary, crc::32>>
  end
end
