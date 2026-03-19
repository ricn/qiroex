defmodule Qiroex.BackgroundImageTest do
  use ExUnit.Case, async: true

  alias Qiroex.BackgroundImage

  # Minimal JPEG signature. Qiroex embeds bytes without decoding them.
  @sample_jpeg <<0xFF, 0xD8, 0xFF, 0xD9>>
  @sample_svg ~s(<svg viewBox="0 0 10 10"><rect width="10" height="10" fill="#336699"/></svg>)

  describe "new/1" do
    test "auto-detects raster image types" do
      background_image = BackgroundImage.new(image: @sample_jpeg, opacity: 0.24)

      assert background_image.image == @sample_jpeg
      assert background_image.image_type == :jpeg
      assert background_image.opacity == 0.24
      assert background_image.fit == :cover
    end

    test "accepts SVG markup sources" do
      background_image = BackgroundImage.new(svg: @sample_svg, fit: :contain)

      assert background_image.svg == @sample_svg
      assert background_image.fit == :contain
      assert background_image.opacity == 0.2
    end

    test "rejects invalid opacity" do
      assert_raise ArgumentError, ~r/opacity must be between 0.0 and 1.0/, fn ->
        BackgroundImage.new(image: @sample_jpeg, opacity: 1.5)
      end
    end
  end

  describe "from_file/2" do
    test "loads raster images from disk" do
      path =
        Path.join(
          System.tmp_dir!(),
          "qiroex-background-#{System.unique_integer([:positive])}.jpg"
        )

      try do
        File.write!(path, @sample_jpeg)

        assert {:ok, %BackgroundImage{} = background_image} =
                 BackgroundImage.from_file(path, opacity: 0.18)

        assert background_image.image == @sample_jpeg
        assert background_image.image_type == :jpeg
        assert background_image.opacity == 0.18
      after
        File.rm(path)
      end
    end

    test "loads SVG files as markup" do
      path =
        Path.join(
          System.tmp_dir!(),
          "qiroex-background-#{System.unique_integer([:positive])}.svg"
        )

      try do
        File.write!(path, @sample_svg)

        assert {:ok, %BackgroundImage{} = background_image} = BackgroundImage.from_file(path)

        assert background_image.svg == @sample_svg
        assert is_nil(background_image.image)
      after
        File.rm(path)
      end
    end

    test "returns validation errors instead of raising" do
      path =
        Path.join(
          System.tmp_dir!(),
          "qiroex-background-#{System.unique_integer([:positive])}.jpg"
        )

      try do
        File.write!(path, @sample_jpeg)

        assert {:error, message} = BackgroundImage.from_file(path, opacity: -0.1)
        assert message =~ "opacity must be between 0.0 and 1.0"
      after
        File.rm(path)
      end
    end
  end
end
