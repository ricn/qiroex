defmodule Qiroex.ValidateTest do
  use ExUnit.Case, async: true

  alias Qiroex.Validate

  # ── Encode Options ──────────────────────────────────────────────────

  describe "encode_opts/1" do
    test "accepts valid defaults" do
      assert :ok = Validate.encode_opts([])
    end

    test "accepts valid ec levels" do
      for level <- [:l, :m, :q, :h] do
        assert :ok = Validate.encode_opts(level: level)
        assert :ok = Validate.encode_opts(ec_level: level)
      end
    end

    test "rejects invalid ec level" do
      assert {:error, msg} = Validate.encode_opts(level: :x)
      assert msg =~ "invalid error correction level"
      assert msg =~ ":x"
    end

    test "accepts valid versions" do
      assert :ok = Validate.encode_opts(version: :auto)
      assert :ok = Validate.encode_opts(version: 1)
      assert :ok = Validate.encode_opts(version: 40)
    end

    test "rejects invalid versions" do
      assert {:error, msg} = Validate.encode_opts(version: 0)
      assert msg =~ "invalid version"

      assert {:error, msg} = Validate.encode_opts(version: 41)
      assert msg =~ "invalid version"

      assert {:error, msg} = Validate.encode_opts(version: "1")
      assert msg =~ "invalid version"
    end

    test "accepts valid modes" do
      for mode <- [:auto, :numeric, :alphanumeric, :byte, :kanji] do
        assert :ok = Validate.encode_opts(mode: mode)
      end
    end

    test "rejects invalid modes" do
      assert {:error, msg} = Validate.encode_opts(mode: :utf8)
      assert msg =~ "invalid mode"
    end

    test "accepts valid masks" do
      assert :ok = Validate.encode_opts(mask: :auto)

      for mask <- 0..7 do
        assert :ok = Validate.encode_opts(mask: mask)
      end
    end

    test "rejects invalid masks" do
      assert {:error, msg} = Validate.encode_opts(mask: -1)
      assert msg =~ "invalid mask"

      assert {:error, msg} = Validate.encode_opts(mask: 8)
      assert msg =~ "invalid mask"
    end
  end

  # ── SVG Render Options ─────────────────────────────────────────────

  describe "svg_render_opts/1" do
    test "accepts valid defaults" do
      assert :ok = Validate.svg_render_opts([])
    end

    test "accepts valid module_size" do
      assert :ok = Validate.svg_render_opts(module_size: 5)
      assert :ok = Validate.svg_render_opts(module_size: 1)
    end

    test "rejects invalid module_size" do
      assert {:error, msg} = Validate.svg_render_opts(module_size: 0)
      assert msg =~ "invalid module_size"

      assert {:error, msg} = Validate.svg_render_opts(module_size: -5)
      assert msg =~ "invalid module_size"

      assert {:error, msg} = Validate.svg_render_opts(module_size: "10")
      assert msg =~ "invalid module_size"
    end

    test "accepts valid quiet_zone" do
      assert :ok = Validate.svg_render_opts(quiet_zone: 0)
      assert :ok = Validate.svg_render_opts(quiet_zone: 4)
    end

    test "rejects invalid quiet_zone" do
      assert {:error, msg} = Validate.svg_render_opts(quiet_zone: -1)
      assert msg =~ "invalid quiet_zone"
    end

    test "accepts valid CSS colors" do
      assert :ok = Validate.svg_render_opts(dark_color: "#000", light_color: "white")
    end

    test "rejects invalid CSS colors" do
      assert {:error, msg} = Validate.svg_render_opts(dark_color: "")
      assert msg =~ "invalid dark_color"

      assert {:error, msg} = Validate.svg_render_opts(dark_color: 0)
      assert msg =~ "invalid dark_color"
    end

    test "accepts valid style struct" do
      style = Qiroex.Style.new(module_shape: :circle)
      assert :ok = Validate.svg_render_opts(style: style)
      assert :ok = Validate.svg_render_opts(style: nil)
    end

    test "rejects invalid style" do
      assert {:error, msg} = Validate.svg_render_opts(style: %{shape: :circle})
      assert msg =~ "invalid style"
    end

    test "accepts valid logo struct" do
      logo = Qiroex.Logo.new(svg: "<svg/>")
      assert :ok = Validate.svg_render_opts(logo: logo)
      assert :ok = Validate.svg_render_opts(logo: nil)
    end

    test "rejects invalid logo" do
      assert {:error, msg} = Validate.svg_render_opts(logo: "<svg/>")
      assert msg =~ "invalid logo"
    end
  end

  # ── PNG Render Options ─────────────────────────────────────────────

  describe "png_render_opts/1" do
    test "accepts valid defaults" do
      assert :ok = Validate.png_render_opts([])
    end

    test "accepts valid RGB colors" do
      assert :ok = Validate.png_render_opts(dark_color: {0, 0, 0})
      assert :ok = Validate.png_render_opts(light_color: {255, 255, 255})
    end

    test "rejects out-of-range RGB" do
      assert {:error, msg} = Validate.png_render_opts(dark_color: {256, 0, 0})
      assert msg =~ "invalid dark_color"
      assert msg =~ "{r, g, b}"
    end

    test "rejects non-tuple color" do
      assert {:error, msg} = Validate.png_render_opts(dark_color: "#000000")
      assert msg =~ "invalid dark_color"
    end
  end

  # ── Terminal Render Options ────────────────────────────────────────

  describe "terminal_render_opts/1" do
    test "accepts valid options" do
      assert :ok = Validate.terminal_render_opts([])
      assert :ok = Validate.terminal_render_opts(compact: true)
      assert :ok = Validate.terminal_render_opts(compact: false)
      assert :ok = Validate.terminal_render_opts(quiet_zone: 2)
    end

    test "rejects invalid compact" do
      assert {:error, msg} = Validate.terminal_render_opts(compact: "yes")
      assert msg =~ "invalid compact"
    end
  end

  # ── Payload Format ─────────────────────────────────────────────────

  describe "payload_format/1" do
    test "accepts valid formats" do
      for fmt <- [:svg, :png, :terminal, :matrix, :encode] do
        assert :ok = Validate.payload_format(fmt)
      end
    end

    test "rejects invalid format" do
      assert {:error, msg} = Validate.payload_format(:pdf)
      assert msg =~ "invalid format"
      assert msg =~ ":pdf"
    end
  end
end
