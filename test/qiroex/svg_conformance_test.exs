defmodule Qiroex.SVGConformanceTest do
  use ExUnit.Case, async: true

  alias Qiroex.{BackgroundImage, Logo, Style}

  @moduletag :conformance

  @decoder_args ["--raw", "-q"]
  @svg_render_opts [module_size: 12, quiet_zone: 4, dark_color: "#111827", light_color: "#FFFFFF"]
  @sample_logo_svg ~s(<svg viewBox="0 0 100 100"><rect x="8" y="8" width="84" height="84" rx="18" fill="#0F766E"/><circle cx="50" cy="50" r="24" fill="#FACC15"/></svg>)

  @sample_png <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
                0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x02,
                0x00, 0x00, 0x00, 0x90, 0x77, 0x53, 0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44,
                0x41, 0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00, 0x00, 0x00, 0x02, 0x00,
                0x01, 0xE2, 0x21, 0xBC, 0x33, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44,
                0xAE, 0x42, 0x60, 0x82>>

  setup_all do
    case {System.find_executable("zbarimg"), System.find_executable("rsvg-convert")} do
      {nil, _} ->
        {:skip, "zbarimg is not installed; run `brew install zbar` or install zbar-tools in CI"}

      {_, nil} ->
        {:skip,
         "rsvg-convert is not installed; run `brew install librsvg` or install librsvg2-bin in CI"}

      {zbarimg, rasterizer} ->
        {:ok, zbarimg: zbarimg, rasterizer: rasterizer}
    end
  end

  test "styled SVG with embedded logo decodes after rasterization", %{
    zbarimg: zbarimg,
    rasterizer: rasterizer
  } do
    data = "https://qiroex.dev/svg-logo-proof"

    style =
      Style.new(
        module_shape: :rounded,
        module_radius: 0.28,
        finder: %{
          outer: "#0F172A",
          outer_shape: :rounded,
          inner: "#FFFFFF",
          inner_shape: :rounded,
          eye: "#1D4ED8",
          eye_shape: :circle
        }
      )

    logo = Logo.new(svg: @sample_logo_svg, size: 0.14, padding: 1, shape: :circle)
    svg = Qiroex.to_svg!(data, @svg_render_opts ++ [level: :h, style: style, logo: logo])

    assert_svg_decodes(rasterizer, zbarimg, svg, data)
  end

  test "SVG with background image decodes after rasterization", %{
    zbarimg: zbarimg,
    rasterizer: rasterizer
  } do
    data = "https://qiroex.dev/svg-background-proof"
    background_image = BackgroundImage.new(image: @sample_png, image_type: :png, opacity: 0.08)
    style = Style.new(finder: %{outer: "#003049", inner: "#FFFFFF", eye: "#D62828"})

    svg =
      Qiroex.to_svg!(
        data,
        @svg_render_opts ++
          [level: :h, dark_color: "#0B132B", style: style, background_image: background_image]
      )

    assert_svg_decodes(rasterizer, zbarimg, svg, data)
  end

  test "SVG with logo and background image decodes after rasterization", %{
    zbarimg: zbarimg,
    rasterizer: rasterizer
  } do
    data = "https://qiroex.dev/svg-full-proof"

    background_image =
      BackgroundImage.new(image: @sample_png, image_type: :png, opacity: 0.06, fit: :contain)

    logo =
      Logo.new(
        svg: @sample_logo_svg,
        size: 0.12,
        padding: 1,
        shape: :rounded,
        border_radius: 6
      )

    style =
      Style.new(
        module_shape: :rounded,
        module_radius: 0.22,
        finder: %{outer: "#005F73", inner: "#FFFFFF", eye: "#9B2226"}
      )

    svg =
      Qiroex.to_svg!(
        data,
        @svg_render_opts ++
          [
            level: :h,
            dark_color: "#001219",
            style: style,
            logo: logo,
            background_image: background_image
          ]
      )

    assert_svg_decodes(rasterizer, zbarimg, svg, data)
  end

  defp assert_svg_decodes(rasterizer, zbarimg, svg, expected) do
    {svg_path, png_path} = temp_svg_and_png_paths()

    try do
      File.write!(svg_path, svg)

      {rasterizer_output, rasterizer_exit_code} =
        System.cmd(rasterizer, ["-o", png_path, svg_path], stderr_to_stdout: true)

      assert rasterizer_exit_code == 0, rasterizer_output

      {decoded, decoder_exit_code} =
        System.cmd(zbarimg, @decoder_args ++ [png_path], stderr_to_stdout: true)

      assert decoder_exit_code == 0
      assert normalize_decoder_output(decoded) == expected
    after
      File.rm(svg_path)
      File.rm(png_path)
    end
  end

  defp normalize_decoder_output(output) do
    output
    |> String.replace_suffix("\n", "")
    |> String.replace_suffix("\r", "")
  end

  defp temp_svg_and_png_paths do
    unique = System.unique_integer([:positive, :monotonic])
    base = Path.join(System.tmp_dir!(), "qiroex_svg_conformance_#{unique}")
    {base <> ".svg", base <> ".png"}
  end
end
