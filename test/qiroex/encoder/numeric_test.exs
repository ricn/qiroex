defmodule Qiroex.Encoder.NumericTest do
  use ExUnit.Case, async: true

  alias Qiroex.Encoder.Numeric

  describe "encode/1" do
    test "encodes 3-digit groups as 10 bits" do
      # 123 → binary 1111011 padded to 10 bits = 0001111011
      bits = Numeric.encode("123")
      assert bits == <<123::10>>
    end

    test "encodes 2-digit remainder as 7 bits" do
      # 45 → binary 101101 padded to 7 bits = 0101101
      bits = Numeric.encode("45")
      assert bits == <<45::7>>
    end

    test "encodes 1-digit remainder as 4 bits" do
      # 6 → binary 110 padded to 4 bits = 0110
      bits = Numeric.encode("6")
      assert bits == <<6::4>>
    end

    test "encodes 8675309 (Thonky reference)" do
      # 867 → 10 bits, 530 → 10 bits, 9 → 4 bits
      bits = Numeric.encode("8675309")
      expected = <<867::10, 530::10, 9::4>>
      assert bits == expected
    end

    test "encodes 01234567890123456 (16 digits)" do
      bits = Numeric.encode("01234567890123456")
      # 5 groups of 3 (012, 345, 678, 901, 234) + 1 remainder of 1 (56 as 2-digit = 7 bits?)
      # Wait: 16 digits = 5 groups of 3 + 1 remainder digit
      # 012 → 12, 345 → 345, 678 → 678, 901 → 901, 234 → 234, 56 → 56
      # Actually 16/3 = 5 remainder 1: groups [012, 345, 678, 901, 234], remainder [56]
      # No wait, 16 = 5*3 + 1, so groups [012, 345, 678, 901, 234] and remainder [5, 6]
      # Actually chunk_every(3) on 16 digits: [0,1,2], [3,4,5], [6,7,8], [9,0,1], [2,3,4], [5,6]
      # Last group is [5,6] → 56 → 7 bits
      expected = <<12::10, 345::10, 678::10, 901::10, 234::10, 56::7>>
      assert bits == expected
    end

    test "encodes single digit 0" do
      bits = Numeric.encode("0")
      assert bits == <<0::4>>
    end
  end

  describe "valid?/1" do
    test "all digits is valid" do
      assert Numeric.valid?("0123456789")
    end

    test "letters are invalid" do
      refute Numeric.valid?("12A34")
    end

    test "empty string is invalid" do
      refute Numeric.valid?("")
    end

    test "spaces are invalid" do
      refute Numeric.valid?("12 34")
    end
  end
end
