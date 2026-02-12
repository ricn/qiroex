defmodule Qiroex.Render.PNGTest do
  use ExUnit.Case, async: true

  alias Qiroex.Render.PNG
  alias Qiroex.QR

  @png_signature <<137, 80, 78, 71, 13, 10, 26, 10>>

  setup do
    {:ok, qr} = QR.encode("HELLO", level: :m)
    %{qr: qr, matrix: qr.matrix}
  end

  describe "render/2" do
    test "returns valid PNG binary", %{matrix: matrix} do
      png = PNG.render(matrix)

      assert is_binary(png)
      assert byte_size(png) > 8
    end

    test "starts with PNG signature", %{matrix: matrix} do
      png = PNG.render(matrix)

      assert <<@png_signature, _rest::binary>> = png
    end

    test "contains IHDR chunk", %{matrix: matrix} do
      png = PNG.render(matrix)

      # IHDR comes right after the 8-byte signature
      <<@png_signature, _length::32, "IHDR", _rest::binary>> = png
    end

    test "IHDR has correct dimensions", %{matrix: matrix} do
      png = PNG.render(matrix)

      # Default: V1(21) + 2*4 quiet zone = 29, × 10 = 290 pixels
      expected_px = (matrix.size + 8) * 10

      <<@png_signature, 13::32, "IHDR", width::32, height::32, _rest::binary>> = png

      assert width == expected_px
      assert height == expected_px
    end

    test "custom module size affects dimensions", %{matrix: matrix} do
      png = PNG.render(matrix, module_size: 5)

      expected_px = (matrix.size + 8) * 5

      <<@png_signature, 13::32, "IHDR", width::32, height::32, _rest::binary>> = png

      assert width == expected_px
      assert height == expected_px
    end

    test "custom quiet zone affects dimensions", %{matrix: matrix} do
      png = PNG.render(matrix, quiet_zone: 2)

      expected_px = (matrix.size + 4) * 10

      <<@png_signature, 13::32, "IHDR", width::32, height::32, _rest::binary>> = png

      assert width == expected_px
      assert height == expected_px
    end

    test "contains PLTE chunk", %{matrix: matrix} do
      png = PNG.render(matrix)
      assert String.contains?(png, "PLTE")
    end

    test "contains IDAT chunk", %{matrix: matrix} do
      png = PNG.render(matrix)
      assert String.contains?(png, "IDAT")
    end

    test "ends with IEND chunk", %{matrix: matrix} do
      png = PNG.render(matrix)

      # IEND is the last chunk: length(0) + "IEND" + CRC
      assert String.contains?(png, "IEND")
      # Last 12 bytes: 00 00 00 00 IEND <crc32>
      <<_prefix::binary-size(byte_size(png) - 12), 0::32, "IEND", _crc::32>> = png
    end

    test "PLTE contains correct default colors", %{matrix: matrix} do
      png = PNG.render(matrix)

      # Find PLTE chunk: 6 bytes of palette data (2 colors × 3 bytes RGB)
      plte_idx = :binary.match(png, "PLTE")
      assert plte_idx != :nomatch

      {offset, _} = plte_idx
      # 4 bytes before "PLTE" is the length
      <<_before::binary-size(offset - 4), 6::32, "PLTE", lr::8, lg::8, lb::8, dr::8, dg::8, db::8,
        _rest::binary>> = png

      # Default: light = white, dark = black
      assert {lr, lg, lb} == {255, 255, 255}
      assert {dr, dg, db} == {0, 0, 0}
    end

    test "custom colors in palette", %{matrix: matrix} do
      png = PNG.render(matrix, dark_color: {255, 0, 0}, light_color: {0, 255, 0})

      {offset, _} = :binary.match(png, "PLTE")

      <<_before::binary-size(offset - 4), 6::32, "PLTE", lr::8, lg::8, lb::8, dr::8, dg::8, db::8,
        _rest::binary>> = png

      assert {lr, lg, lb} == {0, 255, 0}
      assert {dr, dg, db} == {255, 0, 0}
    end

    test "different inputs produce different PNGs" do
      {:ok, qr1} = QR.encode("HELLO", level: :m)
      {:ok, qr2} = QR.encode("WORLD", level: :m)

      png1 = PNG.render(qr1.matrix)
      png2 = PNG.render(qr2.matrix)

      refute png1 == png2
    end

    test "uses indexed color type (3)", %{matrix: matrix} do
      png = PNG.render(matrix)

      <<@png_signature, 13::32, "IHDR", _w::32, _h::32, bit_depth::8, color_type::8,
        _rest::binary>> = png

      assert bit_depth == 8
      # indexed color
      assert color_type == 3
    end
  end

  describe "save/3" do
    test "writes PNG to file", %{matrix: matrix} do
      path = Path.join(System.tmp_dir!(), "qiroex_test_#{:rand.uniform(100_000)}.png")

      try do
        assert :ok = PNG.save(matrix, path)
        assert File.exists?(path)

        content = File.read!(path)
        assert <<@png_signature, _rest::binary>> = content
      after
        File.rm(path)
      end
    end
  end
end
