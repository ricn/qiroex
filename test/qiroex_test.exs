defmodule QiroexTest do
  use ExUnit.Case, async: true

  # ── encode/2 ───────────────────────────────────────────────────────

  describe "encode/2" do
    test "returns {:ok, qr} for valid input" do
      assert {:ok, qr} = Qiroex.encode("HELLO WORLD")
      assert is_map(qr)
    end

    test "returns error for empty string" do
      assert {:error, _} = Qiroex.encode("")
    end

    test "accepts :level option" do
      for lvl <- [:l, :m, :q, :h] do
        assert {:ok, qr} = Qiroex.encode("test", level: lvl)
        assert qr.ec_level == lvl
      end
    end

    test "accepts :ec_level alias" do
      assert {:ok, qr} = Qiroex.encode("test", ec_level: :h)
      assert qr.ec_level == :h
    end

    test "rejects invalid ec level" do
      assert {:error, msg} = Qiroex.encode("test", level: :x)
      assert msg =~ "invalid error correction level"
    end

    test "accepts :version option" do
      assert {:ok, qr} = Qiroex.encode("test", version: 5)
      assert qr.version == 5
    end

    test "rejects out-of-range version" do
      assert {:error, msg} = Qiroex.encode("test", version: 0)
      assert msg =~ "invalid version"

      assert {:error, msg} = Qiroex.encode("test", version: 41)
      assert msg =~ "invalid version"
    end

    test "accepts :mode option" do
      assert {:ok, qr} = Qiroex.encode("12345", mode: :numeric)
      assert qr.mode == :numeric
    end

    test "rejects invalid mode" do
      assert {:error, msg} = Qiroex.encode("test", mode: :utf8)
      assert msg =~ "invalid mode"
    end

    test "accepts :mask option" do
      assert {:ok, qr} = Qiroex.encode("test", mask: 3)
      assert qr.mask == 3
    end

    test "rejects invalid mask" do
      assert {:error, msg} = Qiroex.encode("test", mask: 8)
      assert msg =~ "invalid mask"
    end
  end

  # ── encode!/2 ──────────────────────────────────────────────────────

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

    test "raises for invalid options" do
      assert_raise ArgumentError, ~r/invalid error correction level/, fn ->
        Qiroex.encode!("test", level: :z)
      end
    end
  end

  # ── to_matrix/2 ────────────────────────────────────────────────────

  describe "to_matrix/2" do
    test "returns 2D list of 0s and 1s" do
      {:ok, rows} = Qiroex.to_matrix("HI", level: :l)

      assert is_list(rows)
      assert is_list(hd(rows))

      for row <- rows, val <- row do
        assert val in [0, 1]
      end
    end

    test "respects margin option" do
      {:ok, rows_4} = Qiroex.to_matrix("HI", level: :l, margin: 4)
      {:ok, rows_0} = Qiroex.to_matrix("HI", level: :l, margin: 0)

      # margin adds 2*margin to each dimension
      assert length(rows_4) == length(rows_0) + 8
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

  # ── SVG API ────────────────────────────────────────────────────────

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

    test "rejects invalid render options" do
      assert {:error, msg} = Qiroex.to_svg("test", module_size: -1)
      assert msg =~ "invalid module_size"
    end

    test "rejects invalid style type" do
      assert {:error, msg} = Qiroex.to_svg("test", style: :circle)
      assert msg =~ "invalid style"
    end

    test "accepts style struct" do
      style = Qiroex.Style.new(module_shape: :circle)
      assert {:ok, svg} = Qiroex.to_svg("test", style: style)
      assert String.contains?(svg, "<circle")
    end

    test "accepts logo struct" do
      logo = Qiroex.Logo.new(svg: ~s(<circle cx="5" cy="5" r="4" fill="blue"/>), size: 0.15)
      assert {:ok, svg} = Qiroex.to_svg("test", level: :h, logo: logo)
      assert String.contains?(svg, "blue")
    end
  end

  describe "to_svg!/2" do
    test "returns SVG string directly" do
      svg = Qiroex.to_svg!("HELLO")
      assert String.contains?(svg, "<svg")
    end

    test "raises for invalid options" do
      assert_raise ArgumentError, fn ->
        Qiroex.to_svg!("test", module_size: 0)
      end
    end
  end

  # ── PNG API ────────────────────────────────────────────────────────

  describe "to_png/2" do
    test "returns {:ok, png_binary}" do
      assert {:ok, png} = Qiroex.to_png("HELLO")
      assert is_binary(png)
      assert <<137, 80, 78, 71, _rest::binary>> = png
    end

    test "returns error for invalid input" do
      assert {:error, _} = Qiroex.to_png("")
    end

    test "rejects invalid RGB color" do
      assert {:error, msg} = Qiroex.to_png("test", dark_color: "#000")
      assert msg =~ "invalid dark_color"
    end

    test "accepts valid RGB tuple" do
      assert {:ok, png} = Qiroex.to_png("test", dark_color: {0, 0, 128})
      assert <<137, 80, 78, 71, _rest::binary>> = png
    end
  end

  describe "to_png!/2" do
    test "returns PNG binary directly" do
      png = Qiroex.to_png!("HELLO")
      assert <<137, 80, 78, 71, _rest::binary>> = png
    end
  end

  # ── File Saving ────────────────────────────────────────────────────

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

    test "returns error for invalid data" do
      path = Path.join(System.tmp_dir!(), "qiroex_api_test_#{:rand.uniform(100_000)}.png")
      assert {:error, _} = Qiroex.save_png("", path)
      refute File.exists?(path)
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

    test "returns error for invalid data" do
      path = Path.join(System.tmp_dir!(), "qiroex_api_test_#{:rand.uniform(100_000)}.svg")
      assert {:error, _} = Qiroex.save_svg("", path)
      refute File.exists?(path)
    end
  end

  # ── Terminal API ───────────────────────────────────────────────────

  describe "to_terminal/2" do
    test "returns {:ok, terminal_string}" do
      assert {:ok, output} = Qiroex.to_terminal("HELLO")
      assert is_binary(output)
      assert String.length(output) > 0
    end

    test "returns error for invalid input" do
      assert {:error, _} = Qiroex.to_terminal("")
    end

    test "rejects invalid compact option" do
      assert {:error, msg} = Qiroex.to_terminal("test", compact: "yes")
      assert msg =~ "invalid compact"
    end
  end

  describe "to_terminal!/2" do
    test "returns terminal string directly" do
      str = Qiroex.to_terminal!("HELLO")
      assert is_binary(str)
      assert String.length(str) > 0
    end

    test "raises for empty input" do
      assert_raise ArgumentError, fn ->
        Qiroex.to_terminal!("")
      end
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

  # ── Payload API ────────────────────────────────────────────────────

  describe "payload/4" do
    test "generates WiFi QR in SVG format" do
      assert {:ok, svg} = Qiroex.payload(:wifi, [ssid: "MyNet", password: "s3cr3t"], :svg)
      assert String.contains?(svg, "<svg")
    end

    test "generates URL QR in PNG format" do
      assert {:ok, png} = Qiroex.payload(:url, [url: "https://example.com"], :png)
      assert <<137, 80, 78, 71, _::binary>> = png
    end

    test "generates vCard QR in terminal format" do
      assert {:ok, str} = Qiroex.payload(:vcard, [first_name: "Jane", last_name: "Doe"], :terminal)
      assert is_binary(str)
    end

    test "generates phone QR as encode struct" do
      assert {:ok, qr} = Qiroex.payload(:phone, [number: "+1234567890"], :encode)
      assert qr.version >= 1
    end

    test "generates geo QR as matrix" do
      assert {:ok, rows} = Qiroex.payload(:geo, [latitude: 40.7128, longitude: -74.006], :matrix)
      assert is_list(rows)
    end

    test "returns error for unknown payload type" do
      assert {:error, msg} = Qiroex.payload(:fax, [number: "123"], :svg)
      assert msg =~ "unknown payload type"
      assert msg =~ ":fax"
    end

    test "returns error for invalid format" do
      assert {:error, msg} = Qiroex.payload(:wifi, [ssid: "x", password: "y"], :pdf)
      assert msg =~ "invalid format"
    end

    test "passes render options through" do
      assert {:ok, svg} =
               Qiroex.payload(:url, [url: "https://example.com"], :svg, dark_color: "#336699")

      assert String.contains?(svg, "#336699")
    end
  end

  describe "payload!/4" do
    test "returns result directly" do
      svg = Qiroex.payload!(:url, [url: "https://example.com"], :svg)
      assert String.contains?(svg, "<svg")
    end

    test "raises on error" do
      assert_raise ArgumentError, ~r/unknown payload type/, fn ->
        Qiroex.payload!(:fax, [number: "123"], :svg)
      end
    end
  end

  # ── info/1 ─────────────────────────────────────────────────────────

  describe "info/1" do
    test "returns metadata map for encoded QR" do
      {:ok, qr} = Qiroex.encode("Hello, World!")
      info = Qiroex.info(qr)

      assert info.version >= 1
      assert info.ec_level == :m
      assert info.mode in [:byte, :alphanumeric, :numeric, :kanji]
      assert info.mask in 0..7
      assert info.modules > 0
      assert info.data_bytes == byte_size("Hello, World!")
    end

    test "reflects forced ec level" do
      {:ok, qr} = Qiroex.encode("123", level: :h)
      info = Qiroex.info(qr)
      assert info.ec_level == :h
    end

    test "reflects forced version" do
      {:ok, qr} = Qiroex.encode("test", version: 10)
      info = Qiroex.info(qr)
      assert info.version == 10
      assert info.modules == 57  # version 10 = 4*10+17 = 57
    end
  end

  # ── Edge Cases ─────────────────────────────────────────────────────

  describe "edge cases" do
    test "encodes single character" do
      assert {:ok, _} = Qiroex.encode("A")
    end

    test "encodes numeric data" do
      assert {:ok, qr} = Qiroex.encode("1234567890")
      assert qr.mode == :numeric
    end

    test "encodes alphanumeric data" do
      assert {:ok, qr} = Qiroex.encode("HELLO 123")
      assert qr.mode == :alphanumeric
    end

    test "encodes byte data (UTF-8)" do
      assert {:ok, qr} = Qiroex.encode("Hello, 世界!")
      # Mixed content with non-ASCII uses byte or auto-detected segments
      assert qr.version >= 1
    end

    test "encodes data that requires higher version" do
      # 200 chars of data should need more than version 1
      data = String.duplicate("A", 200)
      assert {:ok, qr} = Qiroex.encode(data, level: :l)
      assert qr.version > 1
    end

    test "handles maximum version 40 data" do
      # Version 40-L numeric can hold 7089 digits
      data = String.duplicate("0", 2000)
      assert {:ok, qr} = Qiroex.encode(data, level: :l)
      assert qr.version > 10
    end

    test "returns error when data exceeds capacity" do
      # Too much data even for version 40-L byte mode (max 2953 bytes)
      data = String.duplicate("x", 3000)
      assert {:error, _} = Qiroex.encode(data, level: :l)
    end

    test "deterministic output with forced mask" do
      {:ok, svg1} = Qiroex.to_svg("test", mask: 0)
      {:ok, svg2} = Qiroex.to_svg("test", mask: 0)
      assert svg1 == svg2
    end

    test "different masks produce different output" do
      {:ok, svg0} = Qiroex.to_svg("test", mask: 0)
      {:ok, svg3} = Qiroex.to_svg("test", mask: 3)
      assert svg0 != svg3
    end
  end

  # ── Logo Coverage Validation ───────────────────────────────────────

  describe "logo coverage validation" do
    test "rejects oversized logo with low EC" do
      logo = Qiroex.Logo.new(svg: "<svg/>", size: 0.4)
      assert {:error, msg} = Qiroex.to_svg("test", level: :l, logo: logo)
      assert msg =~ "covers"
      assert msg =~ "higher EC level"
    end

    test "accepts reasonably sized logo with high EC" do
      logo = Qiroex.Logo.new(svg: "<svg/>", size: 0.15)
      assert {:ok, svg} = Qiroex.to_svg("test", level: :h, logo: logo)
      assert String.contains?(svg, "<svg")
    end
  end
end
