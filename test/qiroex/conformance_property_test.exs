defmodule Qiroex.ConformancePropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import StreamData

  alias Qiroex.Style

  @moduletag :conformance

  @decoder_args ["--raw", "-q"]
  @levels [:l, :m, :q, :h]
  @render_opts [module_size: 8, quiet_zone: 4]
  @numeric_chars Enum.to_list(?0..?9)
  @alphanumeric_chars String.to_charlist("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:")
  @byte_chars Enum.to_list(32..126)
  @styled_png_variants [
    [
      dark_color: {0, 0, 0},
      light_color: {255, 255, 255},
      style: Style.new(finder: %{outer: "#000000", inner: "#FFFFFF", eye: "#1D4ED8"})
    ],
    [
      dark_color: {15, 23, 42},
      light_color: {248, 250, 252},
      style: Style.new(finder: %{outer: "#0F172A", inner: "#F8FAFC", eye: "#DC2626"})
    ],
    [
      dark_color: {0, 53, 102},
      light_color: {255, 251, 235},
      style: Style.new(finder: %{outer: "#003566", inner: "#FFFBEB", eye: "#7C2D12"})
    ],
    [
      dark_color: {0, 95, 115},
      light_color: {238, 247, 255},
      style: Style.new(finder: %{outer: "#005F73", inner: "#FFFFFF", eye: "#9B2226"})
    ]
  ]

  setup_all do
    case System.find_executable("zbarimg") do
      nil ->
        {:skip, "zbarimg is not installed; run `brew install zbar` or install zbar-tools in CI"}

      zbarimg ->
        {:ok, zbarimg: zbarimg}
    end
  end

  property "random payloads round-trip through a real decoder", %{zbarimg: zbarimg} do
    check all(
            {mode, data} <- conformance_case_generator(),
            level <- member_of(@levels),
            max_runs: 40
          ) do
      png = Qiroex.to_png!(data, @render_opts ++ [level: level, mode: mode])
      assert_png_decodes(zbarimg, png, data)
    end
  end

  property "styled PNGs round-trip with finder styling and color variants", %{zbarimg: zbarimg} do
    check all(
            {mode, data} <- conformance_case_generator(),
            level <- member_of(@levels),
            styled_render_opts <- member_of(@styled_png_variants),
            max_runs: 24
          ) do
      png = Qiroex.to_png!(data, @render_opts ++ styled_render_opts ++ [level: level, mode: mode])
      assert_png_decodes(zbarimg, png, data)
    end
  end

  defp conformance_case_generator do
    one_of([
      map(numeric_data_generator(), &{:numeric, &1}),
      map(alphanumeric_data_generator(), &{:alphanumeric, &1}),
      map(byte_data_generator(), &{:byte, &1})
    ])
  end

  defp numeric_data_generator do
    @numeric_chars
    |> member_of()
    |> list_of(min_length: 1, max_length: 120)
    |> map(&List.to_string/1)
  end

  defp alphanumeric_data_generator do
    @alphanumeric_chars
    |> member_of()
    |> list_of(min_length: 1, max_length: 80)
    |> map(&List.to_string/1)
  end

  defp byte_data_generator do
    @byte_chars
    |> member_of()
    |> list_of(min_length: 1, max_length: 60)
    |> map(&List.to_string/1)
  end

  defp normalize_decoder_output(output) do
    output
    |> String.replace_suffix("\n", "")
    |> String.replace_suffix("\r", "")
  end

  defp assert_png_decodes(zbarimg, png, expected) do
    path = temp_png_path()

    try do
      File.write!(path, png)

      {decoded, exit_code} =
        System.cmd(zbarimg, @decoder_args ++ [path], stderr_to_stdout: true)

      assert exit_code == 0
      assert normalize_decoder_output(decoded) == expected
    after
      File.rm(path)
    end
  end

  defp temp_png_path do
    unique = System.unique_integer([:positive, :monotonic])
    Path.join(System.tmp_dir!(), "qiroex_property_#{unique}.png")
  end
end
