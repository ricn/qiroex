defmodule Qiroex.Validate do
  @moduledoc """
  Input validation for QR code options and parameters.

  Provides consistent, descriptive error messages for all public-facing
  option validation. Used internally by `Qiroex`, `Qiroex.QR`, and
  renderer modules to catch misconfigurations early.
  """

  @valid_ec_levels [:l, :m, :q, :h]
  @valid_modes [:numeric, :alphanumeric, :byte, :kanji, :auto]
  @valid_shapes [:square, :rounded, :circle, :diamond]

  @doc """
  Validates encoding options, returning the normalized keyword list or an error.

  Checks:
    - `:level` / `:ec_level` — must be `:l`, `:m`, `:q`, or `:h`
    - `:version` — must be `:auto` or an integer 1–40
    - `:mode` — must be `:auto`, `:numeric`, `:alphanumeric`, `:byte`, or `:kanji`
    - `:mask` — must be `:auto` or an integer 0–7
  """
  @spec encode_opts(keyword()) :: :ok | {:error, String.t()}
  def encode_opts(opts) do
    with :ok <- validate_ec_level(opts),
         :ok <- validate_version(opts),
         :ok <- validate_mode(opts) do
      validate_mask(opts)
    end
  end

  @doc """
  Validates SVG render options.

  Checks:
    - `:module_size` — positive integer
    - `:quiet_zone` — non-negative integer
    - `:dark_color` / `:light_color` — non-empty string
    - `:style` — `%Qiroex.Style{}` struct or `nil`
    - `:logo` — `%Qiroex.Logo{}` struct or `nil`
  """
  @spec svg_render_opts(keyword()) :: :ok | {:error, String.t()}
  def svg_render_opts(opts) do
    with :ok <- validate_module_size(opts),
         :ok <- validate_quiet_zone(opts),
         :ok <- validate_css_color(opts, :dark_color),
         :ok <- validate_css_color(opts, :light_color),
         :ok <- validate_style(opts) do
      validate_logo(opts)
    end
  end

  @doc """
  Validates PNG render options.

  Checks:
    - `:module_size` — positive integer
    - `:quiet_zone` — non-negative integer
    - `:dark_color` / `:light_color` — `{r, g, b}` tuples (0–255)
    - `:style` — `%Qiroex.Style{}` struct or `nil`
  """
  @spec png_render_opts(keyword()) :: :ok | {:error, String.t()}
  def png_render_opts(opts) do
    with :ok <- validate_module_size(opts),
         :ok <- validate_quiet_zone(opts),
         :ok <- validate_rgb_color(opts, :dark_color),
         :ok <- validate_rgb_color(opts, :light_color) do
      validate_style(opts)
    end
  end

  @doc """
  Validates terminal render options.

  Checks:
    - `:quiet_zone` — non-negative integer
    - `:compact` — boolean
  """
  @spec terminal_render_opts(keyword()) :: :ok | {:error, String.t()}
  def terminal_render_opts(opts) do
    with :ok <- validate_quiet_zone(opts) do
      validate_compact(opts)
    end
  end

  @doc """
  Validates payload format atom.
  """
  @spec payload_format(atom()) :: :ok | {:error, String.t()}
  def payload_format(format) when format in [:svg, :png, :terminal, :matrix, :encode], do: :ok

  def payload_format(format) do
    {:error,
     "invalid format: #{inspect(format)}. " <>
       "Must be one of :svg, :png, :terminal, :matrix, or :encode"}
  end

  # === EC Level ===

  defp validate_ec_level(opts) do
    level = Keyword.get(opts, :level, Keyword.get(opts, :ec_level, :m))

    if level in @valid_ec_levels do
      :ok
    else
      {:error,
       "invalid error correction level: #{inspect(level)}. " <>
         "Must be one of #{inspect(@valid_ec_levels)}"}
    end
  end

  # === Version ===

  defp validate_version(opts) do
    case Keyword.get(opts, :version, :auto) do
      :auto ->
        :ok

      v when is_integer(v) and v >= 1 and v <= 40 ->
        :ok

      v ->
        {:error,
         "invalid version: #{inspect(v)}. " <>
           "Must be :auto or an integer from 1 to 40"}
    end
  end

  # === Mode ===

  defp validate_mode(opts) do
    mode = Keyword.get(opts, :mode, :auto)

    if mode in @valid_modes do
      :ok
    else
      {:error,
       "invalid mode: #{inspect(mode)}. " <>
         "Must be one of #{inspect(@valid_modes)}"}
    end
  end

  # === Mask ===

  defp validate_mask(opts) do
    case Keyword.get(opts, :mask, :auto) do
      :auto ->
        :ok

      m when is_integer(m) and m >= 0 and m <= 7 ->
        :ok

      m ->
        {:error,
         "invalid mask: #{inspect(m)}. " <>
           "Must be :auto or an integer from 0 to 7"}
    end
  end

  # === Module Size ===

  defp validate_module_size(opts) do
    case Keyword.get(opts, :module_size) do
      nil ->
        :ok

      s when is_integer(s) and s > 0 ->
        :ok

      s ->
        {:error, "invalid module_size: #{inspect(s)}. Must be a positive integer"}
    end
  end

  # === Quiet Zone ===

  defp validate_quiet_zone(opts) do
    case Keyword.get(opts, :quiet_zone) do
      nil ->
        :ok

      q when is_integer(q) and q >= 0 ->
        :ok

      q ->
        {:error, "invalid quiet_zone: #{inspect(q)}. Must be a non-negative integer"}
    end
  end

  # === CSS Color ===

  defp validate_css_color(opts, key) do
    case Keyword.get(opts, key) do
      nil -> :ok
      c when is_binary(c) and byte_size(c) > 0 -> :ok
      c -> {:error, "invalid #{key}: #{inspect(c)}. Must be a CSS color string"}
    end
  end

  # === RGB Color Tuple ===

  defp validate_rgb_color(opts, key) do
    case Keyword.get(opts, key) do
      nil ->
        :ok

      {r, g, b}
      when is_integer(r) and r >= 0 and r <= 255 and
             is_integer(g) and g >= 0 and g <= 255 and
             is_integer(b) and b >= 0 and b <= 255 ->
        :ok

      c ->
        {:error,
         "invalid #{key}: #{inspect(c)}. " <>
           "Must be an {r, g, b} tuple with values 0–255"}
    end
  end

  # === Style ===

  defp validate_style(opts) do
    case Keyword.get(opts, :style) do
      nil -> :ok
      %Qiroex.Style{} -> :ok
      s -> {:error, "invalid style: #{inspect(s)}. Must be a %Qiroex.Style{} struct or nil"}
    end
  end

  # === Logo ===

  defp validate_logo(opts) do
    case Keyword.get(opts, :logo) do
      nil -> :ok
      %Qiroex.Logo{} -> :ok
      l -> {:error, "invalid logo: #{inspect(l)}. Must be a %Qiroex.Logo{} struct or nil"}
    end
  end

  # === Compact ===

  defp validate_compact(opts) do
    case Keyword.get(opts, :compact) do
      nil -> :ok
      b when is_boolean(b) -> :ok
      c -> {:error, "invalid compact: #{inspect(c)}. Must be a boolean"}
    end
  end

  @doc """
  Validates module shape for styled rendering.
  """
  @spec module_shape(atom()) :: :ok | {:error, String.t()}
  def module_shape(shape) when shape in @valid_shapes, do: :ok

  def module_shape(shape) do
    {:error,
     "invalid module_shape: #{inspect(shape)}. " <>
       "Must be one of #{inspect(@valid_shapes)}"}
  end
end
