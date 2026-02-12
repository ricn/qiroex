defmodule Qiroex.Encoder.ModeTest do
  use ExUnit.Case, async: true

  alias Qiroex.Encoder.Mode

  describe "detect/1" do
    test "all digits → numeric" do
      assert Mode.detect("12345") == :numeric
      assert Mode.detect("0") == :numeric
    end

    test "uppercase with digits → alphanumeric" do
      assert Mode.detect("HELLO") == :alphanumeric
      assert Mode.detect("ABC123") == :alphanumeric
    end

    test "lowercase → byte" do
      assert Mode.detect("hello") == :byte
      assert Mode.detect("Hello") == :byte
    end

    test "special alphanumeric chars → alphanumeric" do
      assert Mode.detect("A B") == :alphanumeric
      assert Mode.detect("$100") == :alphanumeric
    end

    test "non-alphanumeric special chars → byte" do
      assert Mode.detect("hello@world") == :byte
      assert Mode.detect("test!") == :byte
    end
  end

  describe "segment/2" do
    test "pure numeric returns single numeric segment" do
      segments = Mode.segment("12345", 1)
      assert [{:numeric, "12345"}] = segments
    end

    test "pure alphanumeric returns single alphanumeric segment" do
      segments = Mode.segment("HELLO", 1)
      assert [{:alphanumeric, "HELLO"}] = segments
    end

    test "pure byte returns single byte segment" do
      segments = Mode.segment("hello", 1)
      assert [{:byte, "hello"}] = segments
    end

    test "empty data returns byte segment" do
      segments = Mode.segment("", 1)
      assert [{:byte, ""}] = segments
    end

    test "mixed content produces multiple or merged segments" do
      # The optimizer may merge short segments
      segments = Mode.segment("ABC123def", 1)
      # Should have at least some segments
      assert length(segments) >= 1
      # All data is covered
      reassembled = segments |> Enum.map(&elem(&1, 1)) |> Enum.join()
      assert reassembled == "ABC123def"
    end

    test "all segment data concatenates to original" do
      input = "HELLO123world456"
      segments = Mode.segment(input, 5)
      reassembled = segments |> Enum.map(&elem(&1, 1)) |> Enum.join()
      assert reassembled == input
    end
  end
end
