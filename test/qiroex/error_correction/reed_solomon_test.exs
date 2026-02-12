defmodule Qiroex.ErrorCorrection.ReedSolomonTest do
  use ExUnit.Case, async: true

  alias Qiroex.ErrorCorrection.ReedSolomon

  describe "generator_polynomial/1" do
    test "generator for 7 EC codewords" do
      # Known generator polynomial coefficients for 7 EC codewords
      # g(x) = (x-α⁰)(x-α¹)(x-α²)(x-α³)(x-α⁴)(x-α⁵)(x-α⁶)
      poly = ReedSolomon.generator_polynomial(7)
      # degree 7 has 8 coefficients
      assert length(poly) == 8
      # First coefficient is always 1
      assert hd(poly) == 1
    end

    test "generator for 10 EC codewords has 11 coefficients" do
      poly = ReedSolomon.generator_polynomial(10)
      assert length(poly) == 11
      assert hd(poly) == 1
    end

    test "generator for 2 EC codewords" do
      # g(x) = (x - α⁰)(x - α¹) = x² + (α⁰ + α¹)x + α⁰·α¹
      # = x² + 3x + 2
      poly = ReedSolomon.generator_polynomial(2)
      assert poly == [1, 3, 2]
    end
  end

  describe "encode/2" do
    test "HELLO WORLD at V1-M (10 EC codewords)" do
      # From Thonky QR tutorial: "HELLO WORLD" at V1-M
      # Data codewords: [32, 91, 11, 120, 209, 114, 220, 77, 67, 64, 236, 17, 236, 17, 236, 17]
      data = [32, 91, 11, 120, 209, 114, 220, 77, 67, 64, 236, 17, 236, 17, 236, 17]
      ec = ReedSolomon.encode(data, 10)

      assert length(ec) == 10

      # Known EC codewords for this data
      expected = [196, 35, 39, 119, 235, 215, 231, 226, 93, 23]
      assert ec == expected
    end

    test "simple single-block encoding" do
      # V1-L has 19 data codewords and 7 EC codewords
      data = List.duplicate(0, 19)
      ec = ReedSolomon.encode(data, 7)
      assert length(ec) == 7
    end

    test "EC codewords are valid integers 0-255" do
      data = [1, 2, 3, 4, 5]
      ec = ReedSolomon.encode(data, 10)

      assert Enum.all?(ec, &(&1 >= 0 and &1 <= 255))
    end
  end
end
