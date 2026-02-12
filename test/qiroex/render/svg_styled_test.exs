defmodule Qiroex.Render.SVG.StyledTest do
  use ExUnit.Case, async: true

  alias Qiroex.Render.SVG
  alias Qiroex.Style
  alias Qiroex.QR

  setup do
    {:ok, qr} = QR.encode("HELLO", level: :m)
    %{matrix: qr.matrix}
  end

  describe "module shapes" do
    test "circle shape renders <circle> elements", %{matrix: matrix} do
      style = Style.new(module_shape: :circle)
      svg = SVG.render(matrix, style: style)

      assert String.contains?(svg, "<circle")
      assert String.contains?(svg, "cx=")
      assert String.contains?(svg, "cy=")
      assert String.contains?(svg, " r=")
    end

    test "rounded shape renders <rect> with rx/ry", %{matrix: matrix} do
      style = Style.new(module_shape: :rounded, module_radius: 0.3)
      svg = SVG.render(matrix, style: style)

      assert String.contains?(svg, "<rect")
      assert String.contains?(svg, "rx=")
      assert String.contains?(svg, "ry=")
    end

    test "diamond shape renders <polygon>", %{matrix: matrix} do
      style = Style.new(module_shape: :diamond)
      svg = SVG.render(matrix, style: style)

      assert String.contains?(svg, "<polygon")
      assert String.contains?(svg, "points=")
    end

    test "square shape (default) still works with style", %{matrix: matrix} do
      style = Style.new(module_shape: :square, finder: %{eye: "#ff0000"})
      svg = SVG.render(matrix, style: style)

      assert String.contains?(svg, "<rect")
      assert is_binary(svg)
    end
  end

  describe "finder pattern styling" do
    test "custom finder colors appear in SVG", %{matrix: matrix} do
      style = Style.new(finder: %{
        outer: "#1a5276",
        inner: "#d5e8f0",
        eye: "#e74c3c"
      })
      svg = SVG.render(matrix, style: style)

      assert String.contains?(svg, "#1a5276")
      assert String.contains?(svg, "#d5e8f0")
      assert String.contains?(svg, "#e74c3c")
    end

    test "partial finder colors use defaults for missing", %{matrix: matrix} do
      style = Style.new(finder: %{eye: "#e74c3c"})
      svg = SVG.render(matrix, style: style)

      # Eye should be custom
      assert String.contains?(svg, "#e74c3c")
      # Dark color should appear for outer (default)
      assert String.contains?(svg, "#000000")
    end

    test "finder inner ring is always rendered with inner color", %{matrix: matrix} do
      style = Style.new(finder: %{inner: "#aabbcc"})
      svg = SVG.render(matrix, style: style)

      assert String.contains?(svg, "#aabbcc")
    end
  end

  describe "gradient fills" do
    test "linear gradient adds <defs> and <linearGradient>", %{matrix: matrix} do
      style = Style.new(gradient: %{
        type: :linear,
        start_color: "#000000",
        end_color: "#3498db"
      })
      svg = SVG.render(matrix, style: style)

      assert String.contains?(svg, "<defs>")
      assert String.contains?(svg, "<linearGradient")
      assert String.contains?(svg, "id=\"qr-gradient\"")
      assert String.contains?(svg, "#000000")
      assert String.contains?(svg, "#3498db")
      assert String.contains?(svg, "url(#qr-gradient)")
    end

    test "radial gradient adds <radialGradient>", %{matrix: matrix} do
      style = Style.new(gradient: %{
        type: :radial,
        start_color: "#ff0000",
        end_color: "#0000ff"
      })
      svg = SVG.render(matrix, style: style)

      assert String.contains?(svg, "<radialGradient")
      assert String.contains?(svg, "#ff0000")
      assert String.contains?(svg, "#0000ff")
    end

    test "gradient with custom angle sets direction", %{matrix: matrix} do
      style = Style.new(gradient: %{
        type: :linear,
        start_color: "#000",
        end_color: "#fff",
        angle: 90
      })
      svg = SVG.render(matrix, style: style)

      assert String.contains?(svg, "<linearGradient")
      # 90 degrees = left to right (x1=0, y1=0, x2=1, y2=0)
      assert String.contains?(svg, ~s(x2="1.0"))
    end

    test "gradient + finder colors: finders use their own colors", %{matrix: matrix} do
      style = Style.new(
        gradient: %{type: :linear, start_color: "#000", end_color: "#3498db"},
        finder: %{eye: "#e74c3c", outer: "#1a5276", inner: "#ffffff"}
      )
      svg = SVG.render(matrix, style: style)

      # Gradient for data modules
      assert String.contains?(svg, "url(#qr-gradient)")
      # Finder colors for finders
      assert String.contains?(svg, "#e74c3c")
      assert String.contains?(svg, "#1a5276")
    end
  end

  describe "no style (backward compatibility)" do
    test "renders exactly like before without style", %{matrix: matrix} do
      svg_no_style = SVG.render(matrix)
      svg_nil_style = SVG.render(matrix, style: nil)

      # Both should use the fast path with <path> element
      assert String.contains?(svg_no_style, "<path d=")
      assert svg_no_style == svg_nil_style
    end

    test "default style uses fast path", %{matrix: matrix} do
      style = Style.new()
      svg = SVG.render(matrix, style: style)

      # Default style should use the fast path
      assert String.contains?(svg, "<path d=")
    end
  end

  describe "combined styling" do
    test "circle shape with finder colors", %{matrix: matrix} do
      style = Style.new(
        module_shape: :circle,
        finder: %{outer: "#2c3e50", eye: "#e74c3c"}
      )
      svg = SVG.render(matrix, style: style)

      # Data modules as circles
      assert String.contains?(svg, "<circle")
      # Finder colors present
      assert String.contains?(svg, "#2c3e50")
      assert String.contains?(svg, "#e74c3c")
    end

    test "rounded shape with gradient", %{matrix: matrix} do
      style = Style.new(
        module_shape: :rounded,
        module_radius: 0.4,
        gradient: %{type: :linear, start_color: "#1a1a2e", end_color: "#16213e"}
      )
      svg = SVG.render(matrix, style: style)

      assert String.contains?(svg, "rx=")
      assert String.contains?(svg, "url(#qr-gradient)")
    end
  end

  describe "render_iolist/2" do
    test "styled iolist matches rendered string", %{matrix: matrix} do
      style = Style.new(module_shape: :circle, finder: %{eye: "#ff0000"})
      opts = [style: style]

      svg_string = SVG.render(matrix, opts)
      svg_from_iolist = SVG.render_iolist(matrix, opts) |> IO.iodata_to_binary()

      assert svg_string == svg_from_iolist
    end
  end
end
