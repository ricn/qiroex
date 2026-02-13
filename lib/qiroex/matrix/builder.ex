defmodule Qiroex.Matrix.Builder do
  @moduledoc """
  Places all function patterns onto the QR code matrix.

  Handles: finder patterns, separators, alignment patterns, timing patterns,
  dark module, format information areas, and version information areas.
  """

  alias Qiroex.ErrorCorrection.BCH
  alias Qiroex.Matrix
  alias Qiroex.Spec

  @doc """
  Builds a matrix with all function patterns placed.
  Data region modules are left as nil.
  """
  @spec build(non_neg_integer()) :: Matrix.t()
  def build(version) do
    Matrix.new(version)
    |> place_finder_patterns()
    |> place_separators()
    |> place_alignment_patterns(version)
    |> place_timing_patterns()
    |> place_dark_module(version)
    |> reserve_format_areas()
    |> reserve_version_areas(version)
  end

  @doc "Places finder patterns and format/version info after masking."
  @spec finalize(Matrix.t(), Spec.ec_level(), non_neg_integer()) :: Matrix.t()
  def finalize(matrix, ec_level, mask_pattern) do
    matrix
    |> place_format_info(ec_level, mask_pattern)
    |> place_version_info()
  end

  # === Finder Patterns ===
  # Three 7×7 finder patterns at TL, TR, BL corners
  # Pattern: dark 7×7, light 5×5, dark 3×3

  defp place_finder_patterns(matrix) do
    size = matrix.size

    matrix
    # Top-left
    |> place_finder_pattern(0, 0)
    # Top-right
    |> place_finder_pattern(0, size - 7)
    # Bottom-left
    |> place_finder_pattern(size - 7, 0)
  end

  defp place_finder_pattern(matrix, row_offset, col_offset) do
    Enum.reduce(0..6, matrix, fn r, mat ->
      Enum.reduce(0..6, mat, fn c, mat2 ->
        value =
          cond do
            # Outer border
            r == 0 or r == 6 or c == 0 or c == 6 -> :dark
            # Inner white border
            r == 1 or r == 5 or c == 1 or c == 5 -> :light
            # Center 3×3
            true -> :dark
          end

        Matrix.set(mat2, {row_offset + r, col_offset + c}, value)
      end)
    end)
  end

  # === Separators ===
  # 1-module white border around each finder pattern

  defp place_separators(matrix) do
    size = matrix.size

    matrix
    # Top-left separator (right and bottom of TL finder)
    # bottom of TL
    |> place_separator_line(7, 0, 8, :horizontal)
    # right of TL
    |> place_separator_line(0, 7, 8, :vertical)
    # Top-right separator (left and bottom of TR finder)
    # bottom of TR
    |> place_separator_line(7, size - 8, 8, :horizontal)
    # left of TR
    |> place_separator_line(0, size - 8, 8, :vertical)
    # Bottom-left separator (right and top of BL finder)
    # top of BL
    |> place_separator_line(size - 8, 0, 8, :horizontal)
    # right of BL
    |> place_separator_line(size - 8, 7, 8, :vertical)
  end

  defp place_separator_line(matrix, row, col, count, :horizontal) do
    Enum.reduce(0..(count - 1), matrix, fn i, mat ->
      pos = {row, col + i}
      if Matrix.in_bounds?(mat, pos), do: Matrix.set(mat, pos, :light), else: mat
    end)
  end

  defp place_separator_line(matrix, row, col, count, :vertical) do
    Enum.reduce(0..(count - 1), matrix, fn i, mat ->
      pos = {row + i, col}
      if Matrix.in_bounds?(mat, pos), do: Matrix.set(mat, pos, :light), else: mat
    end)
  end

  # === Alignment Patterns ===
  # 5×5 patterns placed at version-dependent positions, skipping finder pattern areas

  defp place_alignment_patterns(matrix, version) do
    centers = Spec.alignment_pattern_positions(version)

    # Generate all center coordinate pairs
    positions = for r <- centers, c <- centers, do: {r, c}

    Enum.reduce(positions, matrix, fn {row, col}, mat ->
      if overlaps_finder?(mat, row, col) do
        mat
      else
        place_alignment_pattern(mat, row, col)
      end
    end)
  end

  defp overlaps_finder?(matrix, row, col) do
    size = matrix.size

    # Top-left finder + separator: rows 0-8, cols 0-8
    # Top-right finder + separator: rows 0-8, cols (size-9) to (size-1)
    # Bottom-left finder + separator: rows (size-9) to (size-1), cols 0-8
    (row <= 8 and col <= 8) or
      (row <= 8 and col >= size - 9) or
      (row >= size - 9 and col <= 8)
  end

  defp place_alignment_pattern(matrix, center_row, center_col) do
    Enum.reduce(-2..2, matrix, fn dr, mat ->
      Enum.reduce(-2..2, mat, fn dc, mat2 ->
        value =
          cond do
            abs(dr) == 2 or abs(dc) == 2 -> :dark
            dr == 0 and dc == 0 -> :dark
            true -> :light
          end

        Matrix.set(mat2, {center_row + dr, center_col + dc}, value)
      end)
    end)
  end

  # === Timing Patterns ===
  # Alternating dark/light on row 6 and column 6

  defp place_timing_patterns(matrix) do
    size = matrix.size

    Enum.reduce(8..(size - 9), matrix, fn i, mat ->
      value = if rem(i, 2) == 0, do: :dark, else: :light

      mat
      # Horizontal timing (row 6)
      |> set_if_unset({6, i}, value)
      # Vertical timing (col 6)
      |> set_if_unset({i, 6}, value)
    end)
  end

  defp set_if_unset(matrix, pos, value) do
    if Matrix.reserved?(matrix, pos) do
      matrix
    else
      Matrix.set(matrix, pos, value)
    end
  end

  # === Dark Module ===
  # Always-dark module at (4*V + 9, 8)

  defp place_dark_module(matrix, version) do
    row = 4 * version + 9
    Matrix.set(matrix, {row, 8}, :dark)
  end

  # === Format Information Areas ===
  # Reserve 15-bit format info positions around finders (filled after masking)

  defp reserve_format_areas(matrix) do
    size = matrix.size
    positions = format_info_positions(size)

    Enum.reduce(positions, matrix, fn pos, mat ->
      if Matrix.reserved?(mat, pos), do: mat, else: Matrix.set(mat, pos, :light)
    end)
  end

  @doc "Returns all format information bit positions."
  @spec format_info_positions(non_neg_integer()) :: list(Matrix.position())
  def format_info_positions(size) do
    # Two copies of 15 bits each
    # Copy 1: around top-left finder
    copy1 = format_info_positions_copy1()
    # Copy 2: split between bottom-left and top-right finders
    copy2 = format_info_positions_copy2(size)
    copy1 ++ copy2
  end

  # Format info copy 1 positions (around top-left finder)
  # Bits 0-7 go along the left side (column 8), bits 8-14 go along the top (row 8)
  defp format_info_positions_copy1 do
    # Bits 0-5: row 0-5, col 8
    left_top = for i <- 0..5, do: {i, 8}
    # Bit 6: row 7, col 8 (skip row 6 = timing)
    # Bit 7: row 8, col 8
    left_bottom = [{7, 8}, {8, 8}]
    # Bits 8-14: row 8, cols 7 down to 0 (skip col 6 = timing)
    top = [{8, 7}] ++ for i <- 5..0//-1, do: {8, i}

    left_top ++ left_bottom ++ top
  end

  # Format info copy 2 positions (bottom-left and top-right)
  defp format_info_positions_copy2(size) do
    # Bits 0-6: col 8, rows (size-1) down to (size-7)
    bottom_left = for i <- 0..6, do: {size - 1 - i, 8}
    # Bits 7-14: row 8, cols (size-8) to (size-1)
    top_right = for i <- 0..7, do: {8, size - 8 + i}

    bottom_left ++ top_right
  end

  # === Version Information Areas ===
  # 18-bit version info for V7+ in two 6×3 blocks

  defp reserve_version_areas(matrix, version) when version < 7, do: matrix

  defp reserve_version_areas(matrix, _version) do
    size = matrix.size
    positions = version_info_positions(size)

    Enum.reduce(positions, matrix, fn pos, mat ->
      if Matrix.reserved?(mat, pos), do: mat, else: Matrix.set(mat, pos, :light)
    end)
  end

  @doc "Returns all version information bit positions for the given matrix size."
  @spec version_info_positions(non_neg_integer()) :: list(Matrix.position())
  def version_info_positions(size) do
    # Copy 1: bottom-left area (rows size-11 to size-9, cols 0-5)
    copy1 = for j <- 0..5, i <- 0..2, do: {size - 11 + i, j}
    # Copy 2: top-right area (rows 0-5, cols size-11 to size-9)
    copy2 = for i <- 0..5, j <- 0..2, do: {i, size - 11 + j}
    copy1 ++ copy2
  end

  # === Place Format Information ===

  defp place_format_info(matrix, ec_level, mask_pattern) do
    size = matrix.size
    bits = BCH.format_info_bits(ec_level, mask_pattern)

    # Copy 1
    positions1 = format_info_positions_copy1()
    matrix = place_info_bits(matrix, positions1, bits)

    # Copy 2
    positions2 = format_info_positions_copy2(size)
    place_info_bits(matrix, positions2, bits)
  end

  # === Place Version Information ===

  defp place_version_info(%Matrix{version: version} = matrix) when version < 7, do: matrix

  defp place_version_info(%Matrix{version: version, size: size} = matrix) do
    bits = BCH.version_info_bits(version)

    # Copy 1: bottom-left (6×3 block, LSB first)
    copy1_positions = for j <- 0..5, i <- 0..2, do: {size - 11 + i, j}
    matrix = place_info_bits(matrix, copy1_positions, Enum.reverse(bits))

    # Copy 2: top-right (3×6 block, LSB first)
    copy2_positions = for i <- 0..5, j <- 0..2, do: {i, size - 11 + j}
    place_info_bits(matrix, copy2_positions, Enum.reverse(bits))
  end

  defp place_info_bits(matrix, positions, bits) do
    positions
    |> Enum.zip(bits)
    |> Enum.reduce(matrix, fn {pos, bit}, mat ->
      value = if bit == 1, do: :dark, else: :light
      # Force-set even if reserved (format/version areas are pre-reserved)
      %{mat | modules: Map.put(mat.modules, pos, value), reserved: MapSet.put(mat.reserved, pos)}
    end)
  end
end
