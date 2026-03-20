defmodule Qiroex.VersionPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import StreamData

  alias Qiroex.{QR, Spec, Version}

  @levels [:l, :m, :q, :h]
  @numeric_chars Enum.to_list(?0..?9)
  @alphanumeric_chars String.to_charlist("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ $%*+-./:")
  @byte_chars Enum.to_list(32..126)

  property "auto-selected versions are minimal and spec-consistent" do
    check all(
            {mode, data} <- encode_case_generator(),
            level <- member_of(@levels),
            max_runs: 80
          ) do
      assert {:ok, version} = Version.select(data, level, mode)
      assert Version.fits?(data, version, level, mode)

      if version > 1 do
        refute Version.fits?(data, version - 1, level, mode)
      end

      assert {:ok, qr} = QR.encode(data, level: level, mode: mode)
      assert qr.version == version
      assert qr.matrix.size == Spec.matrix_size(version)
      assert length(qr.codewords) == Spec.total_codewords(version)
    end
  end

  defp encode_case_generator do
    one_of([
      map(numeric_data_generator(), &{:numeric, &1}),
      map(alphanumeric_data_generator(), &{:alphanumeric, &1}),
      map(byte_data_generator(), &{:byte, &1})
    ])
  end

  defp numeric_data_generator do
    @numeric_chars
    |> member_of()
    |> list_of(min_length: 1, max_length: 240)
    |> map(&List.to_string/1)
  end

  defp alphanumeric_data_generator do
    @alphanumeric_chars
    |> member_of()
    |> list_of(min_length: 1, max_length: 160)
    |> map(&List.to_string/1)
  end

  defp byte_data_generator do
    @byte_chars
    |> member_of()
    |> list_of(min_length: 1, max_length: 120)
    |> map(&List.to_string/1)
  end
end
