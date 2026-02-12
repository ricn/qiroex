defmodule Qiroex.MatrixTest do
  use ExUnit.Case, async: true

  alias Qiroex.Matrix

  describe "new/1" do
    test "creates matrix with correct size for version 1" do
      matrix = Matrix.new(1)
      assert matrix.size == 21
      assert matrix.version == 1
    end

    test "creates matrix with correct size for version 40" do
      matrix = Matrix.new(40)
      assert matrix.size == 177
    end
  end

  describe "set/3 and get/2" do
    test "set and retrieve a value" do
      matrix = Matrix.new(1)
      matrix = Matrix.set(matrix, {0, 0}, :dark)
      assert Matrix.get(matrix, {0, 0}) == :dark
    end

    test "marks position as reserved" do
      matrix = Matrix.new(1)
      matrix = Matrix.set(matrix, {5, 5}, :light)
      assert Matrix.reserved?(matrix, {5, 5})
    end

    test "unset positions return nil" do
      matrix = Matrix.new(1)
      assert Matrix.get(matrix, {10, 10}) == nil
    end
  end

  describe "set_data/3" do
    test "sets value without marking as reserved" do
      matrix = Matrix.new(1)
      matrix = Matrix.set_data(matrix, {10, 10}, :dark)
      assert Matrix.get(matrix, {10, 10}) == :dark
      refute Matrix.reserved?(matrix, {10, 10})
    end
  end

  describe "in_bounds?/2" do
    test "valid positions return true" do
      matrix = Matrix.new(1)
      assert Matrix.in_bounds?(matrix, {0, 0})
      assert Matrix.in_bounds?(matrix, {20, 20})
    end

    test "out of bounds positions return false" do
      matrix = Matrix.new(1)
      refute Matrix.in_bounds?(matrix, {-1, 0})
      refute Matrix.in_bounds?(matrix, {21, 0})
      refute Matrix.in_bounds?(matrix, {0, 21})
    end
  end

  describe "to_list/2" do
    test "returns 2D boolean list with margin" do
      matrix = Matrix.new(1)
      list = Matrix.to_list(matrix, 4)

      # 29
      expected_size = 21 + 2 * 4
      assert length(list) == expected_size
      assert length(hd(list)) == expected_size
    end

    test "quiet zone is all zeros" do
      matrix = Matrix.new(1)
      matrix = Matrix.set(matrix, {0, 0}, :dark)
      list = Matrix.to_list(matrix, 4)

      # First row (margin) should be all 0
      assert Enum.all?(hd(list), &(&1 == 0))
      # Last row (margin) should be all 0
      assert Enum.all?(List.last(list), &(&1 == 0))
    end

    test "dark modules map to 1" do
      matrix = Matrix.new(1)
      matrix = Matrix.set(matrix, {0, 0}, :dark)
      list = Matrix.to_list(matrix, 4)

      # Position {0,0} in matrix → {4,4} in list (with margin=4)
      assert Enum.at(Enum.at(list, 4), 4) == 1
    end
  end
end
