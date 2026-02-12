defmodule Qiroex.Matrix.DataPlacer do
  @moduledoc """
  Places encoded data bits into the QR code matrix using the
  ISO 18004 two-column upward/downward snake pattern.

  Data bits are placed starting from the bottom-right corner,
  moving upward in 2-module-wide columns. When reaching the top
  or bottom edge, the direction reverses and shifts left by 2.
  Column 6 (vertical timing pattern) is skipped.
  """

  alias Qiroex.Matrix

  @doc """
  Places data bits into the matrix, skipping reserved modules.

  ## Parameters
    - `matrix` - matrix with function patterns already placed
    - `data_bits` - list of 0/1 integers to place

  ## Returns
    Updated matrix with data bits placed.
  """
  @spec place(Matrix.t(), list(0 | 1)) :: Matrix.t()
  def place(matrix, data_bits) do
    positions = data_module_positions(matrix)
    place_bits(matrix, positions, data_bits)
  end

  @doc """
  Returns the ordered list of positions where data bits are placed,
  following the two-column snake pattern. Skips reserved modules.
  """
  @spec data_module_positions(Matrix.t()) :: list(Matrix.position())
  def data_module_positions(%Matrix{size: size} = matrix) do
    # Start from the rightmost column pair and move left
    # Column pairs: (size-1, size-2), (size-3, size-4), ..., (1, 0)
    # Skip column 6 (timing pattern)
    col_pairs = generate_column_pairs(size)

    Enum.flat_map(col_pairs, fn {right_col, left_col, direction} ->
      rows = if direction == :up, do: (size - 1)..0//-1, else: 0..(size - 1)

      Enum.flat_map(rows, fn row ->
        [{row, right_col}, {row, left_col}]
        |> Enum.filter(fn pos ->
          Matrix.in_bounds?(matrix, pos) and not Matrix.reserved?(matrix, pos)
        end)
      end)
    end)
  end

  # Generate column pairs with their traversal direction
  # Starting from right side, moving left
  defp generate_column_pairs(size) do
    # Start at column (size - 1), go left in pairs
    # Skip column 6 entirely
    right_cols =
      (size - 1)..0//-2
      |> Enum.to_list()
      |> Enum.map(fn col ->
        # Adjust for column 6: any column <= 6 shifts left by 1
        if col <= 6, do: col - 1, else: col
      end)
      |> Enum.filter(&(&1 >= 0))
      |> Enum.uniq()

    right_cols
    |> Enum.with_index()
    |> Enum.map(fn {right_col, idx} ->
      left_col = right_col - 1
      direction = if rem(idx, 2) == 0, do: :up, else: :down
      {right_col, left_col, direction}
    end)
    |> Enum.filter(fn {_r, l, _d} -> l >= 0 end)
  end

  # Place bits at positions
  defp place_bits(matrix, positions, bits) do
    positions
    |> Enum.zip(bits)
    |> Enum.reduce(matrix, fn {pos, bit}, mat ->
      value = if bit == 1, do: :dark, else: :light
      Matrix.set_data(mat, pos, value)
    end)
  end
end
