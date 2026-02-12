defmodule Qiroex.Matrix.Regions do
  @moduledoc """
  Classifies QR code matrix modules into functional regions.

  Used by renderers to apply distinct styles (colors, shapes) to different
  areas of the QR code: finder patterns, alignment patterns, timing patterns,
  and data modules.

  ## Regions

    - `:finder_eye`   — center 1×1 and surrounding 3×3 dark core of finder patterns
    - `:finder_inner`  — light ring (5×5 minus 3×3) of finder patterns
    - `:finder_outer`  — dark border (7×7 minus 5×5) of finder patterns
    - `:separator`     — 1-module white border around finders
    - `:alignment`     — 5×5 alignment patterns (versions 2+)
    - `:timing`        — alternating row 6 / column 6 timing patterns
    - `:data`          — all remaining modules (data + error correction)
  """

  alias Qiroex.Matrix
  alias Qiroex.Spec

  @type region ::
          :finder_eye
          | :finder_inner
          | :finder_outer
          | :separator
          | :alignment
          | :timing
          | :data

  @doc """
  Returns the region for a given module position.

  ## Parameters
    - `matrix` — a `%Qiroex.Matrix{}` struct
    - `pos` — `{row, col}` tuple
  """
  @spec classify(Matrix.t(), Matrix.position()) :: region()
  def classify(%Matrix{} = matrix, {row, col} = _pos) do
    size = matrix.size
    version = matrix.version

    cond do
      finder_eye?(row, col, size) -> :finder_eye
      finder_inner?(row, col, size) -> :finder_inner
      finder_outer?(row, col, size) -> :finder_outer
      separator?(row, col, size) -> :separator
      alignment?(row, col, version, size) -> :alignment
      timing?(row, col, size) -> :timing
      true -> :data
    end
  end

  @doc """
  Builds a complete region map for the entire matrix.

  Returns a map of `{row, col} => region` for all dark and light modules.
  """
  @spec build_map(Matrix.t()) :: %{Matrix.position() => region()}
  def build_map(%Matrix{} = matrix) do
    size = matrix.size

    for row <- 0..(size - 1),
        col <- 0..(size - 1),
        into: %{} do
      {{row, col}, classify(matrix, {row, col})}
    end
  end

  # === Finder Pattern Regions ===

  # The three finder pattern origins (top-left corner of each 7×7 block)
  defp finder_origins(size) do
    [{0, 0}, {0, size - 7}, {size - 7, 0}]
  end

  # Center 3×3 of each finder pattern (rows 2-4, cols 2-4 relative to origin)
  defp finder_eye?(row, col, size) do
    Enum.any?(finder_origins(size), fn {or_, oc} ->
      lr = row - or_
      lc = col - oc
      lr >= 2 and lr <= 4 and lc >= 2 and lc <= 4
    end)
  end

  # Light ring: 5×5 minus 3×3 (rows 1-5, cols 1-5 but not 2-4/2-4)
  defp finder_inner?(row, col, size) do
    Enum.any?(finder_origins(size), fn {or_, oc} ->
      lr = row - or_
      lc = col - oc
      lr >= 1 and lr <= 5 and lc >= 1 and lc <= 5 and
        not (lr >= 2 and lr <= 4 and lc >= 2 and lc <= 4)
    end)
  end

  # Dark border: 7×7 minus 5×5 (the outermost ring)
  defp finder_outer?(row, col, size) do
    Enum.any?(finder_origins(size), fn {or_, oc} ->
      lr = row - or_
      lc = col - oc
      lr >= 0 and lr <= 6 and lc >= 0 and lc <= 6 and
        not (lr >= 1 and lr <= 5 and lc >= 1 and lc <= 5)
    end)
  end

  # === Separator ===

  defp separator?(row, col, size) do
    # Separator is the 1-module-wide border around each finder pattern
    # TL: row 7 cols 0-7, col 7 rows 0-7
    (row == 7 and col <= 7) or
    (col == 7 and row <= 7) or
    # TR: row 7 cols (size-8)..(size-1), col (size-8) rows 0-7
    (row == 7 and col >= size - 8) or
    (col == size - 8 and row <= 7) or
    # BL: row (size-8) cols 0-7, col 7 rows (size-8)..(size-1)
    (row == size - 8 and col <= 7) or
    (col == 7 and row >= size - 8)
  end

  # === Alignment Pattern ===

  defp alignment?(row, col, version, size) do
    centers = Spec.alignment_pattern_positions(version)
    positions = for r <- centers, c <- centers, do: {r, c}

    Enum.any?(positions, fn {cr, cc} ->
      # Skip if overlapping with finder pattern area
      not overlaps_finder?(cr, cc, size) and
        row >= cr - 2 and row <= cr + 2 and
        col >= cc - 2 and col <= cc + 2
    end)
  end

  defp overlaps_finder?(cr, cc, size) do
    (cr <= 8 and cc <= 8) or
    (cr <= 8 and cc >= size - 9) or
    (cr >= size - 9 and cc <= 8)
  end

  # === Timing Pattern ===

  defp timing?(row, col, size) do
    # Row 6, between finders (cols 8 to size-9)
    (row == 6 and col >= 8 and col <= size - 9) or
    # Col 6, between finders (rows 8 to size-9)
    (col == 6 and row >= 8 and row <= size - 9)
  end
end
