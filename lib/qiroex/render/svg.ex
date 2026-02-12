defmodule Qiroex.Render.SVG do
  @moduledoc """
  Renders a QR code as an SVG string.

  Uses IO lists for efficient string building. Supports module shapes,
  finder pattern styling, and gradient fills.

  ## Options
    - `:module_size` - size of each module in pixels (default: 10)
    - `:quiet_zone` - number of quiet zone modules (default: 4)
    - `:dark_color` - CSS color for dark modules (default: `"#000000"`)
    - `:light_color` - CSS color for light/background modules (default: `"#ffffff"`)
    - `:style` - a `%Qiroex.Style{}` struct for advanced styling (optional)
  """

  alias Qiroex.Matrix
  alias Qiroex.Matrix.Regions
  alias Qiroex.Style
  alias Qiroex.Logo

  @default_opts %{
    module_size: 10,
    quiet_zone: 4,
    dark_color: "#000000",
    light_color: "#ffffff",
    style: nil,
    logo: nil
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
      light_color: Keyword.get(opts, :light_color, @default_opts.light_color),
      style: Keyword.get(opts, :style, @default_opts.style),
      logo: Keyword.get(opts, :logo, @default_opts.logo)
    }
  end

  defp build_iolist(matrix, config) do
    %{module_size: mod, quiet_zone: qz, dark_color: dark, light_color: light,
      style: style, logo: logo} = config

    total_modules = matrix.size + 2 * qz
    total_px = total_modules * mod

    width = Integer.to_string(total_px)
    height = Integer.to_string(total_px)

    # Compute cleared positions for logo (if any)
    cleared = if logo, do: Logo.cleared_positions(logo, matrix.size, mod, qz), else: MapSet.new()

    # Build the logo SVG fragment (if any)
    logo_fragment =
      if logo do
        geo = Logo.geometry(logo, matrix.size, mod, qz)
        Logo.render_svg(logo, geo)
      else
        []
      end

    if styled?(style) do
      build_styled_iolist(matrix, mod, qz, dark, light, style, width, height, cleared, logo_fragment)
    else
      build_simple_iolist(matrix, mod, qz, dark, light, width, height, cleared, logo_fragment)
    end
  end

  defp styled?(nil), do: false
  defp styled?(%Style{} = s), do: not Style.default?(s)

  # === Simple Rendering (original fast path) ===

  defp build_simple_iolist(matrix, mod, qz, dark, light, width, height, cleared, logo_fragment) do
    path_data = build_path_data(matrix, mod, qz, cleared)

    [
      svg_header(width, height),
      background_rect(light),
      ~s(<path d="), path_data, ~s(" fill="), dark, ~s("/>\n),
      logo_fragment,
      ~s(</svg>\n)
    ]
  end

  # Build SVG path data string for all dark modules (square shape).
  defp build_path_data(matrix, mod, qz, cleared) do
    size = matrix.size
    mod_s = Integer.to_string(mod)
    neg_mod_s = Integer.to_string(-mod)

    for row <- 0..(size - 1),
        col <- 0..(size - 1),
        Matrix.dark?(matrix, {row, col}),
        not MapSet.member?(cleared, {row, col}) do
      x = Integer.to_string((col + qz) * mod)
      y = Integer.to_string((row + qz) * mod)

      [?M, x, ?,, y, ?h, mod_s, ?v, mod_s, ?h, neg_mod_s, ?Z]
    end
  end

  # === Styled Rendering ===

  defp build_styled_iolist(matrix, mod, qz, dark, light, style, width, height, cleared, logo_fragment) do
    region_map = Regions.build_map(matrix)
    defs = build_defs(style, width, height)

    # Classify dark modules by region and render with appropriate style
    module_elements = build_styled_modules(matrix, region_map, mod, qz, dark, light, style, cleared)

    [
      svg_header(width, height),
      defs,
      background_rect(light),
      module_elements,
      logo_fragment,
      ~s(</svg>\n)
    ]
  end

  defp build_styled_modules(matrix, region_map, mod, qz, dark, light, style, cleared) do
    size = matrix.size

    # Group modules by their effective fill color and shape
    modules =
      for row <- 0..(size - 1),
          col <- 0..(size - 1),
          not MapSet.member?(cleared, {row, col}) do
        pos = {row, col}
        region = Map.get(region_map, pos, :data)
        is_dark = Matrix.dark?(matrix, pos)
        {pos, region, is_dark}
      end

    # Separate finder pattern modules from other modules
    {finder_modules, other_modules} =
      Enum.split_with(modules, fn {_pos, region, _dark} ->
        region in [:finder_outer, :finder_inner, :finder_eye]
      end)

    # Render non-finder modules with the data module shape/color
    data_fill = if style.gradient, do: "url(#qr-gradient)", else: dark
    shape = if style, do: style.module_shape, else: :square
    radius = if style, do: style.module_radius, else: 0

    data_elements =
      for {pos, _region, is_dark} <- other_modules, is_dark do
        render_module(pos, mod, qz, data_fill, shape, radius)
      end

    # Render finder patterns
    finder_elements =
      if Style.custom_finder?(style) do
        render_finder_modules(finder_modules, mod, qz, dark, light, style)
      else
        # Use standard data styling for finder patterns too
        for {pos, _region, is_dark} <- finder_modules, is_dark do
          render_module(pos, mod, qz, data_fill, :square, 0)
        end
      end

    [data_elements, finder_elements]
  end

  defp render_finder_modules(finder_modules, mod, qz, dark, light, style) do
    outer_color = Style.finder_color(style, :outer, dark)
    inner_color = Style.finder_color(style, :inner, light)
    eye_color = Style.finder_color(style, :eye, dark)

    for {pos, region, is_dark} <- finder_modules do
      case region do
        :finder_outer ->
          if is_dark do
            render_module(pos, mod, qz, outer_color, :square, 0)
          else
            []
          end

        :finder_inner ->
          # Inner ring: always rendered (it's the light ring) with inner color
          render_module(pos, mod, qz, inner_color, :square, 0)

        :finder_eye ->
          if is_dark do
            render_module(pos, mod, qz, eye_color, :square, 0)
          else
            []
          end
      end
    end
  end

  # === Module Shape Rendering ===

  defp render_module({row, col}, mod, qz, fill, shape, radius) do
    x = (col + qz) * mod
    y = (row + qz) * mod

    case shape do
      :square -> render_square(x, y, mod, fill)
      :rounded -> render_rounded(x, y, mod, fill, radius)
      :circle -> render_circle(x, y, mod, fill)
      :diamond -> render_diamond(x, y, mod, fill)
    end
  end

  defp render_square(x, y, mod, fill) do
    xs = Integer.to_string(x)
    ys = Integer.to_string(y)
    ms = Integer.to_string(mod)

    [~s(<rect x="), xs, ~s(" y="), ys, ~s(" width="), ms, ~s(" height="), ms,
     ~s(" fill="), ?", fill, ?", ~s(/>\n)]
  end

  defp render_rounded(x, y, mod, fill, radius_fraction) do
    xs = Integer.to_string(x)
    ys = Integer.to_string(y)
    ms = Integer.to_string(mod)
    r = Float.to_string(mod * radius_fraction)

    [~s(<rect x="), xs, ~s(" y="), ys, ~s(" width="), ms, ~s(" height="), ms,
     ~s(" rx="), ?", r, ?", ~s(" ry="), ?", r, ?",
     ~s(" fill="), ?", fill, ?", ~s(/>\n)]
  end

  defp render_circle(x, y, mod, fill) do
    half = mod / 2
    cx = Float.to_string(x + half)
    cy = Float.to_string(y + half)
    r = Float.to_string(half * 0.85)

    [~s(<circle cx="), cx, ~s(" cy="), cy, ~s(" r="), r,
     ~s(" fill="), ?", fill, ?", ~s(/>\n)]
  end

  defp render_diamond(x, y, mod, fill) do
    half = mod / 2
    # Diamond: 4 points (top, right, bottom, left)
    top_x = Float.to_string(x + half)
    top_y = Float.to_string(y + 0.0)
    right_x = Float.to_string(x + mod + 0.0)
    right_y = Float.to_string(y + half)
    bottom_x = Float.to_string(x + half)
    bottom_y = Float.to_string(y + mod + 0.0)
    left_x = Float.to_string(x + 0.0)
    left_y = Float.to_string(y + half)

    [~s(<polygon points="),
     top_x, ?,, top_y, ?\s,
     right_x, ?,, right_y, ?\s,
     bottom_x, ?,, bottom_y, ?\s,
     left_x, ?,, left_y,
     ~s(" fill="), ?", fill, ?", ~s(/>\n)]
  end

  # === Gradient Defs ===

  defp build_defs(%Style{gradient: nil}, _w, _h), do: []

  defp build_defs(%Style{gradient: %{type: :linear} = g}, _w, _h) do
    angle = Map.get(g, :angle, 0)
    {x1, y1, x2, y2} = angle_to_coords(angle)

    [
      ~s(<defs>\n),
      ~s(<linearGradient id="qr-gradient" ),
      ~s(x1="), Float.to_string(x1), ~s(" y1="), Float.to_string(y1), ~s(" ),
      ~s(x2="), Float.to_string(x2), ~s(" y2="), Float.to_string(y2), ~s(">\n),
      ~s(<stop offset="0%" stop-color="), g.start_color, ~s("/>\n),
      ~s(<stop offset="100%" stop-color="), g.end_color, ~s("/>\n),
      ~s(</linearGradient>\n),
      ~s(</defs>\n)
    ]
  end

  defp build_defs(%Style{gradient: %{type: :radial} = g}, _w, _h) do
    [
      ~s(<defs>\n),
      ~s(<radialGradient id="qr-gradient" cx="50%" cy="50%" r="50%">\n),
      ~s(<stop offset="0%" stop-color="), g.start_color, ~s("/>\n),
      ~s(<stop offset="100%" stop-color="), g.end_color, ~s("/>\n),
      ~s(</radialGradient>\n),
      ~s(</defs>\n)
    ]
  end

  # Convert angle (degrees, 0=top→bottom) to x1,y1,x2,y2 gradient coords
  defp angle_to_coords(0), do: {0.0, 0.0, 0.0, 1.0}
  defp angle_to_coords(90), do: {0.0, 0.0, 1.0, 0.0}
  defp angle_to_coords(180), do: {0.0, 1.0, 0.0, 0.0}
  defp angle_to_coords(270), do: {1.0, 0.0, 0.0, 0.0}

  defp angle_to_coords(angle) do
    rad = angle * :math.pi() / 180
    dx = :math.sin(rad)
    dy = :math.cos(rad)

    # Normalize to 0..1 range
    x1 = Float.round(0.5 - dx / 2, 4)
    y1 = Float.round(0.5 - dy / 2, 4)
    x2 = Float.round(0.5 + dx / 2, 4)
    y2 = Float.round(0.5 + dy / 2, 4)

    {x1, y1, x2, y2}
  end

  # === Common SVG Fragments ===

  defp svg_header(width, height) do
    [
      ~s(<?xml version="1.0" encoding="UTF-8"?>\n),
      ~s(<svg xmlns="http://www.w3.org/2000/svg" ),
      ~s(version="1.1" ),
      ~s(width="), width, ~s(" ),
      ~s(height="), height, ~s(" ),
      ~s(viewBox="0 0 ), width, ~s( ), height, ~s(">\n)
    ]
  end

  defp background_rect(light) do
    [~s(<rect width="100%" height="100%" fill="), light, ~s("/>\n)]
  end
end
