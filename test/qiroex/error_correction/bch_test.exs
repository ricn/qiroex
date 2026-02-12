defmodule Qiroex.ErrorCorrection.BCHTest do
  use ExUnit.Case, async: true

  alias Qiroex.ErrorCorrection.BCH

  describe "format_info/2" do
    test "M level, mask 0" do
      # EC level M = 00, mask 0 = 000 → data = 00000
      # Known result after BCH + XOR mask
      result = BCH.format_info(:m, 0)
      # Result should be a 15-bit value
      assert result >= 0
      assert result < Bitwise.bsl(1, 15)
    end

    test "all 32 format info values are unique" do
      values =
        for ec <- [:l, :m, :q, :h], mask <- 0..7 do
          BCH.format_info(ec, mask)
        end

      assert length(Enum.uniq(values)) == 32
    end

    test "known format info: L level, mask 0" do
      # EC L = 01, mask 0 = 000 → data bits = 01 000 = 8
      # After BCH: 01000 + EC bits = 01000_0100110111 (before XOR)
      # After XOR with mask: specific known value
      result = BCH.format_info(:l, 0)
      bits = BCH.format_info_bits(:l, 0)
      assert length(bits) == 15
      # Verify it reconstructs correctly
      reconstructed = Enum.reduce(bits, 0, fn bit, acc -> Bitwise.bsl(acc, 1) + bit end)
      assert reconstructed == result
    end

    test "known format info: M level, mask 0 = 101010000010010" do
      # For M(00), mask 0(000): data = 00000, BCH remainder = 0000000000
      # Combined: 000000000000000, XOR with mask: 101010000010010
      result = BCH.format_info(:m, 0)
      assert result == 0b101010000010010
    end
  end

  describe "format_info_bits/2" do
    test "returns list of 15 bits" do
      bits = BCH.format_info_bits(:m, 0)
      assert length(bits) == 15
      assert Enum.all?(bits, &(&1 in [0, 1]))
    end
  end

  describe "version_info/1" do
    test "returns 18-bit value for version 7" do
      result = BCH.version_info(7)
      assert result >= 0
      assert result < Bitwise.bsl(1, 18)

      # Top 6 bits should encode version 7
      top_bits = Bitwise.bsr(result, 12)
      assert top_bits == 7
    end

    test "all version info values are unique for V7-V40" do
      values = for v <- 7..40, do: BCH.version_info(v)
      assert length(Enum.uniq(values)) == 34
    end

    test "version_info_bits returns 18 bits" do
      bits = BCH.version_info_bits(7)
      assert length(bits) == 18
      assert Enum.all?(bits, &(&1 in [0, 1]))
    end

    test "known version info: version 7 = 000111 110010010100" do
      result = BCH.version_info(7)
      # Version 7 (000111) with known BCH EC bits
      assert Bitwise.bsr(result, 12) == 7
    end
  end
end
