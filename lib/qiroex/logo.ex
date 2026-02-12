defmodule Qiroex.Logo do
  @moduledoc """
  Logo embedding configuration and geometry for QR codes.

  Calculates the position, size, and cleared module region for embedding
  a logo in the center of a QR code. Validates that the logo doesn't
  cover too many data modules for the chosen error correction level.

  Logos can be provided as **SVG markup** or as **raster image binaries**
  (PNG, JPEG, WEBP, GIF, BMP). Raster images are embedded via base64
  data URIs — no external dependencies required.

  ## Coverage Limits

  The maximum safe logo coverage depends on the error correction level:
    - `:l` — 7% (level L can recover ~7% of data)
    - `:m` — 15% (level M can recover ~15%)
    - `:q` — 25% (level Q can recover ~25%)
    - `:h` — 30% (level H can recover ~30%)

  A safety margin of 80% is applied, so actual limits are slightly lower.

  ## Usage

  ### SVG logo

      logo = Qiroex.Logo.new(
        svg: ~s(<svg viewBox="0 0 100 100"><circle cx="50" cy="50" r="40" fill="blue"/></svg>),
        size: 0.25
      )

      Qiroex.to_svg!("Hello", logo: logo)

  ### Raster image logo (PNG, JPEG, etc.)

      png_bytes = File.read!("logo.png")
      logo = Qiroex.Logo.new(image: png_bytes, image_type: :png, size: 0.22, shape: :circle)

      Qiroex.to_svg!("Hello", level: :h, logo: logo)

  ## Options
    - `:svg` — SVG markup string for the logo (provide this **or** `:image`)
    - `:image` — binary image data for a raster logo (provide this **or** `:svg`)
    - `:image_type` — image format atom: `:png`, `:jpeg`, `:webp`, `:gif`, `:bmp` (required when using `:image`)
    - `:size` — logo size as a fraction of the QR code (0.0–0.4, default: 0.2)
    - `:padding` — padding around the logo in modules (default: 1)
    - `:background` — background color behind the logo (default: `"#ffffff"`)
    - `:shape` — background shape: `:square`, `:rounded`, or `:circle` (default: `:square`)
    - `:border_radius` — corner radius for `:rounded` shape (default: 4)
  """

  @type image_type :: :png | :jpeg | :webp | :gif | :bmp

  @type t :: %__MODULE__{
          svg: String.t() | nil,
          image: binary() | nil,
          image_type: image_type() | nil,
          size: float(),
          padding: non_neg_integer(),
          background: String.t(),
          shape: :square | :rounded | :circle,
          border_radius: number()
        }

  defstruct svg: nil,
            image: nil,
            image_type: nil,
            size: 0.2,
            padding: 1,
            background: "#ffffff",
            shape: :square,
            border_radius: 4

  @valid_image_types [:png, :jpeg, :webp, :gif, :bmp]

  # Safety margin: use 80% of theoretical EC capacity for logo coverage
  @safety_factor 0.80

  @max_coverage %{
    l: 0.07 * @safety_factor,
    m: 0.15 * @safety_factor,
    q: 0.25 * @safety_factor,
    h: 0.30 * @safety_factor
  }

  @doc """
  Creates a new logo configuration.

  Provide either `:svg` (SVG markup string) or `:image` + `:image_type`
  (raster image binary). You cannot provide both.

  ## Options
    - `:svg` — SVG markup string
    - `:image` — binary image data (PNG, JPEG, WEBP, GIF, BMP)
    - `:image_type` — image format: `:png`, `:jpeg`, `:webp`, `:gif`, `:bmp`
    - `:size` — fraction of QR code size (0.0–0.4, default: 0.2)
    - `:padding` — padding in modules around the logo (default: 1)
    - `:background` — CSS color for the background behind the logo (default: `"#ffffff"`)
    - `:shape` — `:square`, `:rounded`, or `:circle` (default: `:square`)
    - `:border_radius` — corner radius for `:rounded` shape (default: 4)
  """
  @spec new(keyword()) :: t()
  def new(opts) do
    svg = Keyword.get(opts, :svg)
    image = Keyword.get(opts, :image)
    image_type = Keyword.get(opts, :image_type)

    # Auto-detect image type from binary magic bytes if not provided
    image_type = if image && is_nil(image_type), do: detect_image_type(image), else: image_type

    logo = %__MODULE__{
      svg: svg,
      image: image,
      image_type: image_type,
      size: Keyword.get(opts, :size, 0.2),
      padding: Keyword.get(opts, :padding, 1),
      background: Keyword.get(opts, :background, "#ffffff"),
      shape: Keyword.get(opts, :shape, :square),
      border_radius: Keyword.get(opts, :border_radius, 4)
    }

    validate!(logo)
    logo
  end

  @doc """
  Calculates the logo placement geometry for the given matrix size and module size.

  Returns a map with:
    - `:logo_px` — logo size in pixels
    - `:clear_px` — cleared area size in pixels (logo + padding)
    - `:logo_x`, `:logo_y` — logo top-left position in SVG coordinates
    - `:clear_x`, `:clear_y` — cleared area top-left position
    - `:clear_modules` — number of modules covered by the cleared area
    - `:clear_start_row`, `:clear_start_col` — first cleared module row/col
    - `:clear_end_row`, `:clear_end_col` — last cleared module row/col (inclusive)
  """
  @spec geometry(t(), non_neg_integer(), non_neg_integer(), non_neg_integer()) :: map()
  def geometry(%__MODULE__{} = logo, matrix_size, module_size, quiet_zone) do
    total_modules = matrix_size + 2 * quiet_zone
    total_px = total_modules * module_size

    # Logo size in pixels
    logo_px = round(total_px * logo.size)
    # Cleared area = logo + padding on each side
    padding_px = logo.padding * module_size
    clear_px = logo_px + 2 * padding_px

    # Center the cleared area
    clear_x = div(total_px - clear_px, 2)
    clear_y = div(total_px - clear_px, 2)

    # Logo position (centered within cleared area)
    logo_x = clear_x + padding_px
    logo_y = clear_y + padding_px

    # Calculate which modules are covered (for clearing/validation)
    clear_start_col = div(clear_x, module_size) - quiet_zone
    clear_start_row = div(clear_y, module_size) - quiet_zone
    clear_end_col = div(clear_x + clear_px - 1, module_size) - quiet_zone
    clear_end_row = div(clear_y + clear_px - 1, module_size) - quiet_zone

    # Clamp to matrix bounds
    clear_start_row = max(clear_start_row, 0)
    clear_start_col = max(clear_start_col, 0)
    clear_end_row = min(clear_end_row, matrix_size - 1)
    clear_end_col = min(clear_end_col, matrix_size - 1)

    rows_covered = clear_end_row - clear_start_row + 1
    cols_covered = clear_end_col - clear_start_col + 1
    clear_modules = rows_covered * cols_covered

    %{
      logo_px: logo_px,
      clear_px: clear_px,
      logo_x: logo_x,
      logo_y: logo_y,
      clear_x: clear_x,
      clear_y: clear_y,
      clear_modules: clear_modules,
      clear_start_row: clear_start_row,
      clear_start_col: clear_start_col,
      clear_end_row: clear_end_row,
      clear_end_col: clear_end_col
    }
  end

  @doc """
  Validates that the logo coverage is safe for the given EC level and matrix size.

  Returns `:ok` or `{:error, reason}`.
  """
  @spec validate_coverage(t(), non_neg_integer(), non_neg_integer(), atom()) ::
          :ok | {:error, String.t()}
  def validate_coverage(%__MODULE__{} = logo, matrix_size, module_size, ec_level) do
    quiet_zone = 4
    geo = geometry(logo, matrix_size, module_size, quiet_zone)
    total_modules = matrix_size * matrix_size
    coverage = geo.clear_modules / total_modules

    max = Map.get(@max_coverage, ec_level, 0.0)

    if coverage <= max do
      :ok
    else
      {:error,
       "Logo covers #{Float.round(coverage * 100, 1)}% of modules, " <>
         "but EC level :#{ec_level} safely supports only #{Float.round(max * 100, 1)}%. " <>
         "Use a higher EC level or a smaller logo size."}
    end
  end

  @doc """
  Returns the set of module positions `{row, col}` that should be cleared
  (made light/transparent) behind the logo.
  """
  @spec cleared_positions(t(), non_neg_integer(), non_neg_integer(), non_neg_integer()) ::
          MapSet.t({non_neg_integer(), non_neg_integer()})
  def cleared_positions(%__MODULE__{} = logo, matrix_size, module_size, quiet_zone) do
    geo = geometry(logo, matrix_size, module_size, quiet_zone)

    for row <- geo.clear_start_row..geo.clear_end_row,
        col <- geo.clear_start_col..geo.clear_end_col,
        into: MapSet.new() do
      {row, col}
    end
  end

  @doc """
  Renders the SVG fragment for the logo (background shape + embedded logo image).

  Supports both SVG logos (nested `<svg>` element) and raster images
  (base64-encoded `<image>` element).

  ## Parameters
    - `logo` — `%Qiroex.Logo{}` struct
    - `geo` — geometry map from `geometry/4`

  ## Returns
    An IO list with the SVG elements for the logo.
  """
  @spec render_svg(t(), map()) :: iolist()
  def render_svg(%__MODULE__{} = logo, geo) do
    bg = render_background(logo, geo)
    embed = render_logo_embed(logo, geo)
    [bg, embed]
  end

  # === Background Shape ===

  defp render_background(logo, geo) do
    case logo.shape do
      :square -> render_bg_square(logo, geo)
      :rounded -> render_bg_rounded(logo, geo)
      :circle -> render_bg_circle(logo, geo)
    end
  end

  defp render_bg_square(logo, geo) do
    [
      ~s(<rect x="),
      to_s(geo.clear_x),
      ~s(" y="),
      to_s(geo.clear_y),
      ~s(" width="),
      to_s(geo.clear_px),
      ~s(" height="),
      to_s(geo.clear_px),
      ~s(" fill="),
      logo.background,
      ~s("/>\n)
    ]
  end

  defp render_bg_rounded(logo, geo) do
    r = to_s(logo.border_radius)

    [
      ~s(<rect x="),
      to_s(geo.clear_x),
      ~s(" y="),
      to_s(geo.clear_y),
      ~s(" width="),
      to_s(geo.clear_px),
      ~s(" height="),
      to_s(geo.clear_px),
      ~s(" rx="),
      r,
      ~s(" ry="),
      r,
      ~s(" fill="),
      logo.background,
      ~s("/>\n)
    ]
  end

  defp render_bg_circle(logo, geo) do
    cx = to_s(geo.clear_x + div(geo.clear_px, 2))
    cy = to_s(geo.clear_y + div(geo.clear_px, 2))
    r = to_s(div(geo.clear_px, 2))

    [
      ~s(<circle cx="),
      cx,
      ~s(" cy="),
      cy,
      ~s(" r="),
      r,
      ~s(" fill="),
      logo.background,
      ~s("/>\n)
    ]
  end

  # === Logo Embed (SVG or raster) ===

  defp render_logo_embed(%__MODULE__{svg: svg} = _logo, geo) when is_binary(svg) do
    # Embed SVG logo using nested <svg> element
    [
      ~s(<svg x="),
      to_s(geo.logo_x),
      ~s(" y="),
      to_s(geo.logo_y),
      ~s(" width="),
      to_s(geo.logo_px),
      ~s(" height="),
      to_s(geo.logo_px),
      ~s(">\n),
      svg,
      ~s(\n),
      ~s(</svg>\n)
    ]
  end

  defp render_logo_embed(%__MODULE__{image: image, image_type: image_type} = _logo, geo)
       when is_binary(image) do
    # Embed raster image using <image> with base64 data URI
    mime = image_type_to_mime(image_type)
    b64 = Base.encode64(image)

    [
      ~s(<image href="data:),
      mime,
      ~s(;base64,),
      b64,
      ~s(" x="),
      to_s(geo.logo_x),
      ~s(" y="),
      to_s(geo.logo_y),
      ~s(" width="),
      to_s(geo.logo_px),
      ~s(" height="),
      to_s(geo.logo_px),
      ~s(" preserveAspectRatio="xMidYMid meet"/>\n)
    ]
  end

  @doc false
  @spec image_type_to_mime(image_type()) :: String.t()
  def image_type_to_mime(:png), do: "image/png"
  def image_type_to_mime(:jpeg), do: "image/jpeg"
  def image_type_to_mime(:webp), do: "image/webp"
  def image_type_to_mime(:gif), do: "image/gif"
  def image_type_to_mime(:bmp), do: "image/bmp"

  # === Image Type Detection ===

  @doc """
  Detects the image format from binary magic bytes.

  Returns the image type atom or `nil` if unrecognized.

  Supported formats: PNG, JPEG, WEBP, GIF, BMP.
  """
  @spec detect_image_type(binary()) :: image_type() | nil
  def detect_image_type(<<0x89, 0x50, 0x4E, 0x47, _::binary>>), do: :png
  def detect_image_type(<<0xFF, 0xD8, 0xFF, _::binary>>), do: :jpeg
  def detect_image_type(<<"RIFF", _size::32, "WEBP", _::binary>>), do: :webp
  def detect_image_type(<<"GIF87a", _::binary>>), do: :gif
  def detect_image_type(<<"GIF89a", _::binary>>), do: :gif
  def detect_image_type(<<"BM", _::binary>>), do: :bmp
  def detect_image_type(_), do: nil

  # === Validation ===

  defp validate!(%__MODULE__{} = logo) do
    validate_source!(logo)

    unless is_number(logo.size) and logo.size > 0 and logo.size <= 0.4 do
      raise ArgumentError,
            "Logo size must be between 0.0 (exclusive) and 0.4 (inclusive), got: #{inspect(logo.size)}"
    end

    unless logo.padding >= 0 do
      raise ArgumentError, "Logo padding must be non-negative, got: #{inspect(logo.padding)}"
    end

    unless logo.shape in [:square, :rounded, :circle] do
      raise ArgumentError,
            "Logo shape must be :square, :rounded, or :circle, got: #{inspect(logo.shape)}"
    end

    :ok
  end

  defp validate_source!(%__MODULE__{svg: nil, image: nil}) do
    raise ArgumentError,
          "Logo requires either :svg (SVG markup string) or :image (binary image data)"
  end

  defp validate_source!(%__MODULE__{svg: svg, image: image})
       when not is_nil(svg) and not is_nil(image) do
    raise ArgumentError,
          "Logo accepts either :svg or :image, not both"
  end

  defp validate_source!(%__MODULE__{svg: svg}) when is_binary(svg) do
    if svg == "" do
      raise ArgumentError, "Logo SVG markup cannot be empty"
    end

    :ok
  end

  defp validate_source!(%__MODULE__{image: image, image_type: image_type})
       when is_binary(image) do
    if byte_size(image) == 0 do
      raise ArgumentError, "Logo image data cannot be empty"
    end

    unless image_type in @valid_image_types do
      raise ArgumentError,
            "Logo image_type must be one of #{inspect(@valid_image_types)}, got: #{inspect(image_type)}. " <>
              "Provide :image_type explicitly or use a supported format (PNG, JPEG, WEBP, GIF, BMP)"
    end

    :ok
  end

  defp to_s(n) when is_integer(n), do: Integer.to_string(n)
  defp to_s(n) when is_float(n), do: Float.to_string(n)
end
