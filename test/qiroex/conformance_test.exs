defmodule Qiroex.ConformanceTest do
  use ExUnit.Case, async: true

  @moduletag :conformance

  @decoder_args ["--raw", "-q"]
  @render_opts [module_size: 8, quiet_zone: 4]

  @cases [
    {"decodes numeric version 1 level L", "01234567890123456789",
     [level: :l, version: 1, mode: :numeric]},
    {"decodes numeric version 1 level H", "0123456789012345",
     [level: :h, version: 1, mode: :numeric]},
    {"decodes alphanumeric version 1 level M", "HELLO WORLD",
     [level: :m, version: 1, mode: :alphanumeric]},
    {"decodes alphanumeric version 5 level Q", "QIROEX 1.0 READY",
     [level: :q, version: 5, mode: :alphanumeric]},
    {"decodes byte mode version 1 level L", "Hello, World!",
     [level: :l, version: 1, mode: :byte]},
    {"decodes byte mode version 7 level H", "https://example.com/qiroex?ref=ci",
     [level: :h, version: 7, mode: :byte]},
    {"decodes forced version 10 with explicit mask", "https://qiroex.dev/docs",
     [level: :m, version: 10, mode: :byte, mask: 3]},
    {"decodes forced version 25 level Q", "QIROEX-" <> String.duplicate("BUILD-", 18),
     [level: :q, version: 25, mode: :byte]},
    {"decodes forced version 20 level H", "Qiroex standard verification",
     [level: :h, version: 20, mode: :byte]},
    {"decodes wifi payload content", "WIFI:T:WPA;S:QIROEX;P:supersecret;;",
     [level: :h, version: 7, mode: :byte]}
  ]

  setup_all do
    case System.find_executable("zbarimg") do
      nil ->
        {:skip, "zbarimg is not installed; run `brew install zbar` or install zbar-tools in CI"}

      zbarimg ->
        {:ok, zbarimg: zbarimg}
    end
  end

  for {name, data, encode_opts} <- @cases do
    test name, %{zbarimg: zbarimg} do
      png = Qiroex.to_png!(unquote(data), @render_opts ++ unquote(Macro.escape(encode_opts)))
      path = temp_png_path()

      try do
        File.write!(path, png)

        {decoded, exit_code} =
          System.cmd(zbarimg, @decoder_args ++ [path], stderr_to_stdout: true)

        assert exit_code == 0
        assert normalize_decoder_output(decoded) == unquote(data)
      after
        File.rm(path)
      end
    end
  end

  defp normalize_decoder_output(output) do
    output
    |> String.replace_suffix("\n", "")
    |> String.replace_suffix("\r", "")
  end

  defp temp_png_path do
    unique = System.unique_integer([:positive, :monotonic])
    Path.join(System.tmp_dir!(), "qiroex_conformance_#{unique}.png")
  end
end
