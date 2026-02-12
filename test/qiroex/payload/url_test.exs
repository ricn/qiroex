defmodule Qiroex.Payload.URLTest do
  use ExUnit.Case, async: true

  alias Qiroex.Payload.URL

  describe "encode/1" do
    test "passes through URL with scheme" do
      assert {:ok, "https://example.com"} = URL.encode(url: "https://example.com")
    end

    test "passes through http scheme" do
      assert {:ok, "http://example.com"} = URL.encode(url: "http://example.com")
    end

    test "prepends https:// when no scheme" do
      assert {:ok, "https://example.com"} = URL.encode(url: "example.com")
    end

    test "preserves path and query" do
      assert {:ok, "https://example.com/path?q=1"} = URL.encode(url: "https://example.com/path?q=1")
    end

    test "error when URL is missing" do
      assert {:error, "URL is required"} = URL.encode([])
    end

    test "error when URL is empty" do
      assert {:error, "URL cannot be empty"} = URL.encode(url: "")
    end
  end
end
