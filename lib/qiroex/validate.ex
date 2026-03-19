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
  @encode_option_keys [:level, :version, :mode, :mask]
  @hex_color_regex ~r/^#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/
  @rgb_color_regex ~r/^rgba?\(\s*.+\)$/i
  @hsl_color_regex ~r/^hsla?\(\s*.+\)$/i
  @css_named_colors MapSet.new([
                      "aliceblue",
                      "antiquewhite",
                      "aqua",
                      "aquamarine",
                      "azure",
                      "beige",
                      "bisque",
                      "black",
                      "blanchedalmond",
                      "blue",
                      "blueviolet",
                      "brown",
                      "burlywood",
                      "cadetblue",
                      "chartreuse",
                      "chocolate",
                      "coral",
                      "cornflowerblue",
                      "cornsilk",
                      "crimson",
                      "currentcolor",
                      "cyan",
                      "darkblue",
                      "darkcyan",
                      "darkgoldenrod",
                      "darkgray",
                      "darkgreen",
                      "darkgrey",
                      "darkkhaki",
                      "darkmagenta",
                      "darkolivegreen",
                      "darkorange",
                      "darkorchid",
                      "darkred",
                      "darksalmon",
                      "darkseagreen",
                      "darkslateblue",
                      "darkslategray",
                      "darkslategrey",
                      "darkturquoise",
                      "darkviolet",
                      "deeppink",
                      "deepskyblue",
                      "dimgray",
                      "dimgrey",
                      "dodgerblue",
                      "firebrick",
                      "floralwhite",
                      "forestgreen",
                      "fuchsia",
                      "gainsboro",
                      "ghostwhite",
                      "gold",
                      "goldenrod",
                      "gray",
                      "green",
                      "greenyellow",
                      "grey",
                      "honeydew",
                      "hotpink",
                      "indianred",
                      "indigo",
                      "ivory",
                      "khaki",
                      "lavender",
                      "lavenderblush",
                      "lawngreen",
                      "lemonchiffon",
                      "lightblue",
                      "lightcoral",
                      "lightcyan",
                      "lightgoldenrodyellow",
                      "lightgray",
                      "lightgreen",
                      "lightgrey",
                      "lightpink",
                      "lightsalmon",
                      "lightseagreen",
                      "lightskyblue",
                      "lightslategray",
                      "lightslategrey",
                      "lightsteelblue",
                      "lightyellow",
                      "lime",
                      "limegreen",
                      "linen",
                      "magenta",
                      "maroon",
                      "mediumaquamarine",
                      "mediumblue",
                      "mediumorchid",
                      "mediumpurple",
                      "mediumseagreen",
                      "mediumslateblue",
                      "mediumspringgreen",
                      "mediumturquoise",
                      "mediumvioletred",
                      "midnightblue",
                      "mintcream",
                      "mistyrose",
                      "moccasin",
                      "navajowhite",
                      "navy",
                      "oldlace",
                      "olive",
                      "olivedrab",
                      "orange",
                      "orangered",
                      "orchid",
                      "palegoldenrod",
                      "palegreen",
                      "paleturquoise",
                      "palevioletred",
                      "papayawhip",
                      "peachpuff",
                      "peru",
                      "pink",
                      "plum",
                      "powderblue",
                      "purple",
                      "rebeccapurple",
                      "red",
                      "rosybrown",
                      "royalblue",
                      "saddlebrown",
                      "salmon",
                      "sandybrown",
                      "seagreen",
                      "seashell",
                      "sienna",
                      "silver",
                      "skyblue",
                      "slateblue",
                      "slategray",
                      "slategrey",
                      "snow",
                      "springgreen",
                      "steelblue",
                      "tan",
                      "teal",
                      "thistle",
                      "tomato",
                      "transparent",
                      "turquoise",
                      "violet",
                      "wheat",
                      "white",
                      "whitesmoke",
                      "yellow",
                      "yellowgreen"
                    ])
  @legacy_option_messages %{
    ec_level: "unsupported option :ec_level. Use :level instead.",
    margin: "unsupported option :margin. Use :quiet_zone instead."
  }

  @doc """
  Validates encoding options.

  Checks:
    - `:level` — must be `:l`, `:m`, `:q`, or `:h`
    - `:version` — must be `:auto` or an integer 1–40
    - `:mode` — must be `:auto`, `:numeric`, `:alphanumeric`, `:byte`, or `:kanji`
    - `:mask` — must be `:auto` or an integer 0–7
  """
  @spec encode_opts(keyword()) :: :ok | {:error, String.t()}
  def encode_opts(opts) do
    with :ok <- option_keys(opts, @encode_option_keys, "encode/2"),
         :ok <- validate_ec_level(opts),
         :ok <- validate_version(opts),
         :ok <- validate_mode(opts) do
      validate_mask(opts)
    end
  end

  @doc """
  Validates matrix render options.

  Checks:
    - `:quiet_zone` — non-negative integer
  """
  @spec matrix_render_opts(keyword()) :: :ok | {:error, String.t()}
  def matrix_render_opts(opts) do
    validate_quiet_zone(opts)
  end

  @doc """
  Validates SVG render options.

  Checks:
    - `:module_size` — positive integer
    - `:quiet_zone` — non-negative integer
    - `:dark_color` / `:light_color` — hex, rgb/rgba, hsl/hsla, or CSS color name string
    - `:style` — `%Qiroex.Style{}` struct or `nil`
    - `:logo` — `%Qiroex.Logo{}` struct or `nil`
    - `:background_image` — `%Qiroex.BackgroundImage{}` struct or `nil`
  """
  @spec svg_render_opts(keyword()) :: :ok | {:error, String.t()}
  def svg_render_opts(opts) do
    with :ok <- validate_module_size(opts),
         :ok <- validate_quiet_zone(opts),
         :ok <- validate_css_color(opts, :dark_color),
         :ok <- validate_css_color(opts, :light_color),
         :ok <- validate_style(opts),
         :ok <- validate_logo(opts) do
      validate_background_image(opts)
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

  @doc false
  @spec option_keys(keyword(), [atom()], String.t(), map()) :: :ok | {:error, String.t()}
  def option_keys(opts, allowed_keys, context, custom_messages \\ %{}) do
    opts
    |> Keyword.keys()
    |> Enum.uniq()
    |> Enum.reduce_while(:ok, fn key, :ok ->
      case option_key_error(key, allowed_keys, context, custom_messages) do
        nil -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  # === EC Level ===

  defp validate_ec_level(opts) do
    level = Keyword.get(opts, :level, :m)

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
      nil ->
        :ok

      c when is_binary(c) ->
        if valid_css_color?(c) do
          :ok
        else
          {:error,
           "invalid #{key}: #{inspect(c)}. Must be a CSS color string in hex, rgb/rgba, hsl/hsla, or a supported named-color form"}
        end

      c ->
        {:error,
         "invalid #{key}: #{inspect(c)}. Must be a CSS color string in hex, rgb/rgba, hsl/hsla, or a supported named-color form"}
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

  # === Background Image ===

  defp validate_background_image(opts) do
    case Keyword.get(opts, :background_image) do
      nil ->
        :ok

      %Qiroex.BackgroundImage{} ->
        :ok

      background_image ->
        {:error,
         "invalid background_image: #{inspect(background_image)}. Must be a %Qiroex.BackgroundImage{} struct or nil"}
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

  defp option_key_error(key, allowed_keys, context, custom_messages) do
    cond do
      key in allowed_keys ->
        nil

      Map.has_key?(@legacy_option_messages, key) ->
        {:error, Map.fetch!(@legacy_option_messages, key)}

      Map.has_key?(custom_messages, key) ->
        {:error, Map.fetch!(custom_messages, key)}

      true ->
        {:error, unknown_option_message(key, allowed_keys, context)}
    end
  end

  defp unknown_option_message(key, allowed_keys, context) do
    suggestion = suggestion_for(key, allowed_keys)

    valid_options =
      allowed_keys
      |> Enum.uniq()
      |> Enum.sort_by(&Atom.to_string/1)
      |> Enum.map_join(", ", &inspect/1)

    suggestion_text =
      case suggestion do
        nil -> ""
        suggested_key -> " Did you mean #{inspect(suggested_key)}?"
      end

    "unknown option #{inspect(key)} for #{context}.#{suggestion_text} Valid options are: #{valid_options}"
  end

  defp suggestion_for(key, allowed_keys) when is_atom(key) do
    key_name = Atom.to_string(key)

    case Enum.max_by(allowed_keys, &String.jaro_distance(key_name, Atom.to_string(&1)), fn ->
           nil
         end) do
      nil ->
        nil

      suggestion ->
        distance = String.jaro_distance(key_name, Atom.to_string(suggestion))

        if distance >= 0.82 do
          suggestion
        else
          nil
        end
    end
  end

  defp suggestion_for(_key, _allowed_keys), do: nil

  defp valid_css_color?(color) do
    trimmed = String.trim(color)
    downcased = String.downcase(trimmed)

    trimmed != "" and
      (Regex.match?(@hex_color_regex, trimmed) or
         Regex.match?(@rgb_color_regex, trimmed) or
         Regex.match?(@hsl_color_regex, trimmed) or
         MapSet.member?(@css_named_colors, downcased))
  end
end
