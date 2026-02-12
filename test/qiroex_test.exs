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

  # === SVG API ===

  describe "to_svg/2" do
    test "returns {:ok, svg_string}" do
      assert {:ok, svg} = Qiroex.to_svg("HELLO")
      assert is_binary(svg)
      assert String.contains?(svg, "<svg")
    end

    test "passes render options through" do
      {:ok, svg} = Qiroex.to_svg("HELLO", dark_color: "#ff0000")
      assert String.contains?(svg, "#ff0000")
    end

    test "returns error for invalid input" do
      assert {:error, _} = Qiroex.to_svg("")
    end
  end

  describe "to_svg!/2" do
    test "returns SVG string directly" do
      svg = Qiroex.to_svg!("HELLO")
      assert String.contains?(svg, "<svg")
    end
  end

  # === PNG API ===

  describe "to_png/2" do
    test "returns {:ok, png_binary}" do
      assert {:ok, png} = Qiroex.to_png("HELLO")
      assert is_binary(png)
      assert <<137, 80, 78, 71, _rest::binary>> = png
    end

    test "returns error for invalid input" do
      assert {:error, _} = Qiroex.to_png("")
    end
  end

  describe "to_png!/2" do
    test "returns PNG binary directly" do
      png = Qiroex.to_png!("HELLO")
      assert <<137, 80, 78, 71, _rest::binary>> = png
    end
  end

  describe "save_png/3" do
    test "writes PNG to file" do
      path = Path.join(System.tmp_dir!(), "qiroex_api_test_#{:rand.uniform(100_000)}.png")

      try do
        assert :ok = Qiroex.save_png("HELLO", path)
        assert File.exists?(path)
      after
        File.rm(path)
      end
    end
  end

  describe "save_svg/3" do
    test "writes SVG to file" do
      path = Path.join(System.tmp_dir!(), "qiroex_api_test_#{:rand.uniform(100_000)}.svg")

      try do
        assert :ok = Qiroex.save_svg("HELLO", path)
        content = File.read!(path)
        assert String.contains?(content, "<svg")
      after
        File.rm(path)
      end
    end
  end

  # === Terminal API ===

  describe "to_terminal/2" do
    test "returns {:ok, terminal_string}" do
      assert {:ok, output} = Qiroex.to_terminal("HELLO")
      assert is_binary(output)
      assert String.length(output) > 0
    end

    test "returns error for invalid input" do
      assert {:error, _} = Qiroex.to_terminal("")
    end
  end

  describe "print/2" do
    test "prints to stdout" do
      output = ExUnit.CaptureIO.capture_io(fn ->
        Qiroex.print("HELLO")
      end)

      assert String.length(output) > 0
    end
  end
end
