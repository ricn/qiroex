defmodule Qiroex.Matrix.MaskTest do
  use ExUnit.Case, async: true

  alias Qiroex.Matrix
  alias Qiroex.Matrix.Builder
  alias Qiroex.Matrix.DataPlacer
  alias Qiroex.Matrix.Mask

  describe "should_mask?/3" do
    test "mask 0: (row + col) mod 2 == 0" do
      assert Mask.should_mask?(0, 0, 0)
      assert Mask.should_mask?(0, 1, 1)
      assert Mask.should_mask?(0, 2, 0)
      refute Mask.should_mask?(0, 0, 1)
      refute Mask.should_mask?(0, 1, 0)
    end

    test "mask 1: row mod 2 == 0" do
      assert Mask.should_mask?(1, 0, 0)
      assert Mask.should_mask?(1, 0, 5)
      assert Mask.should_mask?(1, 2, 3)
      refute Mask.should_mask?(1, 1, 0)
      refute Mask.should_mask?(1, 3, 5)
    end

    test "mask 2: col mod 3 == 0" do
      assert Mask.should_mask?(2, 5, 0)
      assert Mask.should_mask?(2, 5, 3)
      assert Mask.should_mask?(2, 5, 6)
      refute Mask.should_mask?(2, 5, 1)
      refute Mask.should_mask?(2, 5, 2)
    end

    test "mask 3: (row + col) mod 3 == 0" do
      assert Mask.should_mask?(3, 0, 0)
      assert Mask.should_mask?(3, 1, 2)
      assert Mask.should_mask?(3, 3, 0)
      refute Mask.should_mask?(3, 0, 1)
    end

    test "mask 4: (row div 2 + col div 3) mod 2 == 0" do
      assert Mask.should_mask?(4, 0, 0)
      assert Mask.should_mask?(4, 0, 1)
      assert Mask.should_mask?(4, 0, 2)
      refute Mask.should_mask?(4, 0, 3)
    end

    test "mask 5: (row * col) mod 2 + (row * col) mod 3 == 0" do
      assert Mask.should_mask?(5, 0, 0)
      assert Mask.should_mask?(5, 0, 1)
      assert Mask.should_mask?(5, 3, 4)
      refute Mask.should_mask?(5, 1, 1)
    end

    test "mask 6: ((row * col) mod 2 + (row * col) mod 3) mod 2 == 0" do
      assert Mask.should_mask?(6, 0, 0)
      assert Mask.should_mask?(6, 0, 1)
      # (1,1): rem(rem(1,2)+rem(1,3), 2) = rem(1+1, 2) = 0 → true
      assert Mask.should_mask?(6, 1, 1)
      # (1,2): rem(rem(2, 2) + rem(2, 3), 2) = rem(0 + 2, 2) = 0 → true
      assert Mask.should_mask?(6, 1, 2)
      # (3,1): rem(rem(3, 2) + rem(3, 3), 2) = rem(1 + 0, 2) = 1 → false
      refute Mask.should_mask?(6, 3, 1)
    end

    test "mask 7: ((row + col) mod 2 + (row * col) mod 3) mod 2 == 0" do
      assert Mask.should_mask?(7, 0, 0)
      refute Mask.should_mask?(7, 0, 1)
      assert Mask.should_mask?(7, 0, 2)
    end
  end

  describe "apply_mask/2" do
    test "only toggles unreserved (data) modules" do
      matrix = Builder.build(1)
      # Place all zeros (light)
      bits = List.duplicate(0, 208)
      matrix = DataPlacer.place(matrix, bits)

      masked = Mask.apply_mask(matrix, 0)

      # Reserved modules should be unchanged
      assert Matrix.dark?(masked, {0, 0}), "Finder corner should remain dark"
      assert Matrix.get(masked, {1, 1}) == :light, "Finder inner should remain light"
    end

    test "applying same mask twice restores original" do
      matrix = Builder.build(1)
      bits = Enum.map(0..207, fn i -> (rem(i, 3) == 0 && 1) || 0 end)
      matrix = DataPlacer.place(matrix, bits)

      double_masked = matrix |> Mask.apply_mask(3) |> Mask.apply_mask(3)

      # Data modules should be restored
      positions = DataPlacer.data_module_positions(matrix)

      for pos <- positions do
        assert Matrix.get(double_masked, pos) == Matrix.get(matrix, pos),
               "Position #{inspect(pos)} should be restored after double mask"
      end
    end
  end

  describe "evaluate_penalty/1" do
    test "returns non-negative integer" do
      matrix = Builder.build(1)
      bits = List.duplicate(0, 208)
      matrix = DataPlacer.place(matrix, bits)
      masked = Mask.apply_mask(matrix, 0)

      penalty = Mask.evaluate_penalty(masked)
      assert is_integer(penalty)
      assert penalty >= 0
    end

    test "all-dark data has high penalty" do
      matrix = Builder.build(1)
      bits = List.duplicate(1, 208)
      matrix = DataPlacer.place(matrix, bits)

      penalty_all_dark = Mask.evaluate_penalty(matrix)

      # Apply mask to break up the pattern
      masked = Mask.apply_mask(matrix, 0)
      penalty_masked = Mask.evaluate_penalty(masked)

      # Masking should generally reduce penalty
      assert penalty_masked < penalty_all_dark
    end
  end

  describe "select_best/2" do
    test "returns a mask number between 0 and 7" do
      matrix = Builder.build(1)
      bits = List.duplicate(0, 208)
      matrix = DataPlacer.place(matrix, bits)

      {mask_num, masked_matrix} = Mask.select_best(matrix, :m)

      assert mask_num in 0..7
      assert %Matrix{} = masked_matrix
    end

    test "selected mask produces lowest penalty" do
      matrix = Builder.build(1)
      bits = Enum.map(0..207, fn i -> rem(i, 2) end)
      matrix = DataPlacer.place(matrix, bits)

      {best_mask, _masked_matrix} = Mask.select_best(matrix, :m)

      # The selected mask should have the lowest penalty among all 8
      best_penalty =
        Mask.apply_mask(matrix, best_mask) |> Mask.evaluate_penalty()

      for mask_num <- 0..7 do
        penalty = Mask.apply_mask(matrix, mask_num) |> Mask.evaluate_penalty()

        assert best_penalty <= penalty,
               "Mask #{best_mask} (penalty #{best_penalty}) should be <= mask #{mask_num} (penalty #{penalty})"
      end
    end
  end
end
