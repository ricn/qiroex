defmodule Qiroex.Matrix.RegionsTest do
  use ExUnit.Case, async: true

  alias Qiroex.Matrix.Regions
  alias Qiroex.QR

  setup do
    {:ok, qr} = QR.encode("HELLO", level: :m)
    %{matrix: qr.matrix}
  end

  describe "classify/2" do
    test "top-left finder eye center", %{matrix: matrix} do
      # Center of TL finder: rows 2-4, cols 2-4
      assert Regions.classify(matrix, {3, 3}) == :finder_eye
      assert Regions.classify(matrix, {2, 2}) == :finder_eye
      assert Regions.classify(matrix, {4, 4}) == :finder_eye
    end

    test "top-left finder inner ring", %{matrix: matrix} do
      # Inner ring: rows 1-5, cols 1-5 but not 2-4/2-4
      assert Regions.classify(matrix, {1, 1}) == :finder_inner
      assert Regions.classify(matrix, {1, 3}) == :finder_inner
      assert Regions.classify(matrix, {5, 5}) == :finder_inner
    end

    test "top-left finder outer border", %{matrix: matrix} do
      # Outer ring: row 0 or 6, col 0 or 6
      assert Regions.classify(matrix, {0, 0}) == :finder_outer
      assert Regions.classify(matrix, {0, 6}) == :finder_outer
      assert Regions.classify(matrix, {6, 0}) == :finder_outer
      assert Regions.classify(matrix, {6, 6}) == :finder_outer
    end

    test "top-right finder pattern", %{matrix: matrix} do
      size = matrix.size
      # TR finder origin: {0, size-7}
      tr_col = size - 7
      assert Regions.classify(matrix, {3, tr_col + 3}) == :finder_eye
      assert Regions.classify(matrix, {1, tr_col + 1}) == :finder_inner
      assert Regions.classify(matrix, {0, tr_col}) == :finder_outer
    end

    test "bottom-left finder pattern", %{matrix: matrix} do
      size = matrix.size
      # BL finder origin: {size-7, 0}
      bl_row = size - 7
      assert Regions.classify(matrix, {bl_row + 3, 3}) == :finder_eye
      assert Regions.classify(matrix, {bl_row + 1, 1}) == :finder_inner
      assert Regions.classify(matrix, {bl_row, 0}) == :finder_outer
    end

    test "separator positions", %{matrix: matrix} do
      # TL separator: row 7 cols 0-7
      assert Regions.classify(matrix, {7, 0}) == :separator
      assert Regions.classify(matrix, {7, 7}) == :separator
      # TL separator: col 7 rows 0-6
      assert Regions.classify(matrix, {0, 7}) == :separator
    end

    test "timing pattern on row 6", %{matrix: matrix} do
      # Timing pattern: row 6, cols 8 to size-9
      assert Regions.classify(matrix, {6, 8}) == :timing
      assert Regions.classify(matrix, {6, 10}) == :timing
    end

    test "timing pattern on col 6", %{matrix: matrix} do
      # Timing pattern: col 6, rows 8 to size-9
      assert Regions.classify(matrix, {8, 6}) == :timing
      assert Regions.classify(matrix, {10, 6}) == :timing
    end

    test "data modules in center area", %{matrix: matrix} do
      # Module at (10, 10) should be data for V1
      assert Regions.classify(matrix, {10, 10}) == :data
    end
  end

  describe "build_map/1" do
    test "returns map covering all positions", %{matrix: matrix} do
      map = Regions.build_map(matrix)
      size = matrix.size

      assert map_size(map) == size * size

      # Every position should have a valid region
      for row <- 0..(size - 1), col <- 0..(size - 1) do
        region = Map.fetch!(map, {row, col})
        assert region in [:finder_eye, :finder_inner, :finder_outer,
                          :separator, :alignment, :timing, :data]
      end
    end

    test "finder regions count correctly for V1", %{matrix: matrix} do
      map = Regions.build_map(matrix)

      eye_count = Enum.count(map, fn {_, r} -> r == :finder_eye end)
      inner_count = Enum.count(map, fn {_, r} -> r == :finder_inner end)
      outer_count = Enum.count(map, fn {_, r} -> r == :finder_outer end)

      # 3 finders × 3×3 eye = 27
      assert eye_count == 27
      # 3 finders × (5×5 - 3×3) = 3 × 16 = 48
      assert inner_count == 48
      # 3 finders × (7×7 - 5×5) = 3 × 24 = 72
      assert outer_count == 72
    end
  end

  describe "alignment pattern classification" do
    test "version 2+ has alignment patterns" do
      # Force version 2 which has one alignment pattern at center
      {:ok, qr} = QR.encode("A", level: :l, version: 2)
      map = Regions.build_map(qr.matrix)

      alignment_count = Enum.count(map, fn {_, r} -> r == :alignment end)
      # V2 has 1 alignment pattern = 5×5 = 25 modules
      assert alignment_count == 25
    end
  end
end
