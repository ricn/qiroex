defmodule Qiroex.PayloadTest do
  use ExUnit.Case, async: true

  alias Qiroex.Payload

  describe "escape/1" do
    test "escapes backslash" do
      assert Payload.escape("a\\b") == "a\\\\b"
    end

    test "escapes semicolons" do
      assert Payload.escape("a;b") == "a\\;b"
    end

    test "escapes commas" do
      assert Payload.escape("a,b") == "a\\,b"
    end

    test "escapes colons" do
      assert Payload.escape("a:b") == "a\\:b"
    end

    test "escapes multiple special chars" do
      assert Payload.escape("a;b:c,d\\e") == "a\\;b\\:c\\,d\\\\e"
    end

    test "no-op for plain strings" do
      assert Payload.escape("hello") == "hello"
    end
  end
end
