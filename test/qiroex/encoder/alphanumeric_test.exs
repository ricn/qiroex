defmodule Qiroex.Encoder.AlphanumericTest do
  use ExUnit.Case, async: true

  alias Qiroex.Encoder.Alphanumeric

  describe "encode/1" do
    test "encodes HELLO WORLD (Thonky reference)" do
      # From Thonky QR tutorial:
      # HE → (17*45 + 14) = 779 → 11 bits = 01100001011
      # LL → (21*45 + 21) = 966 → 11 bits = 01111000110
      # O  → (24*45 + 36) = 1116... wait, pairs:
      # H=17, E=14 → 17*45+14 = 779
      # L=21, L=21 → 21*45+21 = 966
      # O=24, (space)=36 → 24*45+36 = 1116
      # W=32, O=24 → 32*45+24 = 1464
      # R=27, L=21 → 27*45+21 = 1236
      # D=13 (odd) → 13 → 6 bits

      bits = Alphanumeric.encode("HELLO WORLD")

      expected = <<779::11, 966::11, 1116::11, 1464::11, 1236::11, 13::6>>
      assert bits == expected
    end

    test "encodes single character as 6 bits" do
      # A = 10 → 6 bits
      bits = Alphanumeric.encode("A")
      assert bits == <<10::6>>
    end

    test "encodes pair as 11 bits" do
      # AB → 10*45 + 11 = 461
      bits = Alphanumeric.encode("AB")
      assert bits == <<461::11>>
    end

    test "encodes digits" do
      # 01 → 0*45 + 1 = 1 → 11 bits
      bits = Alphanumeric.encode("01")
      assert bits == <<1::11>>
    end
  end

  describe "valid?/1" do
    test "uppercase letters are valid" do
      assert Alphanumeric.valid?("ABCXYZ")
    end

    test "digits are valid" do
      assert Alphanumeric.valid?("0123456789")
    end

    test "special chars are valid" do
      assert Alphanumeric.valid?(" $%*+-./:")
    end

    test "lowercase letters are invalid" do
      refute Alphanumeric.valid?("Hello")
    end

    test "mixed valid input" do
      assert Alphanumeric.valid?("HELLO WORLD")
    end

    test "empty string is valid" do
      assert Alphanumeric.valid?("")
    end
  end
end
