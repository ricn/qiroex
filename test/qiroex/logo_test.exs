defmodule Qiroex.LogoTest do
  use ExUnit.Case, async: true

  alias Qiroex.Logo

  @sample_svg ~s(<svg viewBox="0 0 100 100"><circle cx="50" cy="50" r="40" fill="blue"/></svg>)

  describe "new/1" do
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
      assert_raise KeyError, fn ->
        Logo.new([])
      end
    end

    test "rejects empty SVG" do
      assert_raise ArgumentError, ~r/SVG markup is required/, fn ->
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
  end
end
