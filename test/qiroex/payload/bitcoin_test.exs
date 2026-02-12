defmodule Qiroex.Payload.BitcoinTest do
  use ExUnit.Case, async: true

  alias Qiroex.Payload.Bitcoin

  describe "encode/1" do
    test "address only" do
      {:ok, payload} = Bitcoin.encode(address: "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa")
      assert payload == "bitcoin:1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa"
    end

    test "with amount" do
      {:ok, payload} = Bitcoin.encode(address: "1abc", amount: 0.001)
      assert String.contains?(payload, "amount=0.001")
    end

    test "with integer amount" do
      {:ok, payload} = Bitcoin.encode(address: "1abc", amount: 1)
      assert String.contains?(payload, "amount=1")
    end

    test "with label and message" do
      {:ok, payload} = Bitcoin.encode(
        address: "1abc",
        label: "Donation",
        message: "Thank you!"
      )
      assert String.contains?(payload, "label=Donation")
      assert String.contains?(payload, "message=Thank%20you!")
    end

    test "amount trailing zeros trimmed" do
      {:ok, payload} = Bitcoin.encode(address: "1abc", amount: 1.5)
      assert String.contains?(payload, "amount=1.5")
    end

    test "error when address is missing" do
      assert {:error, "Bitcoin address is required"} = Bitcoin.encode([])
    end

    test "error when address is empty" do
      assert {:error, "Bitcoin address cannot be empty"} = Bitcoin.encode(address: "")
    end
  end
end
