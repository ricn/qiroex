defmodule Qiroex.Render.SVG.LogoTest do
  use ExUnit.Case, async: true

  alias Qiroex.Render.SVG
  alias Qiroex.Logo
  alias Qiroex.Style
  alias Qiroex.QR

  @sample_svg ~s(<svg viewBox="0 0 100 100"><circle cx="50" cy="50" r="40" fill="blue"/></svg>)

  setup do
    {:ok, qr} = QR.encode("HELLO WORLD", level: :h)
    %{matrix: qr.matrix}
  end

  describe "SVG rendering with logo" do
    test "embeds logo SVG in output", %{matrix: matrix} do
      logo = Logo.new(svg: @sample_svg, size: 0.2)
      svg = SVG.render(matrix, logo: logo)

      assert String.contains?(svg, @sample_svg)
    end

    test "includes background rect for logo", %{matrix: matrix} do
      logo = Logo.new(svg: @sample_svg, size: 0.2, background: "#fff")
      svg = SVG.render(matrix, logo: logo)

      # Should have a background rect (for the logo area) in addition to the main background
      # The logo background rect has specific x,y coordinates (not "100%")
      assert Regex.match?(~r/<rect x="\d+/, svg)
    end

    test "clears modules behind logo", %{matrix: matrix} do
      svg_no_logo = SVG.render(matrix)
      logo = Logo.new(svg: @sample_svg, size: 0.25, padding: 1)
      svg_with_logo = SVG.render(matrix, logo: logo)

      # The version with logo should have fewer path commands (fewer dark modules)
      no_logo_m_count = count_occurrences(svg_no_logo, "M")
      with_logo_m_count = count_occurrences(svg_with_logo, "M")

      assert with_logo_m_count < no_logo_m_count
    end

    test "logo appears after dark modules in SVG", %{matrix: matrix} do
      logo = Logo.new(svg: @sample_svg, size: 0.2)
      svg = SVG.render(matrix, logo: logo)

      # The logo SVG should appear after the path element
      {path_pos, _} = :binary.match(svg, "fill=\"#000000\"/>")
      {logo_pos, _} = :binary.match(svg, @sample_svg)

      assert logo_pos > path_pos
    end

    test "nested SVG has correct x,y position", %{matrix: matrix} do
      logo = Logo.new(svg: @sample_svg, size: 0.2)
      svg = SVG.render(matrix, logo: logo)

      # Should have an svg element with x and y attributes for the logo
      assert Regex.match?(~r/<svg x="\d+" y="\d+"/, svg)
    end

    test "circle logo background", %{matrix: matrix} do
      logo = Logo.new(svg: @sample_svg, size: 0.2, shape: :circle)
      svg = SVG.render(matrix, logo: logo)

      # Should have a circle element for the background
      assert String.contains?(svg, "<circle cx=")
      assert String.contains?(svg, @sample_svg)
    end

    test "rounded logo background", %{matrix: matrix} do
      logo = Logo.new(svg: @sample_svg, size: 0.2, shape: :rounded, border_radius: 8)
      svg = SVG.render(matrix, logo: logo)

      assert String.contains?(svg, ~s(rx="8"))
      assert String.contains?(svg, @sample_svg)
    end

    test "no logo renders normally", %{matrix: matrix} do
      svg_no_logo = SVG.render(matrix)
      svg_nil_logo = SVG.render(matrix, logo: nil)

      assert svg_no_logo == svg_nil_logo
    end
  end

  describe "logo with styled rendering" do
    test "logo works with module shapes", %{matrix: matrix} do
      style = Style.new(module_shape: :circle)
      logo = Logo.new(svg: @sample_svg, size: 0.2)
      svg = SVG.render(matrix, style: style, logo: logo)

      assert String.contains?(svg, "<circle")
      assert String.contains?(svg, @sample_svg)
    end

    test "logo works with finder pattern styling", %{matrix: matrix} do
      style = Style.new(finder: %{eye: "#e74c3c"})
      logo = Logo.new(svg: @sample_svg, size: 0.15)
      svg = SVG.render(matrix, style: style, logo: logo)

      assert String.contains?(svg, "#e74c3c")
      assert String.contains?(svg, @sample_svg)
    end

    test "logo works with gradient", %{matrix: matrix} do
      style = Style.new(gradient: %{type: :linear, start_color: "#000", end_color: "#3498db"})
      logo = Logo.new(svg: @sample_svg, size: 0.2)
      svg = SVG.render(matrix, style: style, logo: logo)

      assert String.contains?(svg, "linearGradient")
      assert String.contains?(svg, @sample_svg)
    end
  end

  describe "public API integration" do
    test "to_svg! with logo" do
      logo = Logo.new(svg: @sample_svg, size: 0.2)
      svg = Qiroex.to_svg!("HELLO WORLD", level: :h, logo: logo)

      assert String.contains?(svg, @sample_svg)
      assert String.contains?(svg, "<svg")
    end

    test "to_svg with logo" do
      logo = Logo.new(svg: @sample_svg, size: 0.2)
      {:ok, svg} = Qiroex.to_svg("HELLO WORLD", level: :h, logo: logo)

      assert String.contains?(svg, @sample_svg)
    end

    test "save_svg with logo" do
      logo = Logo.new(svg: @sample_svg, size: 0.2)
      path = Path.join(System.tmp_dir!(), "test_logo_#{:rand.uniform(100_000)}.svg")

      try do
        assert :ok = Qiroex.save_svg("HELLO WORLD", path, level: :h, logo: logo)
        content = File.read!(path)
        assert String.contains?(content, @sample_svg)
      after
        File.rm(path)
      end
    end
  end

  # Helper to count string occurrences
  defp count_occurrences(string, pattern) do
    string
    |> String.split(pattern)
    |> length()
    |> Kernel.-(1)
  end
end
