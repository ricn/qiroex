defmodule Qiroex.Encoder.ByteTest do
  use ExUnit.Case, async: true

  alias Qiroex.Encoder.Byte

  describe "encode/1" do
    test "encodes ASCII string as-is" do
      data = "Hello"
      assert Byte.encode(data) == data
    end

    test "encodes UTF-8 bytes" do
      data = "é"  # 2 bytes in UTF-8
      assert Byte.encode(data) == data
      assert byte_size(Byte.encode(data)) == 2
    end

    test "encodes binary data" do
      data = <<0, 1, 255>>
      assert Byte.encode(data) == data
    end
  end

  describe "valid?/1" do
    test "any binary is valid" do
      assert Byte.valid?("anything")
      assert Byte.valid?(<<0, 255>>)
      assert Byte.valid?("")
    end
  end
end
