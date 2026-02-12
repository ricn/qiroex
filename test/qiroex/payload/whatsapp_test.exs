defmodule Qiroex.Payload.WhatsAppTest do
  use ExUnit.Case, async: true

  alias Qiroex.Payload.WhatsApp

  describe "encode/1" do
    test "number only" do
      {:ok, payload} = WhatsApp.encode(number: "1234567890")
      assert payload == "https://wa.me/1234567890"
    end

    test "strips + from number" do
      {:ok, payload} = WhatsApp.encode(number: "+1234567890")
      assert payload == "https://wa.me/1234567890"
    end

    test "strips dashes and spaces" do
      {:ok, payload} = WhatsApp.encode(number: "+1-234-567-890")
      assert payload == "https://wa.me/1234567890"
    end

    test "with message" do
      {:ok, payload} = WhatsApp.encode(number: "1234567890", message: "Hello!")
      assert payload == "https://wa.me/1234567890?text=Hello!"
    end

    test "message with spaces encoded" do
      {:ok, payload} = WhatsApp.encode(number: "1234567890", message: "Hi there")
      assert String.contains?(payload, "text=Hi%20there")
    end

    test "empty message treated as no message" do
      {:ok, payload} = WhatsApp.encode(number: "123", message: "")
      assert payload == "https://wa.me/123"
    end

    test "error when number is missing" do
      assert {:error, "Phone number is required"} = WhatsApp.encode([])
    end

    test "error when number is empty" do
      assert {:error, "Phone number cannot be empty"} = WhatsApp.encode(number: "")
    end
  end
end
