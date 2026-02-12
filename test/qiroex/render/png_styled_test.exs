defmodule Qiroex.Render.PNG.StyledTest do
  use ExUnit.Case, async: true

  alias Qiroex.Render.PNG
  alias Qiroex.Style
  alias Qiroex.QR

  @png_signature <<137, 80, 78, 71, 13, 10, 26, 10>>

  setup do
    {:ok, qr} = QR.encode("HELLO", level: :m)
    %{matrix: qr.matrix}
  end

  describe "styled PNG rendering" do
    test "valid PNG with finder colors", %{matrix: matrix} do
      style = Style.new(finder: %{
        outer: "#1a5276",
        inner: "#d5e8f0",
        eye: "#e74c3c"
      })
      png = PNG.render(matrix, style: style)

      assert is_binary(png)
      assert <<@png_signature, _rest::binary>> = png
    end

    test "PLTE chunk has 5 entries with finder styling", %{matrix: matrix} do
      style = Style.new(finder: %{
        outer: "#ff0000",
        inner: "#00ff00",
        eye: "#0000ff"
      })
      png = PNG.render(matrix, style: style)

      # Find PLTE chunk: 5 colors × 3 bytes = 15 bytes
      assert find_chunk_length(png, "PLTE") == 15
    end

    test "PLTE chunk has 2 entries without styling", %{matrix: matrix} do
      png = PNG.render(matrix)

      # 2 colors × 3 bytes = 6 bytes
      assert find_chunk_length(png, "PLTE") == 6
    end

    test "has correct dimensions with style", %{matrix: matrix} do
      style = Style.new(finder: %{eye: "#ff0000"})
      png = PNG.render(matrix, module_size: 5, style: style)

      expected_px = (matrix.size + 8) * 5

      <<@png_signature, 13::32, "IHDR",
        width::32, height::32, _rest::binary>> = png

      assert width == expected_px
      assert height == expected_px
    end

    test "styled and unstyled produce same dimensions", %{matrix: matrix} do
      style = Style.new(finder: %{eye: "#ff0000"})
      png_plain = PNG.render(matrix)
      png_styled = PNG.render(matrix, style: style)

      <<@png_signature, 13::32, "IHDR", w1::32, h1::32, _::binary>> = png_plain
      <<@png_signature, 13::32, "IHDR", w2::32, h2::32, _::binary>> = png_styled

      assert w1 == w2
      assert h1 == h2
    end

    test "nil style uses simple 2-color path", %{matrix: matrix} do
      png = PNG.render(matrix, style: nil)

      assert is_binary(png)
      assert find_chunk_length(png, "PLTE") == 6
    end
  end

  describe "save/3 with style" do
    test "writes styled PNG to file", %{matrix: matrix} do
      path = Path.join(System.tmp_dir!(), "test_styled_#{:rand.uniform(100_000)}.png")
      style = Style.new(finder: %{eye: "#e74c3c"})

      try do
        assert :ok = PNG.save(matrix, path, style: style)
        data = File.read!(path)
        assert <<@png_signature, _::binary>> = data
      after
        File.rm(path)
      end
    end
  end

  # Helper to find the data length of a specific PNG chunk type
  defp find_chunk_length(png, chunk_type) do
    find_chunk_length(png, chunk_type, 8)
  end

  defp find_chunk_length(data, chunk_type, offset) when offset < byte_size(data) - 8 do
    <<_before::binary-size(offset), length::32, type::binary-size(4), _rest::binary>> = data

    if type == chunk_type do
      length
    else
      # Skip: length(4) + type(4) + data(length) + crc(4)
      find_chunk_length(data, chunk_type, offset + 12 + length)
    end
  end

  defp find_chunk_length(_, _, _), do: nil
end
