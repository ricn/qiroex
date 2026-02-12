defmodule Qiroex.Matrix.DataPlacerTest do
  use ExUnit.Case, async: true

  alias Qiroex.Matrix
  alias Qiroex.Matrix.Builder
  alias Qiroex.Matrix.DataPlacer

  describe "data_module_positions/1" do
    test "returns positions for V1 matrix" do
      matrix = Builder.build(1)
      positions = DataPlacer.data_module_positions(matrix)

      # V1 has 21×21 = 441 total modules
      # Function patterns take up some, data positions are the rest
      assert is_list(positions)
      assert length(positions) > 0

      # All returned positions should be unreserved
      for pos <- positions do
        refute Matrix.reserved?(matrix, pos),
               "Data position #{inspect(pos)} should not be reserved"
      end
    end

    test "positions skip column 6 (timing column)" do
      matrix = Builder.build(1)
      positions = DataPlacer.data_module_positions(matrix)

      # Column 6 is the vertical timing pattern column
      # Data positions should never be in column 6
      cols = Enum.map(positions, fn {_r, c} -> c end)
      refute 6 in cols, "No data positions should be in column 6"
    end

    test "positions are all in bounds" do
      matrix = Builder.build(1)
      positions = DataPlacer.data_module_positions(matrix)

      for {r, c} = pos <- positions do
        assert Matrix.in_bounds?(matrix, pos),
               "Position (#{r},#{c}) should be in bounds"
      end
    end

    test "V1 data position count matches expected" do
      matrix = Builder.build(1)
      positions = DataPlacer.data_module_positions(matrix)

      # V1-M has 16 data codewords + 10 EC codewords = 26 total = 208 bits
      # V1 has 208 data modules
      assert length(positions) == 208
    end
  end

  describe "place/2" do
    test "places all data bits into V1 matrix" do
      matrix = Builder.build(1)
      # V1 has 208 data module positions
      bits = List.duplicate(1, 208)

      placed = DataPlacer.place(matrix, bits)

      positions = DataPlacer.data_module_positions(matrix)
      for pos <- positions do
        assert Matrix.get(placed, pos) == :dark,
               "All data bits should be dark (1) at #{inspect(pos)}"
      end
    end

    test "places zeros as light modules" do
      matrix = Builder.build(1)
      bits = List.duplicate(0, 208)

      placed = DataPlacer.place(matrix, bits)

      positions = DataPlacer.data_module_positions(matrix)
      for pos <- positions do
        assert Matrix.get(placed, pos) == :light,
               "All data bits should be light (0) at #{inspect(pos)}"
      end
    end

    test "does not overwrite reserved modules" do
      matrix = Builder.build(1)
      bits = List.duplicate(1, 208)

      placed = DataPlacer.place(matrix, bits)

      # Check that a finder pattern corner is still correct
      assert Matrix.dark?(placed, {0, 0})
      assert Matrix.get(placed, {1, 1}) == :light
    end

    test "handles mixed data pattern" do
      matrix = Builder.build(1)
      bits = Enum.map(0..207, fn i -> rem(i, 2) end)

      placed = DataPlacer.place(matrix, bits)

      positions = DataPlacer.data_module_positions(matrix)

      Enum.zip(positions, bits)
      |> Enum.each(fn {pos, bit} ->
        expected = if bit == 1, do: :dark, else: :light
        assert Matrix.get(placed, pos) == expected
      end)
    end
  end
end
