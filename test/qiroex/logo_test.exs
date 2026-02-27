defmodule Qiroex.LogoTest do
  use ExUnit.Case, async: true

  alias Qiroex.Logo

  @sample_svg ~s(<svg viewBox="0 0 100 100"><circle cx="50" cy="50" r="40" fill="blue"/></svg>)

  # Minimal valid PNG: 1x1 pixel, red
  @sample_png <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
                0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x02,
                0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44,
                0x41, 0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00, 0x00, 0x00, 0x02, 0x00,
                0x01, 0xE2, 0x21, 0xBC, 0x33, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44,
                0xAE, 0x42, 0x60, 0x82>>

  # JPEG magic bytes + minimal header
  @sample_jpeg <<0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46>>

  describe "new/1 — SVG logos" do
    test "creates logo with defaults" do
      logo = Logo.new(svg: @sample_svg)
      assert logo.svg == @sample_svg
      assert logo.size == 0.2
      assert logo.padding == 1
      assert logo.background == "#ffffff"
      assert logo.shape == :square
      assert logo.border_radius == 4
    end

    test "accepts custom size" do
      logo = Logo.new(svg: @sample_svg, size: 0.3)
      assert logo.size == 0.3
    end

    test "accepts custom padding" do
      logo = Logo.new(svg: @sample_svg, padding: 2)
      assert logo.padding == 2
    end

    test "accepts custom background" do
      logo = Logo.new(svg: @sample_svg, background: "#f0f0f0")
      assert logo.background == "#f0f0f0"
    end

    test "accepts rounded shape" do
      logo = Logo.new(svg: @sample_svg, shape: :rounded, border_radius: 8)
      assert logo.shape == :rounded
      assert logo.border_radius == 8
    end

    test "accepts circle shape" do
      logo = Logo.new(svg: @sample_svg, shape: :circle)
      assert logo.shape == :circle
    end

    test "rejects missing SVG" do
      assert_raise ArgumentError, ~r/requires either :svg/, fn ->
        Logo.new([])
      end
    end

    test "rejects empty SVG" do
      assert_raise ArgumentError, ~r/SVG markup cannot be empty/, fn ->
        Logo.new(svg: "")
      end
    end

    test "rejects size > 0.4" do
      assert_raise ArgumentError, ~r/Logo size/, fn ->
        Logo.new(svg: @sample_svg, size: 0.5)
      end
    end

    test "rejects size <= 0" do
      assert_raise ArgumentError, ~r/Logo size/, fn ->
        Logo.new(svg: @sample_svg, size: 0)
      end
    end

    test "rejects negative padding" do
      assert_raise ArgumentError, ~r/padding/, fn ->
        Logo.new(svg: @sample_svg, padding: -1)
      end
    end

    test "rejects invalid shape" do
      assert_raise ArgumentError, ~r/Logo shape/, fn ->
        Logo.new(svg: @sample_svg, shape: :triangle)
      end
    end
  end

  describe "new/1 — raster image logos" do
    test "creates logo from PNG binary with explicit type" do
      logo = Logo.new(image: @sample_png, image_type: :png)
      assert logo.image == @sample_png
      assert logo.image_type == :png
      assert is_nil(logo.svg)
    end

    test "creates logo from JPEG binary with explicit type" do
      logo = Logo.new(image: @sample_jpeg, image_type: :jpeg)
      assert logo.image == @sample_jpeg
      assert logo.image_type == :jpeg
    end

    test "auto-detects PNG from magic bytes" do
      logo = Logo.new(image: @sample_png)
      assert logo.image_type == :png
    end

    test "auto-detects JPEG from magic bytes" do
      logo = Logo.new(image: @sample_jpeg)
      assert logo.image_type == :jpeg
    end

    test "auto-detects GIF from magic bytes" do
      gif = "GIF89a" <> <<0x01, 0x00, 0x01, 0x00>>
      logo = Logo.new(image: gif)
      assert logo.image_type == :gif
    end

    test "auto-detects BMP from magic bytes" do
      bmp = "BM" <> <<0x00, 0x00, 0x00, 0x00>>
      logo = Logo.new(image: bmp)
      assert logo.image_type == :bmp
    end

    test "auto-detects AVIF from magic bytes" do
      avif = <<0x00, 0x00, 0x00, 0x1C, "ftypavif", 0x00, 0x00, 0x00, 0x00>>
      logo = Logo.new(image: avif)
      assert logo.image_type == :avif
    end

    test "auto-detects TIFF (little-endian) from magic bytes" do
      tiff = <<0x49, 0x49, 0x2A, 0x00, 0x08, 0x00, 0x00, 0x00>>
      logo = Logo.new(image: tiff)
      assert logo.image_type == :tiff
    end

    test "auto-detects TIFF (big-endian) from magic bytes" do
      tiff = <<0x4D, 0x4D, 0x00, 0x2A, 0x00, 0x00, 0x00, 0x08>>
      logo = Logo.new(image: tiff)
      assert logo.image_type == :tiff
    end

    test "accepts custom size and shape for raster logo" do
      logo = Logo.new(image: @sample_png, image_type: :png, size: 0.3, shape: :circle)
      assert logo.size == 0.3
      assert logo.shape == :circle
    end

    test "rejects providing both svg and image" do
      assert_raise ArgumentError, ~r/either :svg or :image, not both/, fn ->
        Logo.new(svg: @sample_svg, image: @sample_png, image_type: :png)
      end
    end

    test "rejects empty image binary" do
      assert_raise ArgumentError, ~r/image data cannot be empty/, fn ->
        Logo.new(image: <<>>, image_type: :png)
      end
    end

    test "rejects unrecognized image format without explicit type" do
      assert_raise ArgumentError, ~r/image_type must be one of/, fn ->
        Logo.new(image: <<0x00, 0x00, 0x00, 0x00>>)
      end
    end

    test "rejects invalid image_type atom" do
      assert_raise ArgumentError, ~r/image_type must be one of/, fn ->
        Logo.new(image: @sample_png, image_type: :ico)
      end
    end
  end

  describe "detect_image_type/1" do
    test "detects PNG" do
      assert Logo.detect_image_type(@sample_png) == :png
    end

    test "detects JPEG" do
      assert Logo.detect_image_type(@sample_jpeg) == :jpeg
    end

    test "detects WEBP" do
      webp = <<"RIFF", 100::32, "WEBP", 0x00>>
      assert Logo.detect_image_type(webp) == :webp
    end

    test "detects GIF87a" do
      assert Logo.detect_image_type(<<"GIF87a", 0x00>>) == :gif
    end

    test "detects GIF89a" do
      assert Logo.detect_image_type(<<"GIF89a", 0x00>>) == :gif
    end

    test "detects BMP" do
      assert Logo.detect_image_type(<<"BM", 0x00, 0x00>>) == :bmp
    end

    test "detects AVIF (avif brand)" do
      assert Logo.detect_image_type(<<0x00, 0x00, 0x00, 0x1C, "ftypavif", 0x00>>) == :avif
    end

    test "detects AVIF (avis brand)" do
      assert Logo.detect_image_type(<<0x00, 0x00, 0x00, 0x1C, "ftypavis", 0x00>>) == :avif
    end

    test "detects TIFF (little-endian)" do
      assert Logo.detect_image_type(<<0x49, 0x49, 0x2A, 0x00, 0x08>>) == :tiff
    end

    test "detects TIFF (big-endian)" do
      assert Logo.detect_image_type(<<0x4D, 0x4D, 0x00, 0x2A, 0x08>>) == :tiff
    end

    test "returns nil for unknown format" do
      assert Logo.detect_image_type(<<0x00, 0x00, 0x00>>) == nil
    end
  end

  describe "geometry/4" do
    test "logo is centered in the QR code" do
      logo = Logo.new(svg: @sample_svg, size: 0.2, padding: 0)
      # V1: size=21, mod=10, qz=4 → total=29 modules → 290px
      geo = Logo.geometry(logo, 21, 10, 4)

      # Logo = 20% of 290 = 58px
      assert geo.logo_px == 58
      # Centered: (290 - 58) / 2 = 116
      assert geo.logo_x == 116
      assert geo.logo_y == 116
    end

    test "padding increases cleared area" do
      logo_no_pad = Logo.new(svg: @sample_svg, size: 0.2, padding: 0)
      logo_pad = Logo.new(svg: @sample_svg, size: 0.2, padding: 2)

      geo_no = Logo.geometry(logo_no_pad, 21, 10, 4)
      geo_pad = Logo.geometry(logo_pad, 21, 10, 4)

      assert geo_pad.clear_px > geo_no.clear_px
      assert geo_pad.clear_modules > geo_no.clear_modules
    end

    test "clear region covers expected modules" do
      logo = Logo.new(svg: @sample_svg, size: 0.2, padding: 1)
      geo = Logo.geometry(logo, 21, 10, 4)

      assert geo.clear_start_row >= 0
      assert geo.clear_start_col >= 0
      assert geo.clear_end_row < 21
      assert geo.clear_end_col < 21
      assert geo.clear_modules > 0
    end

    test "larger logo covers more modules" do
      small = Logo.new(svg: @sample_svg, size: 0.15, padding: 0)
      large = Logo.new(svg: @sample_svg, size: 0.35, padding: 0)

      geo_s = Logo.geometry(small, 25, 10, 4)
      geo_l = Logo.geometry(large, 25, 10, 4)

      assert geo_l.clear_modules > geo_s.clear_modules
    end
  end

  describe "validate_coverage/4" do
    test "small logo with high EC passes" do
      logo = Logo.new(svg: @sample_svg, size: 0.15, padding: 0)
      assert :ok = Logo.validate_coverage(logo, 25, 10, :h)
    end

    test "large logo with low EC fails" do
      logo = Logo.new(svg: @sample_svg, size: 0.4, padding: 1)
      assert {:error, msg} = Logo.validate_coverage(logo, 21, 10, :l)
      assert String.contains?(msg, "Logo covers")
      assert String.contains?(msg, ":l")
    end

    test "moderate logo with level Q passes" do
      logo = Logo.new(svg: @sample_svg, size: 0.2, padding: 1)
      assert :ok = Logo.validate_coverage(logo, 25, 10, :q)
    end
  end

  describe "cleared_positions/4" do
    test "returns MapSet of positions" do
      logo = Logo.new(svg: @sample_svg, size: 0.2, padding: 1)
      positions = Logo.cleared_positions(logo, 21, 10, 4)

      assert is_struct(positions, MapSet)
      assert MapSet.size(positions) > 0
    end

    test "positions are within matrix bounds" do
      logo = Logo.new(svg: @sample_svg, size: 0.2, padding: 1)
      positions = Logo.cleared_positions(logo, 21, 10, 4)

      Enum.each(positions, fn {row, col} ->
        assert row >= 0 and row < 21
        assert col >= 0 and col < 21
      end)
    end

    test "positions are centered" do
      logo = Logo.new(svg: @sample_svg, size: 0.2, padding: 0)
      positions = Logo.cleared_positions(logo, 21, 10, 4)

      rows = Enum.map(positions, fn {r, _} -> r end)
      cols = Enum.map(positions, fn {_, c} -> c end)

      # Cleared area should be roughly centered around module 10,10
      avg_row = Enum.sum(rows) / Enum.count(rows)
      avg_col = Enum.sum(cols) / Enum.count(cols)

      assert abs(avg_row - 10) < 2
      assert abs(avg_col - 10) < 2
    end
  end

  describe "render_svg/2" do
    test "renders square background and nested SVG" do
      logo = Logo.new(svg: @sample_svg, shape: :square)
      geo = Logo.geometry(logo, 21, 10, 4)
      result = Logo.render_svg(logo, geo) |> IO.iodata_to_binary()

      assert String.contains?(result, "<rect")
      assert String.contains?(result, ~s(fill="#ffffff"))
      assert String.contains?(result, "<svg x=")
      assert String.contains?(result, @sample_svg)
      assert String.contains?(result, "</svg>")
    end

    test "renders rounded background" do
      logo = Logo.new(svg: @sample_svg, shape: :rounded, border_radius: 6)
      geo = Logo.geometry(logo, 21, 10, 4)
      result = Logo.render_svg(logo, geo) |> IO.iodata_to_binary()

      assert String.contains?(result, ~s(rx="6"))
      assert String.contains?(result, ~s(ry="6"))
    end

    test "renders circle background" do
      logo = Logo.new(svg: @sample_svg, shape: :circle)
      geo = Logo.geometry(logo, 21, 10, 4)
      result = Logo.render_svg(logo, geo) |> IO.iodata_to_binary()

      assert String.contains?(result, "<circle")
      assert String.contains?(result, "cx=")
      assert String.contains?(result, "cy=")
    end

    test "custom background color" do
      logo = Logo.new(svg: @sample_svg, background: "#f5f5dc")
      geo = Logo.geometry(logo, 21, 10, 4)
      result = Logo.render_svg(logo, geo) |> IO.iodata_to_binary()

      assert String.contains?(result, ~s(fill="#f5f5dc"))
    end

    test "renders raster PNG logo as base64 <image> element" do
      logo = Logo.new(image: @sample_png, image_type: :png)
      geo = Logo.geometry(logo, 21, 10, 4)
      result = Logo.render_svg(logo, geo) |> IO.iodata_to_binary()

      assert String.contains?(result, "<image href=\"data:image/png;base64,")
      assert String.contains?(result, Base.encode64(@sample_png))
      assert String.contains?(result, "preserveAspectRatio=\"xMidYMid meet\"")
      # Should still have background
      assert String.contains?(result, "<rect")
    end

    test "renders raster JPEG logo with correct MIME type" do
      logo = Logo.new(image: @sample_jpeg, image_type: :jpeg)
      geo = Logo.geometry(logo, 21, 10, 4)
      result = Logo.render_svg(logo, geo) |> IO.iodata_to_binary()

      assert String.contains?(result, "data:image/jpeg;base64,")
    end

    test "raster logo with circle background" do
      logo = Logo.new(image: @sample_png, image_type: :png, shape: :circle)
      geo = Logo.geometry(logo, 21, 10, 4)
      result = Logo.render_svg(logo, geo) |> IO.iodata_to_binary()

      assert String.contains?(result, "<circle")
      assert String.contains?(result, "<image href=")
    end

    test "raster logo with rounded background" do
      logo = Logo.new(image: @sample_png, image_type: :png, shape: :rounded, border_radius: 8)
      geo = Logo.geometry(logo, 21, 10, 4)
      result = Logo.render_svg(logo, geo) |> IO.iodata_to_binary()

      assert String.contains?(result, ~s(rx="8"))
      assert String.contains?(result, "<image href=")
    end
  end
end
