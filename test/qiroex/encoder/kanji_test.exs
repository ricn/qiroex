defmodule Qiroex.Encoder.KanjiTest do
  use ExUnit.Case, async: true

  alias Qiroex.Encoder.Kanji

  describe "encode/1" do
    test "encodes Shift JIS character in 0x8140-0x9FFC range" do
      # 茗 in Shift JIS = 0x935F
      # 0x935F - 0x8140 = 0x121F
      # high = 0x12, low = 0x1F
      # value = 0x12 * 0xC0 + 0x1F = 18 * 192 + 31 = 3487
      data = <<0x93, 0x5F>>
      bits = Kanji.encode(data)
      assert bits == <<3487::13>>
    end

    test "encodes Shift JIS character in 0xE040-0xEBBF range" do
      # 点 in Shift JIS = 0xE05F (example)
      # 0xE05F - 0xC140 = 0x1F1F
      # high = 0x1F, low = 0x1F
      # value = 0x1F * 0xC0 + 0x1F = 31 * 192 + 31 = 5983
      data = <<0xE0, 0x5F>>
      bits = Kanji.encode(data)
      assert bits == <<5983::13>>
    end

    test "encodes multiple characters" do
      data = <<0x93, 0x5F, 0x93, 0x5F>>
      bits = Kanji.encode(data)
      assert bits == <<3487::13, 3487::13>>
    end
  end

  describe "char_count/1" do
    test "counts double-byte characters" do
      assert Kanji.char_count(<<0x93, 0x5F>>) == 1
      assert Kanji.char_count(<<0x93, 0x5F, 0x93, 0x5F>>) == 2
    end

    test "empty data returns 0" do
      assert Kanji.char_count(<<>>) == 0
    end
  end

  describe "valid?/1" do
    test "valid Shift JIS pair" do
      assert Kanji.valid?(<<0x93, 0x5F>>)
    end

    test "odd byte count is invalid" do
      refute Kanji.valid?(<<0x93>>)
    end

    test "out of range pair is invalid" do
      refute Kanji.valid?(<<0x00, 0x41>>)
    end

    test "empty is valid" do
      assert Kanji.valid?(<<>>)
    end
  end
end
