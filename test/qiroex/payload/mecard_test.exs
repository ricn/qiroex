defmodule Qiroex.Payload.MeCardTest do
  use ExUnit.Case, async: true

  alias Qiroex.Payload.MeCard

  describe "encode/1" do
    test "basic MeCard with name" do
      {:ok, payload} = MeCard.encode(name: "Doe,John")
      assert payload == "MECARD:N:Doe\\,John;;"
    end

    test "with phone and email" do
      {:ok, payload} = MeCard.encode(
        name: "Doe,John",
        phone: "+1234567890",
        email: "john@example.com"
      )
      assert String.contains?(payload, "TEL:+1234567890")
      assert String.contains?(payload, "EMAIL:john@example.com")
      assert String.ends_with?(payload, ";;")
    end

    test "with URL and address" do
      {:ok, payload} = MeCard.encode(
        name: "Doe,John",
        url: "https://john.dev",
        address: "123 Main St"
      )
      assert String.contains?(payload, "URL:https\\://john.dev")
      assert String.contains?(payload, "ADR:123 Main St")
    end

    test "with note, birthday, and org" do
      {:ok, payload} = MeCard.encode(
        name: "Jane",
        note: "Friend",
        birthday: "19900101",
        org: "Acme"
      )
      assert String.contains?(payload, "NOTE:Friend")
      assert String.contains?(payload, "BDAY:19900101")
      assert String.contains?(payload, "ORG:Acme")
    end

    test "escapes special characters" do
      {:ok, payload} = MeCard.encode(name: "O;Brien")
      assert String.contains?(payload, "N:O\\;Brien")
    end

    test "error when name is missing" do
      assert {:error, "Name is required"} = MeCard.encode([])
    end

    test "error when name is empty" do
      assert {:error, "Name cannot be empty"} = MeCard.encode(name: "")
    end
  end
end
