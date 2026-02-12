defmodule Qiroex.Payload.EmailTest do
  use ExUnit.Case, async: true

  alias Qiroex.Payload.Email

  describe "encode/1" do
    test "simple email address" do
      assert {:ok, "mailto:user@example.com"} = Email.encode(to: "user@example.com")
    end

    test "with subject" do
      {:ok, payload} = Email.encode(to: "user@example.com", subject: "Hello")
      assert payload == "mailto:user@example.com?subject=Hello"
    end

    test "with subject and body" do
      {:ok, payload} = Email.encode(to: "a@b.com", subject: "Hi", body: "How are you?")
      assert String.starts_with?(payload, "mailto:a@b.com?")
      assert String.contains?(payload, "subject=Hi")
      assert String.contains?(payload, "body=How+are+you%3F")
    end

    test "with cc and bcc" do
      {:ok, payload} = Email.encode(to: "a@b.com", cc: "c@d.com", bcc: "e@f.com")
      assert String.contains?(payload, "cc=c%40d.com")
      assert String.contains?(payload, "bcc=e%40f.com")
    end

    test "error when email is missing" do
      assert {:error, "Email address is required"} = Email.encode([])
    end

    test "error when email is empty" do
      assert {:error, "Email address cannot be empty"} = Email.encode(to: "")
    end

    test "error when email has no @" do
      assert {:error, _} = Email.encode(to: "notanemail")
    end
  end
end
