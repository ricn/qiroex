defmodule Qiroex.BackgroundImage do
  @moduledoc """
  Background image configuration for SVG QR rendering.

  Background images are rendered beneath the QR modules but inside the QR
  content area only, leaving the quiet zone untouched for scan reliability.
  Sources can be provided as SVG markup or as raster image binaries such as
  JPEG, PNG, WEBP, GIF, BMP, AVIF, or TIFF.

  Raster images are embedded as base64 data URIs inside the SVG output, so the
  final SVG stays self-contained. This makes photo-style backgrounds practical
  without introducing external dependencies.

  ## Usage

  ### Load a photo from disk

      background = Qiroex.BackgroundImage.from_file!("photo.jpg", opacity: 0.2)
      Qiroex.to_svg!("Hello", level: :h, background_image: background)

  ### Use image bytes already in memory

      background = Qiroex.BackgroundImage.new(image: jpeg_bytes, opacity: 0.18)
      Qiroex.to_svg!("Hello", background_image: background)

  ### Use SVG markup

      background = Qiroex.BackgroundImage.new(svg: "<svg>...</svg>", fit: :contain)
      Qiroex.to_svg!("Hello", background_image: background)

  ## Options
    - `:svg` — SVG markup string for the background image (provide this **or** `:image`)
    - `:image` — binary image data for a raster background image (provide this **or** `:svg`)
    - `:image_type` — image format atom: `:png`, `:jpeg`, `:webp`, `:gif`, `:bmp`, `:avif`, `:tiff`
    - `:opacity` — background opacity from `0.0` to `1.0` (default: `0.2`)
    - `:fit` — how the source fits inside the QR content area: `:cover` or `:contain` (default: `:cover`)
  """

  alias Qiroex.Asset

  @type fit :: :cover | :contain
  @type image_type :: :png | :jpeg | :webp | :gif | :bmp | :avif | :tiff

  @type t :: %__MODULE__{
          svg: String.t() | nil,
          image: binary() | nil,
          image_type: image_type() | nil,
          opacity: number(),
          fit: fit()
        }

  defstruct svg: nil,
            image: nil,
            image_type: nil,
            opacity: 0.2,
            fit: :cover

  @valid_image_types Asset.valid_image_types()
  @valid_fits [:cover, :contain]

  @doc """
  Creates a new background image configuration.

  Provide either `:svg` or `:image`. Raster image types are auto-detected when
  omitted.
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    svg = Keyword.get(opts, :svg)
    image = Keyword.get(opts, :image)
    image_type = Keyword.get(opts, :image_type)

    image_type =
      if image && is_nil(image_type), do: Asset.detect_image_type(image), else: image_type

    background_image = %__MODULE__{
      svg: svg,
      image: image,
      image_type: image_type,
      opacity: Keyword.get(opts, :opacity, 0.2),
      fit: Keyword.get(opts, :fit, :cover)
    }

    validate!(background_image)
    background_image
  end

  @doc """
  Loads a background image from disk.

  SVG files are treated as markup. Other files are treated as raster images and
  their type is auto-detected from the file bytes.
  """
  @spec from_file(Path.t(), keyword()) :: {:ok, t()} | {:error, String.t() | File.posix()}
  def from_file(path, opts \\ []) do
    with {:ok, binary} <- File.read(path) do
      try do
        {:ok, new(file_source_opts(path, binary) ++ opts)}
      rescue
        error in ArgumentError -> {:error, Exception.message(error)}
      end
    end
  end

  @doc """
  Loads a background image from disk, raising on error.
  """
  @spec from_file!(Path.t(), keyword()) :: t()
  def from_file!(path, opts \\ []) do
    binary = File.read!(path)
    new(file_source_opts(path, binary) ++ opts)
  end

  @doc false
  @spec geometry(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: map()
  def geometry(matrix_size, module_size, quiet_zone) do
    side = matrix_size * module_size
    offset = quiet_zone * module_size

    %{
      x: offset,
      y: offset,
      width: side,
      height: side
    }
  end

  @doc false
  @spec render_svg(t(), map()) :: iolist()
  def render_svg(%__MODULE__{} = background_image, geo) do
    data_uri = data_uri(background_image)
    preserve = Asset.preserve_aspect_ratio(background_image.fit)

    [
      ~s(<image href="),
      data_uri,
      ~s(" x="),
      to_s(geo.x),
      ~s(" y="),
      to_s(geo.y),
      ~s(" width="),
      to_s(geo.width),
      ~s(" height="),
      to_s(geo.height),
      ~s(" opacity="),
      to_s(background_image.opacity),
      ~s(" preserveAspectRatio="),
      preserve,
      "\"/>\n"
    ]
  end

  defp data_uri(%__MODULE__{svg: svg}) when is_binary(svg), do: Asset.svg_data_uri(svg)

  defp data_uri(%__MODULE__{image: image, image_type: image_type}) when is_binary(image) do
    Asset.raster_data_uri(image, image_type)
  end

  defp validate!(%__MODULE__{} = background_image) do
    validate_source!(background_image)

    unless is_number(background_image.opacity) and background_image.opacity >= 0 and
             background_image.opacity <= 1 do
      raise ArgumentError,
            "Background image opacity must be between 0.0 and 1.0, got: #{inspect(background_image.opacity)}"
    end

    unless background_image.fit in @valid_fits do
      raise ArgumentError,
            "Background image fit must be one of #{inspect(@valid_fits)}, got: #{inspect(background_image.fit)}"
    end

    :ok
  end

  defp validate_source!(%__MODULE__{svg: nil, image: nil}) do
    raise ArgumentError,
          "Background image requires either :svg (SVG markup string) or :image (binary image data)"
  end

  defp validate_source!(%__MODULE__{svg: svg, image: image})
       when not is_nil(svg) and not is_nil(image) do
    raise ArgumentError,
          "Background image accepts either :svg or :image, not both"
  end

  defp validate_source!(%__MODULE__{svg: svg}) when is_binary(svg) do
    if svg == "" do
      raise ArgumentError, "Background image SVG markup cannot be empty"
    end

    :ok
  end

  defp validate_source!(%__MODULE__{image: image, image_type: image_type})
       when is_binary(image) do
    if byte_size(image) == 0 do
      raise ArgumentError, "Background image data cannot be empty"
    end

    unless image_type in @valid_image_types do
      raise ArgumentError,
            "Background image image_type must be one of #{inspect(@valid_image_types)}, got: #{inspect(image_type)}. " <>
              "Provide :image_type explicitly or use a supported format (PNG, JPEG, WEBP, GIF, BMP, AVIF, TIFF)"
    end

    :ok
  end

  defp file_source_opts(path, binary) do
    if svg_file?(path, binary) do
      [svg: binary]
    else
      [image: binary]
    end
  end

  defp svg_file?(path, binary) do
    String.downcase(Path.extname(path)) == ".svg" or svg_markup?(binary)
  end

  defp svg_markup?(binary) do
    if String.valid?(binary) do
      trimmed = String.trim_leading(binary)

      String.starts_with?(trimmed, "<svg") or
        (String.starts_with?(trimmed, "<?xml") and
           String.contains?(String.slice(trimmed, 0, 256), "<svg"))
    else
      false
    end
  end

  defp to_s(n) when is_integer(n), do: Integer.to_string(n)
  defp to_s(n) when is_float(n), do: Float.to_string(n)
end
