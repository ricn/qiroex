defmodule Qiroex.Payload.VCardTest do
  use ExUnit.Case, async: true

  alias Qiroex.Payload.VCard

  describe "encode/1" do
    test "basic vCard with name" do
      {:ok, payload} = VCard.encode(first_name: "John", last_name: "Doe")
      assert String.contains?(payload, "BEGIN:VCARD")
      assert String.contains?(payload, "VERSION:3.0")
      assert String.contains?(payload, "N:Doe;John;;;")
      assert String.contains?(payload, "FN:John Doe")
      assert String.contains?(payload, "END:VCARD")
    end

    test "first name only" do
      {:ok, payload} = VCard.encode(first_name: "John")
      assert String.contains?(payload, "N:;John;;;")
      assert String.contains?(payload, "FN:John")
    end

    test "last name only" do
      {:ok, payload} = VCard.encode(last_name: "Doe")
      assert String.contains?(payload, "N:Doe;;;;")
      assert String.contains?(payload, "FN:Doe")
    end

    test "with phone and email" do
      {:ok, payload} = VCard.encode(
        first_name: "Jane",
        last_name: "Doe",
        phone: "+1234567890",
        email: "jane@example.com"
      )
      assert String.contains?(payload, "TEL;TYPE=CELL:+1234567890")
      assert String.contains?(payload, "EMAIL:jane@example.com")
    end

    test "with work phone and work email" do
      {:ok, payload} = VCard.encode(
        first_name: "Jane",
        work_phone: "+9876543210",
        work_email: "jane@work.com"
      )
      assert String.contains?(payload, "TEL;TYPE=WORK:+9876543210")
      assert String.contains?(payload, "EMAIL;TYPE=WORK:jane@work.com")
    end

    test "with organization and title" do
      {:ok, payload} = VCard.encode(
        first_name: "Jane",
        org: "Acme Corp",
        title: "Engineer"
      )
      assert String.contains?(payload, "ORG:Acme Corp")
      assert String.contains?(payload, "TITLE:Engineer")
    end

    test "with address" do
      {:ok, payload} = VCard.encode(
        first_name: "Jane",
        street: "123 Main St",
        city: "Springfield",
        state: "IL",
        zip: "62701",
        country: "US"
      )
      assert String.contains?(payload, "ADR;TYPE=HOME:;;123 Main St;Springfield;IL;62701;US")
    end

    test "with URL and note" do
      {:ok, payload} = VCard.encode(
        first_name: "Jane",
        url: "https://jane.dev",
        note: "Met at conference"
      )
      assert String.contains?(payload, "URL:https://jane.dev")
      assert String.contains?(payload, "NOTE:Met at conference")
    end

    test "uses CRLF line endings" do
      {:ok, payload} = VCard.encode(first_name: "John")
      assert String.contains?(payload, "\r\n")
    end

    test "error when both names are empty" do
      assert {:error, _} = VCard.encode([])
    end
  end
end
