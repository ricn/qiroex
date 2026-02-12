defmodule QiroexTest do
  use ExUnit.Case, async: true

  describe "encode/2" do
    test "returns {:ok, qr} for valid input" do
      assert {:ok, qr} = Qiroex.encode("HELLO WORLD")
      assert is_map(qr)
    end

    test "returns error for empty string" do
      assert {:error, _} = Qiroex.encode("")
    end
  end

  describe "encode!/2" do
    test "returns qr struct for valid input" do
      qr = Qiroex.encode!("HELLO WORLD")
      assert is_map(qr)
    end

    test "raises for empty string" do
      assert_raise ArgumentError, fn ->
        Qiroex.encode!("")
      end
    end
  end

  describe "to_matrix/2" do
    test "returns 2D list of 0s and 1s" do
      {:ok, rows} = Qiroex.to_matrix("HI", level: :l)

      assert is_list(rows)
      assert is_list(hd(rows))

      for row <- rows, val <- row do
        assert val in [0, 1]
      end
    end
  end

  describe "to_matrix!/2" do
    test "encodes and returns matrix directly" do
      rows = Qiroex.to_matrix!("TEST", level: :m)

      assert is_list(rows)
      assert is_list(hd(rows))
    end

    test "raises for empty input" do
      assert_raise ArgumentError, fn ->
        Qiroex.to_matrix!("")
      end
    end
  end
end
