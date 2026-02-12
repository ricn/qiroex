defmodule Qiroex.Render.SVG do
  @moduledoc """
  Renders a QR code as an SVG string.

  Uses IO lists for efficient string building. Produces compact SVG output
  using a single `<path>` element with optimized `d` attribute for dark modules.

  ## Options
    - `:module_size` - size of each module in pixels (default: 10)
    - `:quiet_zone` - number of quiet zone modules (default: 4)
    - `:dark_color` - CSS color for dark modules (default: `"#000000"`)
    - `:light_color` - CSS color for light/background modules (default: `"#ffffff"`)
  """

  alias Qiroex.Matrix

  @default_opts %{
    module_size: 10,
    quiet_zone: 4,
    dark_color: "#000000",
    light_color: "#ffffff"
  }

  @doc """
  Renders a QR matrix as an SVG string.

  ## Parameters
    - `matrix` - a `%Qiroex.Matrix{}` struct
    - `opts` - keyword list of rendering options

  ## Returns
    An SVG string.
  """
  @spec render(Matrix.t(), keyword()) :: String.t()
  def render(%Matrix{} = matrix, opts \\ []) do
    config = parse_opts(opts)
    matrix |> build_iolist(config) |> IO.iodata_to_binary()
  end

  @doc """
  Renders a QR matrix as an SVG IO list (more efficient for streaming/writing).
  """
  @spec render_iolist(Matrix.t(), keyword()) :: iolist()
  def render_iolist(%Matrix{} = matrix, opts \\ []) do
    config = parse_opts(opts)
    build_iolist(matrix, config)
  end

  defp parse_opts(opts) do
    %{
      module_size: Keyword.get(opts, :module_size, @default_opts.module_size),
      quiet_zone: Keyword.get(opts, :quiet_zone, @default_opts.quiet_zone),
      dark_color: Keyword.get(opts, :dark_color, @default_opts.dark_color),
      light_color: Keyword.get(opts, :light_color, @default_opts.light_color)
    }
  end

  defp build_iolist(matrix, config) do
    %{module_size: mod, quiet_zone: qz, dark_color: dark, light_color: light} = config

    total_modules = matrix.size + 2 * qz
    total_px = total_modules * mod

    width = Integer.to_string(total_px)
    height = Integer.to_string(total_px)

    path_data = build_path_data(matrix, mod, qz)

    [
      ~s(<?xml version="1.0" encoding="UTF-8"?>\n),
      ~s(<svg xmlns="http://www.w3.org/2000/svg" ),
      ~s(version="1.1" ),
      ~s(width="), width, ~s(" ),
      ~s(height="), height, ~s(" ),
      ~s(viewBox="0 0 ), width, ~s( ), height, ~s(">\n),
      # Background rectangle
      ~s(<rect width="100%" height="100%" fill="), light, ~s("/>\n),
      # Dark modules as a single path
      ~s(<path d="), path_data, ~s(" fill="), dark, ~s("/>\n),
      ~s(</svg>\n)
    ]
  end

  # Build SVG path data string for all dark modules.
  # Each dark module becomes a rectangle: M x,y h w v h h -w Z
  defp build_path_data(matrix, mod, qz) do
    size = matrix.size
    mod_s = Integer.to_string(mod)
    neg_mod_s = Integer.to_string(-mod)

    parts =
      for row <- 0..(size - 1),
          col <- 0..(size - 1),
          Matrix.dark?(matrix, {row, col}) do
        x = Integer.to_string((col + qz) * mod)
        y = Integer.to_string((row + qz) * mod)

        [?M, x, ?,, y, ?h, mod_s, ?v, mod_s, ?h, neg_mod_s, ?Z]
      end

    parts
  end
end
