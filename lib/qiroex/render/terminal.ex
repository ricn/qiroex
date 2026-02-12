defmodule Qiroex.Render.Terminal do
  @moduledoc """
  Renders a QR code to the terminal using Unicode block characters.

  Uses the Unicode "upper half block" character (▀) combined with ANSI colors
  to render two rows of modules per terminal line, producing compact output.

  Each terminal character represents two vertically stacked modules:
  - Top dark + bottom dark → inverted space (dark background)
  - Top dark + bottom light → "▄" (lower half block)
  - Top light + bottom dark → "▀" (upper half block)
  - Top light + bottom light → space (light background)

  ## Options
    - `:quiet_zone` - number of quiet zone modules (default: 4)
    - `:dark` - ANSI escape for dark color (default: black)
    - `:light` - ANSI escape for light color (default: white)
    - `:compact` - use 2-row-per-line rendering (default: `true`)
  """

  alias Qiroex.Matrix

  @upper_half "▀"
  @lower_half "▄"
  @full_block "█"

  @default_opts %{
    quiet_zone: 4,
    compact: true
  }

  @doc """
  Renders a QR matrix as a terminal string.

  ## Parameters
    - `matrix` - a `%Qiroex.Matrix{}` struct
    - `opts` - keyword list of rendering options

  ## Returns
    A string ready to be printed to the terminal.
  """
  @spec render(Matrix.t(), keyword()) :: String.t()
  def render(%Matrix{} = matrix, opts \\ []) do
    config = parse_opts(opts)
    matrix |> build_iolist(config) |> IO.iodata_to_binary()
  end

  @doc """
  Renders a QR matrix and prints it directly to the terminal.
  """
  @spec print(Matrix.t(), keyword()) :: :ok
  def print(%Matrix{} = matrix, opts \\ []) do
    config = parse_opts(opts)
    matrix |> build_iolist(config) |> IO.puts()
  end

  defp parse_opts(opts) do
    %{
      quiet_zone: Keyword.get(opts, :quiet_zone, @default_opts.quiet_zone),
      compact: Keyword.get(opts, :compact, @default_opts.compact)
    }
  end

  defp build_iolist(matrix, %{compact: true} = config) do
    build_compact(matrix, config)
  end

  defp build_iolist(matrix, config) do
    build_simple(matrix, config)
  end

  # Compact rendering: 2 module rows per terminal line using half-block chars
  defp build_compact(matrix, config) do
    %{quiet_zone: qz} = config
    rows = Matrix.to_list(matrix, qz)
    total_rows = length(rows)

    # Process rows in pairs
    paired_rows =
      rows
      |> Enum.chunk_every(2, 2, :discard)

    lines =
      Enum.map(paired_rows, fn [top_row, bottom_row] ->
        Enum.zip(top_row, bottom_row)
        |> Enum.map(fn
          {1, 1} -> @full_block
          {1, 0} -> @upper_half
          {0, 1} -> @lower_half
          {0, 0} -> " "
        end)
      end)

    # If odd number of rows, handle the last row
    lines =
      if rem(total_rows, 2) == 1 do
        last_row = List.last(rows)
        last_line = Enum.map(last_row, fn
          1 -> @upper_half
          0 -> " "
        end)
        lines ++ [last_line]
      else
        lines
      end

    Enum.intersperse(lines, "\n")
    |> then(fn parts -> parts ++ ["\n"] end)
  end

  # Simple rendering: 1 module row per terminal line using full blocks
  defp build_simple(matrix, config) do
    %{quiet_zone: qz} = config
    rows = Matrix.to_list(matrix, qz)

    lines =
      Enum.map(rows, fn row ->
        Enum.map(row, fn
          1 -> "██"
          0 -> "  "
        end)
      end)

    Enum.intersperse(lines, "\n")
    |> then(fn parts -> parts ++ ["\n"] end)
  end
end
