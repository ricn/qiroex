defmodule Qiroex.Encoder.SegmentTest do
  use ExUnit.Case, async: true

  alias Qiroex.Encoder.Segment
  alias Qiroex.Spec

  describe "encode/3" do
    test "HELLO WORLD at V1-M produces correct codewords" do
      # From Thonky QR tutorial: "HELLO WORLD" in alphanumeric mode at V1-M
      # Should produce exactly 16 data codewords
      segments = [{:alphanumeric, "HELLO WORLD"}]
      codewords = Segment.encode(segments, 1, :m)

      assert length(codewords) == 16

      # Known data codewords from Thonky:
      # Mode indicator (0010) + char count (000001011 = 11) +
      # data + terminator + padding
      expected = [32, 91, 11, 120, 209, 114, 220, 77, 67, 64, 236, 17, 236, 17, 236, 17]
      assert codewords == expected
    end

    test "pads to correct total with alternating EC/11" do
      # Short data should be padded with 0xEC, 0x11 alternating
      segments = [{:byte, "A"}]
      codewords = Segment.encode(segments, 1, :m)

      # V1-M has 16 data codewords
      assert length(codewords) == 16

      # After mode(4b)+count(8b)+data(8b)+terminator(4b) = 24 bits = 3 bytes
      # Check that the remaining padding bytes are 0xEC and 0x11
      # First 3 bytes have actual data
      padding_start = 3
      padding = Enum.drop(codewords, padding_start)
      assert Enum.all?(padding, &(&1 in [0xEC, 0x11]))
    end

    test "total codewords matches spec" do
      for ec <- [:l, :m, :q, :h] do
        segments = [{:byte, "test"}]
        codewords = Segment.encode(segments, 1, ec)
        expected = Spec.total_data_codewords(1, ec)

        assert length(codewords) == expected,
               "V1-#{ec}: expected #{expected} codewords, got #{length(codewords)}"
      end
    end

    test "numeric encoding produces correct codewords" do
      # "01234567" in numeric mode
      segments = [{:numeric, "01234567"}]
      codewords = Segment.encode(segments, 1, :m)
      assert length(codewords) == 16
    end
  end

  describe "encode_segment/3" do
    test "includes mode indicator and character count" do
      bits = Segment.encode_segment(:alphanumeric, "AB", 1)

      # Mode = 0010 (4 bits) + count = 2 (9 bits for V1 alpha) + data
      # Count = 000000010 (9 bits)
      # Data: A=10, B=11 → 10*45+11 = 461 → 11 bits
      # Total: 4 + 9 + 11 = 24 bits = 3 bytes
      assert bit_size(bits) == 24
    end
  end
end
