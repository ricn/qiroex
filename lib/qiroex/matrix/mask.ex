defmodule Qiroex.Matrix.Mask do
  @moduledoc """
  QR code data masking.

  Implements all 8 mask patterns and the penalty scoring system.
  Applies mask patterns via XOR to data modules only (not function patterns).
  Selects the optimal mask using the ISO 18004 penalty rules.
  """

  alias Qiroex.Matrix


  @doc """
  Applies the given mask pattern to data modules in the matrix.

  Only data modules (non-reserved) are XOR'd with the mask.
  """
  @spec apply_mask(Matrix.t(), 0..7) :: Matrix.t()
  def apply_mask(%Matrix{size: size} = matrix, mask_number) do
    Enum.reduce(0..(size - 1), matrix, fn row, mat ->
      Enum.reduce(0..(size - 1), mat, fn col, mat2 ->
        pos = {row, col}

        if Matrix.reserved?(mat2, pos) or Matrix.get(mat2, pos) == nil do
          mat2
        else
          if should_mask?(mask_number, row, col) do
            current = Matrix.get(mat2, pos)
            toggled = if current == :dark, do: :light, else: :dark
            Matrix.set_data(mat2, pos, toggled)
          else
            mat2
          end
        end
      end)
    end)
  end

  @doc """
  Evaluates the penalty score for the given matrix.
  Returns the total penalty (sum of all 4 rules).
  """
  @spec evaluate_penalty(Matrix.t()) :: non_neg_integer()
  def evaluate_penalty(matrix) do
    penalty_rule1(matrix) +
    penalty_rule2(matrix) +
    penalty_rule3(matrix) +
    penalty_rule4(matrix)
  end

  @doc """
  Selects the best mask pattern by trying all 8 masks and picking
  the one with the lowest penalty score.

  ## Parameters
    - `matrix` - matrix with data placed but not yet masked
    - `ec_level` - needed for format info placement during evaluation

  ## Returns
    `{best_mask_number, masked_matrix}` with format/version info placed.
  """
  @spec select_best(Matrix.t(), Qiroex.Spec.ec_level()) :: {0..7, Matrix.t()}
  def select_best(matrix, ec_level) do
    0..7
    |> Enum.map(fn mask ->
      masked = apply_mask(matrix, mask)
      finalized = Qiroex.Matrix.Builder.finalize(masked, ec_level, mask)
      penalty = evaluate_penalty(finalized)
      {mask, finalized, penalty}
    end)
    |> Enum.min_by(fn {_mask, _matrix, penalty} -> penalty end)
    |> then(fn {mask, matrix, _penalty} -> {mask, matrix} end)
  end

  @doc """
  Returns true if the module at (row, col) should be toggled by the given mask pattern.
  """
  @spec should_mask?(0..7, non_neg_integer(), non_neg_integer()) :: boolean()
  def should_mask?(0, row, col), do: rem(row + col, 2) == 0
  def should_mask?(1, row, _col), do: rem(row, 2) == 0
  def should_mask?(2, _row, col), do: rem(col, 3) == 0
  def should_mask?(3, row, col), do: rem(row + col, 3) == 0
  def should_mask?(4, row, col), do: rem(div(row, 2) + div(col, 3), 2) == 0
  def should_mask?(5, row, col), do: rem(row * col, 2) + rem(row * col, 3) == 0
  def should_mask?(6, row, col), do: rem(rem(row * col, 2) + rem(row * col, 3), 2) == 0
  def should_mask?(7, row, col), do: rem(rem(row + col, 2) + rem(row * col, 3), 2) == 0

  # === Penalty Rule 1 ===
  # 5+ consecutive same-color modules in a row or column → 3 + (count - 5)

  defp penalty_rule1(%Matrix{size: size} = matrix) do
    row_penalty =
      Enum.reduce(0..(size - 1), 0, fn row, acc ->
        acc + count_runs(matrix, Enum.map(0..(size - 1), &{row, &1}))
      end)

    col_penalty =
      Enum.reduce(0..(size - 1), 0, fn col, acc ->
        acc + count_runs(matrix, Enum.map(0..(size - 1), &{&1, col}))
      end)

    row_penalty + col_penalty
  end

  defp count_runs(matrix, positions) do
    values = Enum.map(positions, &Matrix.dark?(matrix, &1))

    {penalty, _last, _count} =
      Enum.reduce(values, {0, nil, 0}, fn dark, {pen, last, count} ->
        if dark == last do
          new_count = count + 1
          if new_count == 5 do
            {pen + 3, dark, new_count}
          else
            if new_count > 5 do
              {pen + 1, dark, new_count}
            else
              {pen, dark, new_count}
            end
          end
        else
          {pen, dark, 1}
        end
      end)

    penalty
  end

  # === Penalty Rule 2 ===
  # Each 2×2 same-color block → +3

  defp penalty_rule2(%Matrix{size: size} = matrix) do
    Enum.reduce(0..(size - 2), 0, fn row, acc ->
      Enum.reduce(0..(size - 2), acc, fn col, acc2 ->
        tl = Matrix.dark?(matrix, {row, col})
        tr = Matrix.dark?(matrix, {row, col + 1})
        bl = Matrix.dark?(matrix, {row + 1, col})
        br = Matrix.dark?(matrix, {row + 1, col + 1})

        if tl == tr and tr == bl and bl == br do
          acc2 + 3
        else
          acc2
        end
      end)
    end)
  end

  # === Penalty Rule 3 ===
  # Pattern 10111010000 or 00001011101 in any row or column → +40

  @finder_pattern1 [true, false, true, true, true, false, true, false, false, false, false]
  @finder_pattern2 [false, false, false, false, true, false, true, true, true, false, true]

  defp penalty_rule3(%Matrix{size: size} = matrix) do
    row_penalty =
      Enum.reduce(0..(size - 1), 0, fn row, acc ->
        line = Enum.map(0..(size - 1), &Matrix.dark?(matrix, {row, &1}))
        acc + count_finder_patterns(line)
      end)

    col_penalty =
      Enum.reduce(0..(size - 1), 0, fn col, acc ->
        line = Enum.map(0..(size - 1), &Matrix.dark?(matrix, {&1, col}))
        acc + count_finder_patterns(line)
      end)

    row_penalty + col_penalty
  end

  defp count_finder_patterns(line) when length(line) < 11, do: 0
  defp count_finder_patterns(line) do
    0..(length(line) - 11)
    |> Enum.count(fn i ->
      window = Enum.slice(line, i, 11)
      window == @finder_pattern1 or window == @finder_pattern2
    end)
    |> Kernel.*(40)
  end

  # === Penalty Rule 4 ===
  # Ratio of dark modules deviation from 50%
  # 10 × floor(|percentage - 50| / 5)

  defp penalty_rule4(%Matrix{size: size} = matrix) do
    total = size * size

    dark_count =
      Enum.reduce(0..(size - 1), 0, fn row, acc ->
        Enum.reduce(0..(size - 1), acc, fn col, acc2 ->
          if Matrix.dark?(matrix, {row, col}), do: acc2 + 1, else: acc2
        end)
      end)

    percentage = dark_count * 100 / total
    prev_multiple = Float.floor(percentage / 5) * 5
    next_multiple = Float.ceil(percentage / 5) * 5

    prev_penalty = abs(prev_multiple - 50) / 5 * 10
    next_penalty = abs(next_multiple - 50) / 5 * 10

    trunc(min(prev_penalty, next_penalty))
  end
end
