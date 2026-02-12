defmodule Qiroex.Matrix.BuilderTest do
  use ExUnit.Case, async: true

  alias Qiroex.Matrix
  alias Qiroex.Matrix.Builder

  describe "build/1" do
    test "creates matrix with finder patterns for V1" do
      matrix = Builder.build(1)

      # Top-left finder pattern: 7×7 at (0,0)
      # Outer dark border
      for i <- 0..6 do
        assert Matrix.dark?(matrix, {0, i}), "TL finder top row at (0,#{i}) should be dark"
        assert Matrix.dark?(matrix, {6, i}), "TL finder bottom row at (6,#{i}) should be dark"
        assert Matrix.dark?(matrix, {i, 0}), "TL finder left col at (#{i},0) should be dark"
        assert Matrix.dark?(matrix, {i, 6}), "TL finder right col at (#{i},6) should be dark"
      end

      # Inner light ring
      for i <- 1..5 do
        assert Matrix.get(matrix, {1, i}) == :light, "TL inner ring (1,#{i}) should be light"
        assert Matrix.get(matrix, {5, i}) == :light, "TL inner ring (5,#{i}) should be light"
      end

      # Center 3×3 dark
      for r <- 2..4, c <- 2..4 do
        assert Matrix.dark?(matrix, {r, c}), "TL center (#{r},#{c}) should be dark"
      end
    end

    test "top-right finder pattern at correct position for V1" do
      matrix = Builder.build(1)
      # Size = 21, so top-right finder starts at col 14
      assert Matrix.dark?(matrix, {0, 14}), "TR finder top-left corner"
      assert Matrix.dark?(matrix, {0, 20}), "TR finder top-right corner"
      assert Matrix.dark?(matrix, {6, 14}), "TR finder bottom-left corner"
    end

    test "bottom-left finder pattern at correct position for V1" do
      matrix = Builder.build(1)
      # Size = 21, so bottom-left finder starts at row 14
      assert Matrix.dark?(matrix, {14, 0}), "BL finder top-left corner"
      assert Matrix.dark?(matrix, {20, 0}), "BL finder bottom-left corner"
      assert Matrix.dark?(matrix, {20, 6}), "BL finder bottom-right corner"
    end

    test "separators are light modules" do
      matrix = Builder.build(1)
      # Right separator of TL finder: col 7, rows 0-7
      for r <- 0..7 do
        assert Matrix.get(matrix, {r, 7}) == :light, "TL right separator (#{r},7)"
      end

      # Bottom separator of TL finder: row 7, cols 0-7
      for c <- 0..7 do
        assert Matrix.get(matrix, {7, c}) == :light, "TL bottom separator (7,#{c})"
      end
    end

    test "timing pattern alternates on row 6 for V1" do
      matrix = Builder.build(1)
      # Timing pattern on row 6, between columns 8 and 12 (between separators)
      for col <- 8..12 do
        expected = if rem(col, 2) == 0, do: :dark, else: :light

        assert Matrix.get(matrix, {6, col}) == expected,
               "Timing row 6, col #{col} should be #{expected}"
      end
    end

    test "timing pattern alternates on col 6 for V1" do
      matrix = Builder.build(1)

      for row <- 8..12 do
        expected = if rem(row, 2) == 0, do: :dark, else: :light

        assert Matrix.get(matrix, {row, 6}) == expected,
               "Timing col 6, row #{row} should be #{expected}"
      end
    end

    test "dark module at correct position for V1" do
      matrix = Builder.build(1)
      # Dark module at (4*1 + 9, 8) = (13, 8)
      assert Matrix.dark?(matrix, {13, 8})
    end

    test "dark module at correct position for V7" do
      matrix = Builder.build(7)
      # Dark module at (4*7 + 9, 8) = (37, 8)
      assert Matrix.dark?(matrix, {37, 8})
    end

    test "V1 has no alignment patterns" do
      matrix = Builder.build(1)
      # V1: no alignment patterns, but we can verify center area is unreserved
      # Position (10, 10) should be available for data
      refute Matrix.reserved?(matrix, {10, 10})
    end

    test "V2 has alignment pattern at (18, 18)" do
      matrix = Builder.build(2)
      # Alignment pattern center at (18, 18)
      assert Matrix.dark?(matrix, {18, 18}), "alignment center"
      assert Matrix.get(matrix, {17, 17}) == :light, "alignment inner ring"
      assert Matrix.dark?(matrix, {16, 16}), "alignment outer ring"
    end

    test "V7 has alignment patterns (skipping finder overlap)" do
      matrix = Builder.build(7)
      # V7 alignment centers: [6, 22, 38]
      # (6,6) overlaps finder → skipped
      # (6,38) overlaps finder → skipped
      # (38,6) overlaps finder → skipped
      # (22,22) should be present
      assert Matrix.dark?(matrix, {22, 22}), "V7 alignment center at (22,22)"
      # (22,6) should be present (doesn't overlap finder)
      assert Matrix.dark?(matrix, {22, 6}), "V7 alignment center at (22,6)"
    end

    test "all positions are either reserved or nil after build" do
      matrix = Builder.build(1)

      for r <- 0..20, c <- 0..20 do
        if Matrix.reserved?(matrix, {r, c}) do
          assert Matrix.get(matrix, {r, c}) in [:dark, :light],
                 "Reserved position (#{r},#{c}) should have a value"
        end
      end
    end
  end

  describe "finalize/3" do
    test "places format info" do
      matrix = Builder.build(1)
      finalized = Builder.finalize(matrix, :m, 0)

      # Format info positions should be set (not nil)
      # Check a few known format info positions
      assert Matrix.get(finalized, {8, 0}) in [:dark, :light]
      assert Matrix.get(finalized, {8, 1}) in [:dark, :light]
    end
  end
end
