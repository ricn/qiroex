defmodule Qiroex.Payload.SMSTest do
  use ExUnit.Case, async: true

  alias Qiroex.Payload.SMS

  describe "encode/1" do
    test "number only" do
      assert {:ok, "smsto:+1234567890"} = SMS.encode(number: "+1234567890")
    end

    test "with message" do
      {:ok, payload} = SMS.encode(number: "+1234567890", message: "Hello!")
      assert payload == "smsto:+1234567890:Hello!"
    end

    test "empty message treated as no message" do
      {:ok, payload} = SMS.encode(number: "+1234567890", message: "")
      assert payload == "smsto:+1234567890"
    end

    test "error when number is missing" do
      assert {:error, "Phone number is required"} = SMS.encode([])
    end

    test "error when number is empty" do
      assert {:error, "Phone number cannot be empty"} = SMS.encode(number: "")
    end
  end
end
