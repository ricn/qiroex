defmodule Qiroex.Render.SVGTest do
  use ExUnit.Case, async: true

  alias Qiroex.Render.SVG
  alias Qiroex.QR

  setup do
    {:ok, qr} = QR.encode("HELLO", level: :m)
    %{qr: qr, matrix: qr.matrix}
  end

  describe "render/2" do
    test "returns valid SVG string", %{matrix: matrix} do
      svg = SVG.render(matrix)

      assert is_binary(svg)
      assert String.starts_with?(svg, ~s(<?xml version="1.0"))
      assert String.contains?(svg, "<svg")
      assert String.contains?(svg, "</svg>")
    end

    test "contains path element for dark modules", %{matrix: matrix} do
      svg = SVG.render(matrix)

      assert String.contains?(svg, "<path")
      assert String.contains?(svg, ~s(fill="#000000"))
    end

    test "contains background rect", %{matrix: matrix} do
      svg = SVG.render(matrix)

      assert String.contains?(svg, "<rect")
      assert String.contains?(svg, ~s(fill="#ffffff"))
    end

    test "correct dimensions with default options", %{matrix: matrix} do
      svg = SVG.render(matrix)

      # V1 = 21 modules + 2*4 quiet zone = 29, × 10px = 290
      expected = (matrix.size + 8) * 10
      expected_s = Integer.to_string(expected)

      assert String.contains?(svg, ~s(width="#{expected_s}"))
      assert String.contains?(svg, ~s(height="#{expected_s}"))
    end

    test "custom module size", %{matrix: matrix} do
      svg = SVG.render(matrix, module_size: 5)

      expected = (matrix.size + 8) * 5
      expected_s = Integer.to_string(expected)

      assert String.contains?(svg, ~s(width="#{expected_s}"))
    end

    test "custom quiet zone", %{matrix: matrix} do
      svg = SVG.render(matrix, quiet_zone: 2)

      expected = (matrix.size + 4) * 10
      expected_s = Integer.to_string(expected)

      assert String.contains?(svg, ~s(width="#{expected_s}"))
    end

    test "custom colors", %{matrix: matrix} do
      svg = SVG.render(matrix, dark_color: "#ff0000", light_color: "#00ff00")

      assert String.contains?(svg, ~s(fill="#ff0000"))
      assert String.contains?(svg, ~s(fill="#00ff00"))
      refute String.contains?(svg, ~s(fill="#000000"))
    end

    test "path data contains M commands for dark modules", %{matrix: matrix} do
      svg = SVG.render(matrix)

      # Should contain path commands
      assert String.contains?(svg, "M")
      assert String.contains?(svg, "Z")
    end

    test "no quiet zone produces smaller SVG", %{matrix: matrix} do
      svg_default = SVG.render(matrix)
      svg_no_qz = SVG.render(matrix, quiet_zone: 0)

      assert String.length(svg_no_qz) < String.length(svg_default)
    end
  end

  describe "render_iolist/2" do
    test "returns iolist that produces same result as render", %{matrix: matrix} do
      svg_string = SVG.render(matrix)
      svg_iolist = SVG.render_iolist(matrix) |> IO.iodata_to_binary()

      assert svg_string == svg_iolist
    end
  end

  describe "SVG validity" do
    test "xmlns attribute present", %{matrix: matrix} do
      svg = SVG.render(matrix)
      assert String.contains?(svg, ~s(xmlns="http://www.w3.org/2000/svg"))
    end

    test "viewBox matches dimensions", %{matrix: matrix} do
      svg = SVG.render(matrix)
      expected = (matrix.size + 8) * 10
      expected_s = Integer.to_string(expected)

      assert String.contains?(svg, ~s(viewBox="0 0 #{expected_s} #{expected_s}"))
    end
  end
end
