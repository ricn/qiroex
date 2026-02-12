defmodule Qiroex.ErrorCorrection.GaloisFieldTest do
  use ExUnit.Case, async: true

  alias Qiroex.ErrorCorrection.GaloisField, as: GF

  describe "exp/1 (antilog table)" do
    test "α⁰ = 1" do
      assert GF.exp(0) == 1
    end

    test "α¹ = 2" do
      assert GF.exp(1) == 2
    end

    test "α⁷ = 128" do
      assert GF.exp(7) == 128
    end

    test "α⁸ = 29 (after XOR with 285)" do
      # 256 XOR 285 = 29
      assert GF.exp(8) == 29
    end

    test "first several powers of alpha" do
      # Known values from the QR code spec
      expected = [1, 2, 4, 8, 16, 32, 64, 128, 29, 58, 116, 232, 205, 135, 19, 38]

      for {expected_val, i} <- Enum.with_index(expected) do
        assert GF.exp(i) == expected_val, "exp(#{i}) should be #{expected_val}, got #{GF.exp(i)}"
      end
    end

    test "wraps around: exp values mod 255" do
      # α^255 should equal α^0 = 1
      assert GF.exp(255) == GF.exp(0)
    end
  end

  describe "log/1" do
    test "log(1) = 0 (since α⁰ = 1)" do
      assert GF.log(1) == 0
    end

    test "log(2) = 1 (since α¹ = 2)" do
      assert GF.log(2) == 1
    end

    test "log(0) raises ArgumentError" do
      assert_raise ArgumentError, fn -> GF.log(0) end
    end

    test "log(exp(n)) == n for all n in 0..254" do
      for n <- 0..254 do
        assert GF.log(GF.exp(n)) == n
      end
    end
  end

  describe "add/2" do
    test "addition is XOR" do
      assert GF.add(5, 3) == Bitwise.bxor(5, 3)
      assert GF.add(0, 0) == 0
      assert GF.add(255, 255) == 0
    end

    test "a + a = 0 (characteristic 2)" do
      for a <- 0..255 do
        assert GF.add(a, a) == 0
      end
    end
  end

  describe "multiply/2" do
    test "anything times 0 is 0" do
      assert GF.multiply(0, 42) == 0
      assert GF.multiply(42, 0) == 0
      assert GF.multiply(0, 0) == 0
    end

    test "anything times 1 is itself" do
      for a <- 1..255 do
        assert GF.multiply(a, 1) == a
        assert GF.multiply(1, a) == a
      end
    end

    test "α⁵ × α³ = α⁸ = 29" do
      # 32
      a5 = GF.exp(5)
      # 8
      a3 = GF.exp(3)
      # 29
      assert GF.multiply(a5, a3) == GF.exp(8)
    end

    test "commutativity" do
      assert GF.multiply(17, 42) == GF.multiply(42, 17)
    end
  end

  describe "inverse/1" do
    test "inverse(0) raises ArgumentError" do
      assert_raise ArgumentError, fn -> GF.inverse(0) end
    end

    test "a * inverse(a) = 1 for all nonzero a" do
      for a <- 1..255 do
        assert GF.multiply(a, GF.inverse(a)) == 1,
               "#{a} * inverse(#{a}) should be 1"
      end
    end
  end

  describe "power/2" do
    test "a^0 = 1 for nonzero a" do
      assert GF.power(5, 0) == 1
    end

    test "a^1 = a" do
      assert GF.power(42, 1) == 42
    end

    test "0^n = 0 for positive n" do
      assert GF.power(0, 5) == 0
    end

    test "0^0 raises" do
      assert_raise ArgumentError, fn -> GF.power(0, 0) end
    end
  end

  describe "tables" do
    test "exp_table has 256 entries (0-255)" do
      table = GF.exp_table()
      assert map_size(table) == 256
    end

    test "log_table has 255 entries (1-255, since log(0) is undefined)" do
      table = GF.log_table()
      assert map_size(table) == 255
    end

    test "all 255 nonzero field elements appear in exp table" do
      values =
        0..254
        |> Enum.map(&GF.exp/1)
        |> MapSet.new()

      assert MapSet.size(values) == 255
    end
  end
end
