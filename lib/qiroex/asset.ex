defmodule Qiroex.Asset do
  @moduledoc false

  @type image_type :: :png | :jpeg | :webp | :gif | :bmp | :avif | :tiff

  @valid_image_types [:png, :jpeg, :webp, :gif, :bmp, :avif, :tiff]

  @spec valid_image_types() :: [image_type()]
  def valid_image_types, do: @valid_image_types

  @spec image_type_to_mime(image_type()) :: String.t()
  def image_type_to_mime(:png), do: "image/png"
  def image_type_to_mime(:jpeg), do: "image/jpeg"
  def image_type_to_mime(:webp), do: "image/webp"
  def image_type_to_mime(:gif), do: "image/gif"
  def image_type_to_mime(:bmp), do: "image/bmp"
  def image_type_to_mime(:avif), do: "image/avif"
  def image_type_to_mime(:tiff), do: "image/tiff"

  @spec detect_image_type(binary()) :: image_type() | nil
  def detect_image_type(<<0x89, 0x50, 0x4E, 0x47, _::binary>>), do: :png
  def detect_image_type(<<0xFF, 0xD8, 0xFF, _::binary>>), do: :jpeg
  def detect_image_type(<<"RIFF", _size::32, "WEBP", _::binary>>), do: :webp
  def detect_image_type(<<"GIF87a", _::binary>>), do: :gif
  def detect_image_type(<<"GIF89a", _::binary>>), do: :gif
  def detect_image_type(<<"BM", _::binary>>), do: :bmp
  def detect_image_type(<<_size::32-big, "ftyp", "avif", _::binary>>), do: :avif
  def detect_image_type(<<_size::32-big, "ftyp", "avis", _::binary>>), do: :avif
  def detect_image_type(<<0x49, 0x49, 0x2A, 0x00, _::binary>>), do: :tiff
  def detect_image_type(<<0x4D, 0x4D, 0x00, 0x2A, _::binary>>), do: :tiff
  def detect_image_type(_), do: nil

  @spec raster_data_uri(binary(), image_type()) :: String.t()
  def raster_data_uri(image, image_type) when is_binary(image) do
    "data:" <> image_type_to_mime(image_type) <> ";base64," <> Base.encode64(image)
  end

  @spec svg_data_uri(String.t()) :: String.t()
  def svg_data_uri(svg) when is_binary(svg) do
    "data:image/svg+xml;base64," <> Base.encode64(svg)
  end

  @spec preserve_aspect_ratio(:cover | :contain) :: String.t()
  def preserve_aspect_ratio(:cover), do: "xMidYMid slice"
  def preserve_aspect_ratio(:contain), do: "xMidYMid meet"
end
