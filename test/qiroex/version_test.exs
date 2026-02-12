defmodule Qiroex.VersionTest do
  use ExUnit.Case, async: true

  alias Qiroex.Version

  describe "select/3" do
    test "selects version 1 for short data" do
      assert {:ok, 1} = Version.select("HELLO WORLD", :m, :alphanumeric)
    end

    test "selects version 1 for 17 bytes at L" do
      data = String.duplicate("A", 17)
      assert {:ok, 1} = Version.select(data, :l, :byte)
    end

    test "selects version 2 when data overflows version 1" do
      # V1-M byte capacity is 14
      data = String.duplicate("a", 15)
      assert {:ok, 2} = Version.select(data, :m, :byte)
    end

    test "returns error when data too large" do
      # Max V40-L byte capacity is 2953
      data = String.duplicate("x", 3000)
      assert {:error, msg} = Version.select(data, :l, :byte)
      assert msg =~ "too large"
    end

    test "auto mode detection works" do
      assert {:ok, 1} = Version.select("12345", :m)
    end

    test "numeric data allows larger capacity" do
      # 34 numeric chars fit in V1-M (capacity 34)
      data = String.duplicate("1", 34)
      assert {:ok, 1} = Version.select(data, :m, :numeric)
    end

    test "35 numeric chars need V2-M" do
      data = String.duplicate("1", 35)
      assert {:ok, 2} = Version.select(data, :m, :numeric)
    end
  end

  describe "fits?/4" do
    test "short data fits in version 1" do
      assert Version.fits?("test", 1, :m, :byte)
    end

    test "too much data doesn't fit" do
      data = String.duplicate("x", 100)
      refute Version.fits?(data, 1, :m, :byte)
    end
  end

  describe "select!/3" do
    test "returns version on success" do
      assert Version.select!("test", :m) >= 1
    end

    test "raises on failure" do
      data = String.duplicate("x", 5000)
      assert_raise ArgumentError, fn -> Version.select!(data, :h) end
    end
  end
end
