defmodule Qiroex.Style do
  @moduledoc """
  Visual styling configuration for QR code rendering.

  Provides a declarative way to customize the appearance of generated QR codes
  beyond basic color options. Supports module shapes, finder pattern styling,
  and gradient fills.

  ## Usage

      style = Qiroex.Style.new(
        module_shape: :circle,
        finder: %{outer: "#1a5276", inner: "#ffffff", eye: "#e74c3c"},
        gradient: %{type: :linear, start_color: "#000000", end_color: "#3498db"}
      )

      Qiroex.to_svg("Hello", style: style)

  ## Module Shapes (SVG only)
    - `:square`  — default square modules
    - `:rounded` — squares with rounded corners (uses `module_radius`)
    - `:circle`  — circular dots
    - `:diamond` — rotated 45° squares
    - `:leaf`    — asymmetric rounded corners (two sharp, two rounded)
    - `:shield`  — flat top with curved pointed bottom

  ## Finder Pattern Styling
  Customize the three concentric layers of each finder pattern independently:
    - `:outer` — the 7×7 dark border ring (color: `:outer`, shape: `:outer_shape`)
    - `:inner` — the 5×5 light ring (color: `:inner`, shape: `:inner_shape`)
    - `:eye`   — the 3×3 dark center (color: `:eye`, shape: `:eye_shape`)

  ## Finder Pattern Shapes (SVG only)
  Each finder layer can have its own shape, rendered as a single compound SVG element:
    - `:square`  — sharp-cornered rectangle (default)
    - `:rounded` — rectangle with rounded corners
    - `:circle`  — circle inscribed in the layer area
    - `:diamond` — rotated 45° square
    - `:leaf`    — asymmetric rounded corners
    - `:shield`  — flat top with curved pointed bottom

  ## Gradient Fills (SVG only)
  Apply linear or radial gradients to dark modules. Finder patterns
  use their own colors (or the gradient if no finder colors are set).
  """

  @type gradient :: %{
          type: :linear | :radial,
          start_color: String.t(),
          end_color: String.t(),
          angle: number()
        }

  @type finder_shape :: :square | :rounded | :circle | :diamond | :leaf | :shield

  @type finder :: %{
          optional(:outer) => String.t(),
          optional(:inner) => String.t(),
          optional(:eye) => String.t(),
          optional(:outer_shape) => finder_shape(),
          optional(:inner_shape) => finder_shape(),
          optional(:eye_shape) => finder_shape()
        }

  @type t :: %__MODULE__{
          module_shape: :square | :rounded | :circle | :diamond | :leaf | :shield,
          module_radius: float(),
          finder: finder() | nil,
          gradient: gradient() | nil
        }

  defstruct module_shape: :square,
            module_radius: 0.5,
            finder: nil,
            gradient: nil

  @doc """
  Creates a new style configuration.

  ## Options
    - `:module_shape` — `:square`, `:rounded`, `:circle`, `:diamond`, `:leaf`, or `:shield` (default: `:square`)
    - `:module_radius` — corner radius fraction 0.0–0.5 for `:rounded` shape (default: `0.5`)
    - `:finder` — `%{outer: color, inner: color, eye: color, outer_shape: shape, inner_shape: shape, eye_shape: shape}` or `nil`
    - `:gradient` — `%{type: :linear | :radial, start_color: color, end_color: color}` or `nil`
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    style = %__MODULE__{
      module_shape: Keyword.get(opts, :module_shape, :square),
      module_radius: Keyword.get(opts, :module_radius, 0.5),
      finder: Keyword.get(opts, :finder),
      gradient: Keyword.get(opts, :gradient)
    }

    validate!(style)
    style
  end

  @doc """
  Validates a style struct, raising on invalid values.
  """
  @spec validate!(t()) :: :ok
  def validate!(%__MODULE__{} = style) do
    validate_shape!(style.module_shape)
    validate_radius!(style.module_radius)
    if style.finder, do: validate_finder!(style.finder)
    if style.gradient, do: validate_gradient!(style.gradient)
    :ok
  end

  @doc "Returns `true` if this style only uses default settings (no custom styling)."
  @spec default?(t() | nil) :: boolean()
  def default?(nil), do: true

  def default?(%__MODULE__{} = style) do
    style.module_shape == :square and
      style.finder == nil and
      style.gradient == nil
  end

  @doc "Returns `true` if finder patterns should be rendered with custom colors."
  @spec custom_finder?(t() | nil) :: boolean()
  def custom_finder?(nil), do: false
  def custom_finder?(%__MODULE__{finder: nil}), do: false
  def custom_finder?(%__MODULE__{finder: f}) when is_map(f), do: true

  @doc "Returns `true` if any finder layer has a custom shape configured."
  @spec custom_finder_shapes?(t() | nil) :: boolean()
  def custom_finder_shapes?(nil), do: false
  def custom_finder_shapes?(%__MODULE__{finder: nil}), do: false

  def custom_finder_shapes?(%__MODULE__{finder: finder}) when is_map(finder) do
    Map.has_key?(finder, :outer_shape) or
      Map.has_key?(finder, :inner_shape) or
      Map.has_key?(finder, :eye_shape)
  end

  @doc "Returns the finder color for a specific layer, falling back to the given default."
  @spec finder_color(t() | nil, :outer | :inner | :eye, String.t() | nil) :: String.t() | nil
  def finder_color(nil, _layer, default), do: default
  def finder_color(%__MODULE__{finder: nil}, _layer, default), do: default

  def finder_color(%__MODULE__{finder: finder}, layer, default) do
    Map.get(finder, layer, default)
  end

  @doc "Returns the finder shape for a specific layer, falling back to `:square`."
  @spec finder_shape(t() | nil, :outer | :inner | :eye, finder_shape()) :: finder_shape()
  def finder_shape(nil, _layer, default), do: default
  def finder_shape(%__MODULE__{finder: nil}, _layer, default), do: default

  def finder_shape(%__MODULE__{finder: finder}, layer, default) do
    shape_key =
      case layer do
        :outer -> :outer_shape
        :inner -> :inner_shape
        :eye -> :eye_shape
      end

    Map.get(finder, shape_key, default)
  end

  # === Validation ===

  @valid_shapes [:square, :rounded, :circle, :diamond, :leaf, :shield]
  @valid_finder_shapes [:square, :rounded, :circle, :diamond, :leaf, :shield]

  defp validate_shape!(shape) when shape in @valid_shapes, do: :ok

  defp validate_shape!(shape) do
    raise ArgumentError,
          "invalid module_shape: #{inspect(shape)}. " <>
            "Must be one of #{inspect(@valid_shapes)}"
  end

  defp validate_radius!(r) when is_number(r) and r >= 0 and r <= 0.5, do: :ok

  defp validate_radius!(r) do
    raise ArgumentError,
          "invalid module_radius: #{inspect(r)}. Must be a number between 0.0 and 0.5"
  end

  defp validate_finder!(f) when is_map(f) do
    valid_keys = [:outer, :inner, :eye, :outer_shape, :inner_shape, :eye_shape]
    extra = Map.keys(f) -- valid_keys

    if extra != [] do
      raise ArgumentError,
            "invalid finder keys: #{inspect(extra)}. Allowed: #{inspect(valid_keys)}"
    end

    # Validate shape values
    for key <- [:outer_shape, :inner_shape, :eye_shape], Map.has_key?(f, key) do
      shape = Map.get(f, key)

      unless shape in @valid_finder_shapes do
        raise ArgumentError,
              "invalid finder shape for #{inspect(key)}: #{inspect(shape)}. " <>
                "Must be one of #{inspect(@valid_finder_shapes)}"
      end
    end

    :ok
  end

  defp validate_finder!(f) do
    raise ArgumentError, "finder must be a map, got: #{inspect(f)}"
  end

  defp validate_gradient!(%{type: type} = g) when type in [:linear, :radial] do
    unless Map.has_key?(g, :start_color) and Map.has_key?(g, :end_color) do
      raise ArgumentError,
            "gradient requires :start_color and :end_color"
    end

    :ok
  end

  defp validate_gradient!(%{type: type}) do
    raise ArgumentError,
          "invalid gradient type: #{inspect(type)}. Must be :linear or :radial"
  end

  defp validate_gradient!(g) do
    raise ArgumentError, "gradient must be a map with :type, got: #{inspect(g)}"
  end
end
