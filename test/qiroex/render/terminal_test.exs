defmodule Qiroex.Render.TerminalTest do
  use ExUnit.Case, async: true

  alias Qiroex.Render.Terminal
  alias Qiroex.QR

  setup do
    {:ok, qr} = QR.encode("HELLO", level: :m)
    %{qr: qr, matrix: qr.matrix}
  end

  describe "render/2 compact mode" do
    test "returns a string", %{matrix: matrix} do
      result = Terminal.render(matrix)
      assert is_binary(result)
      assert String.length(result) > 0
    end

    test "contains Unicode block characters", %{matrix: matrix} do
      result = Terminal.render(matrix)

      # Should contain at least some of these characters
      has_blocks =
        String.contains?(result, "█") or
        String.contains?(result, "▀") or
        String.contains?(result, "▄")

      assert has_blocks
    end

    test "compact mode produces fewer lines than simple mode", %{matrix: matrix} do
      compact = Terminal.render(matrix, compact: true)
      simple = Terminal.render(matrix, compact: false)

      compact_lines = compact |> String.split("\n", trim: true)
      simple_lines = simple |> String.split("\n", trim: true)

      # Compact should have roughly half the lines
      assert length(compact_lines) < length(simple_lines)
    end

    test "ends with newline", %{matrix: matrix} do
      result = Terminal.render(matrix)
      assert String.ends_with?(result, "\n")
    end

    test "custom quiet zone", %{matrix: matrix} do
      result_default = Terminal.render(matrix, quiet_zone: 4)
      result_small = Terminal.render(matrix, quiet_zone: 1)

      # Smaller quiet zone → shorter output
      assert String.length(result_small) < String.length(result_default)
    end

    test "zero quiet zone works", %{matrix: matrix} do
      result = Terminal.render(matrix, quiet_zone: 0)
      assert is_binary(result)
      assert String.length(result) > 0
    end
  end

  describe "render/2 simple mode" do
    test "returns a string with full blocks", %{matrix: matrix} do
      result = Terminal.render(matrix, compact: false)

      assert is_binary(result)
      assert String.contains?(result, "█")
    end

    test "each line has consistent character count", %{matrix: matrix} do
      result = Terminal.render(matrix, compact: false)
      lines = String.split(result, "\n", trim: true)

      char_counts = Enum.map(lines, &String.length/1)
      assert Enum.uniq(char_counts) |> length() == 1, "All lines should have same character count"
    end

    test "number of lines matches matrix + quiet zone", %{matrix: matrix} do
      qz = 4
      result = Terminal.render(matrix, compact: false, quiet_zone: qz)
      lines = String.split(result, "\n", trim: true)

      expected = matrix.size + 2 * qz
      assert length(lines) == expected
    end
  end

  describe "compact mode line count" do
    test "compact produces ceil(total_rows/2) lines", %{matrix: matrix} do
      qz = 4
      result = Terminal.render(matrix, compact: true, quiet_zone: qz)
      lines = String.split(result, "\n", trim: true)

      total_rows = matrix.size + 2 * qz
      expected = div(total_rows, 2) + rem(total_rows, 2)
      assert length(lines) == expected
    end
  end

  describe "print/2" do
    test "prints to stdout without error", %{matrix: matrix} do
      # Capture IO to prevent actual terminal output in tests
      output = ExUnit.CaptureIO.capture_io(fn ->
        Terminal.print(matrix, quiet_zone: 1)
      end)

      assert String.length(output) > 0
    end
  end

  describe "deterministic output" do
    test "same input produces same output", %{matrix: matrix} do
      result1 = Terminal.render(matrix)
      result2 = Terminal.render(matrix)

      assert result1 == result2
    end
  end
end
