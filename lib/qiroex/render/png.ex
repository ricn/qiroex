defmodule Qiroex.Render.PNG do
  @moduledoc """
  Renders a QR code as a PNG binary.

  Produces a minimal valid PNG file using only Erlang stdlib (`:zlib` for
  DEFLATE compression, `:erlang.crc32` for CRC-32). The image uses an
  indexed color palette (2 colors: light and dark).

  ## Options
    - `:module_size` - size of each module in pixels (default: 10)
    - `:quiet_zone` - number of quiet zone modules (default: 4)
    - `:dark_color` - `{r, g, b}` tuple 0-255 (default: `{0, 0, 0}`)
    - `:light_color` - `{r, g, b}` tuple 0-255 (default: `{255, 255, 255}`)
  """

  alias Qiroex.Matrix

  @png_signature <<137, 80, 78, 71, 13, 10, 26, 10>>

  @default_opts %{
    module_size: 10,
    quiet_zone: 4,
    dark_color: {0, 0, 0},
    light_color: {255, 255, 255}
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
      light_color: Keyword.get(opts, :light_color, @default_opts.light_color)
    }
  end

  defp build_png(matrix, config) do
    %{module_size: mod, quiet_zone: qz, dark_color: dark, light_color: light} = config

    total_modules = matrix.size + 2 * qz
    width = total_modules * mod
    height = total_modules * mod

    ihdr = build_ihdr(width, height)
    plte = build_plte(light, dark)
    idat = build_idat(matrix, width, height, mod, qz)
    iend = build_iend()

    IO.iodata_to_binary([@png_signature, ihdr, plte, idat, iend])
  end

  # IHDR chunk: 13 bytes of image header
  # Width (4), Height (4), Bit depth (1), Color type (1), Compression (1), Filter (1), Interlace (1)
  defp build_ihdr(width, height) do
    data = <<
      width::32,
      height::32,
      8::8,           # bit depth: 8 bits per pixel
      3::8,           # color type: indexed color (palette)
      0::8,           # compression: deflate
      0::8,           # filter: adaptive
      0::8            # interlace: none
    >>

    build_chunk("IHDR", data)
  end

  # PLTE chunk: palette with 2 colors (index 0 = light, index 1 = dark)
  defp build_plte({lr, lg, lb}, {dr, dg, db}) do
    data = <<lr::8, lg::8, lb::8, dr::8, dg::8, db::8>>
    build_chunk("PLTE", data)
  end

  # IDAT chunk: compressed image data
  # Each row starts with a filter byte (0 = None), then pixel indices
  defp build_idat(matrix, width, height, mod, qz) do
    raw_data = build_raw_image_data(matrix, width, height, mod, qz)

    z = :zlib.open()
    :zlib.deflateInit(z)
    compressed = :zlib.deflate(z, raw_data, :finish)
    :zlib.deflateEnd(z)
    :zlib.close(z)

    build_chunk("IDAT", IO.iodata_to_binary(compressed))
  end

  # Build raw (uncompressed) image data with filter bytes
  defp build_raw_image_data(matrix, _width, _height, mod, qz) do
    total_modules = matrix.size + 2 * qz

    # Build one row of module indices (without pixel scaling)
    module_rows =
      for mr <- 0..(total_modules - 1) do
        row_bytes =
          for mc <- 0..(total_modules - 1) do
            r = mr - qz
            c = mc - qz

            if r >= 0 and r < matrix.size and c >= 0 and c < matrix.size do
              if Matrix.dark?(matrix, {r, c}), do: 1, else: 0
            else
              0  # quiet zone = light
            end
          end

        # Scale each module pixel to mod × mod
        scaled_row = Enum.flat_map(row_bytes, fn byte ->
          List.duplicate(byte, mod)
        end)

        # Add filter byte (0 = None) and convert to binary
        pixel_row = [0 | scaled_row] |> :binary.list_to_bin()

        # Repeat this row `mod` times for vertical scaling
        List.duplicate(pixel_row, mod)
      end

    IO.iodata_to_binary(module_rows)
  end

  # IEND chunk: empty end marker
  defp build_iend do
    build_chunk("IEND", <<>>)
  end

  # Build a PNG chunk: length(4) + type(4) + data + crc(4)
  defp build_chunk(type, data) do
    type_bin = type
    length = byte_size(data)
    crc = :erlang.crc32(<<type_bin::binary, data::binary>>)

    <<length::32, type_bin::binary, data::binary, crc::32>>
  end
end
