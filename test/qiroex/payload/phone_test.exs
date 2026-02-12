defmodule Qiroex.Payload.PhoneTest do
  use ExUnit.Case, async: true

  alias Qiroex.Payload.Phone

  describe "encode/1" do
    test "formats phone number" do
      assert {:ok, "tel:+1234567890"} = Phone.encode(number: "+1234567890")
    end

    test "local number" do
      assert {:ok, "tel:555-1234"} = Phone.encode(number: "555-1234")
    end

    test "error when number is missing" do
      assert {:error, "Phone number is required"} = Phone.encode([])
    end

    test "error when number is empty" do
      assert {:error, "Phone number cannot be empty"} = Phone.encode(number: "")
    end
  end
end
