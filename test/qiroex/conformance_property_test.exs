defmodule Qiroex.ConformancePropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import StreamData

  @moduletag :conformance

  @decoder_args ["--raw", "-q"]
  @levels [:l, :m, :q, :h]
  @render_opts [module_size: 8, quiet_zone: 4]
  @numeric_chars Enum.to_list(?0..?9)
  @alphanumeric_chars String.to_charlist("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:")
  @byte_chars Enum.to_list(32..126)

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
      path = temp_png_path()

      try do
        File.write!(path, png)

        {decoded, exit_code} =
          System.cmd(zbarimg, @decoder_args ++ [path], stderr_to_stdout: true)

        assert exit_code == 0
        assert normalize_decoder_output(decoded) == data
      after
        File.rm(path)
      end
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

  defp temp_png_path do
    unique = System.unique_integer([:positive, :monotonic])
    Path.join(System.tmp_dir!(), "qiroex_property_#{unique}.png")
  end
end
