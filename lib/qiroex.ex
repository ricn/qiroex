defmodule Qiroex do
  @moduledoc """
  Pure-Elixir QR code generation library with zero dependencies.

  Generates valid, scannable QR codes supporting all 40 versions,
  4 encoding modes (numeric, alphanumeric, byte, kanji),
  4 error correction levels (L/M/Q/H), and output in SVG, PNG, and
  terminal formats.

  ## Quick Start

      # Generate a QR code struct
      {:ok, qr} = Qiroex.encode("Hello, World!")

      # Render as SVG string
      {:ok, svg} = Qiroex.to_svg("Hello, World!")

      # Render as PNG binary
      {:ok, png} = Qiroex.to_png("Hello, World!")

      # Print to terminal
      Qiroex.print("Hello, World!")

  ## Encoding Options

  All rendering functions accept encoding options as well:

    - `:level` / `:ec_level` — error correction level (`:l`, `:m`, `:q`, `:h`). Default: `:m`
    - `:version` — force a specific version (1–40) or `:auto`. Default: `:auto`
    - `:mode` — force encoding mode (`:numeric`, `:alphanumeric`, `:byte`, `:kanji`)
      or `:auto`. Default: `:auto`
    - `:mask` — force mask pattern (0–7) or `:auto`. Default: `:auto`

  ## Styling

  Customize QR code appearance with the `Qiroex.Style` struct:

      style = Qiroex.Style.new(module_shape: :circle)
      {:ok, svg} = Qiroex.to_svg("Hello", style: style)

  ## Logos

  Embed an SVG logo in the center of the code (SVG output only):

      logo = Qiroex.Logo.new(svg: "<svg>...</svg>", size: 0.2)
      {:ok, svg} = Qiroex.to_svg("Hello", level: :h, logo: logo)

  ## Payload Helpers

  Generate structured QR payloads (WiFi, vCard, etc.) in one step:

      {:ok, svg} = Qiroex.payload(:wifi, [ssid: "Net", password: "pass"], :svg)
  """

  alias Qiroex.{QR, Validate}
  alias Qiroex.Render.{SVG, PNG, Terminal}

  @svg_render_keys [:module_size, :quiet_zone, :dark_color, :light_color, :style, :logo]
  @png_render_keys [:module_size, :quiet_zone, :dark_color, :light_color, :style]
  @terminal_render_keys [:quiet_zone, :compact]

  # ─── Encode ──────────────────────────────────────────────────────────

  @doc """
  Encodes data into a QR code struct.

  ## Options

    - `:level` / `:ec_level` — error correction level (`:l`, `:m`, `:q`, `:h`). Default: `:m`
    - `:version` — force a specific version (1–40) or `:auto`. Default: `:auto`
    - `:mode` — force encoding mode or `:auto`. Default: `:auto`
    - `:mask` — force mask pattern (0–7) or `:auto`. Default: `:auto`

  ## Examples

      {:ok, qr} = Qiroex.encode("Hello")
      {:ok, qr} = Qiroex.encode("12345", level: :h, mode: :numeric)
      {:error, _} = Qiroex.encode("")

  ## Returns

    `{:ok, %Qiroex.QR{}}` or `{:error, reason}`
  """
  @spec encode(binary(), keyword()) :: {:ok, QR.t()} | {:error, String.t()}
  def encode(data, opts \\ []) do
    with :ok <- Validate.encode_opts(opts) do
      QR.encode(data, opts)
    end
  end

  @doc """
  Encodes data into a QR code struct, raising on error.

  Same options as `encode/2`. Raises `ArgumentError` on invalid data or options.
  """
  @spec encode!(binary(), keyword()) :: QR.t()
  def encode!(data, opts \\ []) do
    case encode(data, opts) do
      {:ok, qr} -> qr
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  # ─── Matrix ─────────────────────────────────────────────────────────

  @doc """
  Generates a QR code and returns it as a 2D list of 0s and 1s.

  ## Options

  Same as `encode/2`, plus:

    - `:margin` — quiet zone size in modules. Default: 4

  ## Examples

      {:ok, rows} = Qiroex.to_matrix("Hi")
      length(rows) # => matrix size + 2 * margin
  """
  @spec to_matrix(binary(), keyword()) :: {:ok, list(list(0 | 1))} | {:error, String.t()}
  def to_matrix(data, opts \\ []) do
    margin = Keyword.get(opts, :margin, 4)

    case encode(data, opts) do
      {:ok, qr} -> {:ok, QR.to_matrix(qr, margin)}
      error -> error
    end
  end

  @doc """
  Generates a QR code matrix, raising on error.

  Same options as `to_matrix/2`.
  """
  @spec to_matrix!(binary(), keyword()) :: list(list(0 | 1))
  def to_matrix!(data, opts \\ []) do
    margin = Keyword.get(opts, :margin, 4)
    qr = encode!(data, opts)
    QR.to_matrix(qr, margin)
  end

  # ─── SVG ─────────────────────────────────────────────────────────────

  @doc """
  Generates a QR code and renders it as an SVG string.

  ## Options

  Same as `encode/2`, plus:

    - `:module_size` — pixel size of each module (default: 10)
    - `:quiet_zone` — quiet zone modules (default: 4)
    - `:dark_color` — CSS color for dark modules (default: `"#000000"`)
    - `:light_color` — CSS color for background (default: `"#ffffff"`)
    - `:style` — a `%Qiroex.Style{}` struct for shapes, finder colors, gradients
    - `:logo` — a `%Qiroex.Logo{}` struct for center logo embedding

  ## Examples

      {:ok, svg} = Qiroex.to_svg("Hello")
      {:ok, svg} = Qiroex.to_svg("Hello", dark_color: "#336699", module_size: 5)

  ## Returns

    `{:ok, svg_string}` or `{:error, reason}`
  """
  @spec to_svg(binary(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def to_svg(data, opts \\ []) do
    {render_opts, encode_opts} = split_render_opts(opts, @svg_render_keys)

    with :ok <- Validate.svg_render_opts(render_opts),
         {:ok, qr} <- encode(data, encode_opts),
         :ok <- validate_logo_coverage(render_opts, qr) do
      {:ok, SVG.render(qr.matrix, render_opts)}
    end
  end

  @doc """
  Generates a QR code SVG string, raising on error.

  Same options as `to_svg/2`.
  """
  @spec to_svg!(binary(), keyword()) :: String.t()
  def to_svg!(data, opts \\ []) do
    case to_svg(data, opts) do
      {:ok, svg} -> svg
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  # ─── PNG ─────────────────────────────────────────────────────────────

  @doc """
  Generates a QR code and renders it as a PNG binary.

  ## Options

  Same as `encode/2`, plus:

    - `:module_size` — pixel size of each module (default: 10)
    - `:quiet_zone` — quiet zone modules (default: 4)
    - `:dark_color` — `{r, g, b}` tuple with values 0–255 (default: `{0, 0, 0}`)
    - `:light_color` — `{r, g, b}` tuple with values 0–255 (default: `{255, 255, 255}`)
    - `:style` — a `%Qiroex.Style{}` struct for finder pattern colors

  ## Examples

      {:ok, png} = Qiroex.to_png("Hello")
      {:ok, png} = Qiroex.to_png("Hello", module_size: 20)

  ## Returns

    `{:ok, png_binary}` or `{:error, reason}`
  """
  @spec to_png(binary(), keyword()) :: {:ok, binary()} | {:error, String.t()}
  def to_png(data, opts \\ []) do
    {render_opts, encode_opts} = split_render_opts(opts, @png_render_keys)

    with :ok <- Validate.png_render_opts(render_opts),
         {:ok, qr} <- encode(data, encode_opts) do
      {:ok, PNG.render(qr.matrix, render_opts)}
    end
  end

  @doc """
  Generates a QR code PNG binary, raising on error.

  Same options as `to_png/2`.
  """
  @spec to_png!(binary(), keyword()) :: binary()
  def to_png!(data, opts \\ []) do
    case to_png(data, opts) do
      {:ok, png} -> png
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  # ─── File Saving ─────────────────────────────────────────────────────

  @doc """
  Generates a QR code SVG and writes it to a file.

  ## Options

  Same as `to_svg/2`.

  ## Examples

      :ok = Qiroex.save_svg("Hello", "/tmp/hello.svg")
      :ok = Qiroex.save_svg("Hello", "/tmp/hello.svg", dark_color: "#003366")

  ## Returns

    `:ok` or `{:error, reason}`
  """
  @spec save_svg(binary(), Path.t(), keyword()) :: :ok | {:error, term()}
  def save_svg(data, path, opts \\ []) do
    case to_svg(data, opts) do
      {:ok, svg} -> File.write(path, svg)
      error -> error
    end
  end

  @doc """
  Generates a QR code PNG and writes it to a file.

  ## Options

  Same as `to_png/2`.

  ## Examples

      :ok = Qiroex.save_png("Hello", "/tmp/hello.png")
      :ok = Qiroex.save_png("Hello", "/tmp/hello.png", module_size: 20)

  ## Returns

    `:ok` or `{:error, reason}`
  """
  @spec save_png(binary(), Path.t(), keyword()) :: :ok | {:error, term()}
  def save_png(data, path, opts \\ []) do
    case to_png(data, opts) do
      {:ok, png} -> File.write(path, png)
      error -> error
    end
  end

  # ─── Terminal ────────────────────────────────────────────────────────

  @doc """
  Generates a QR code and renders it as a terminal-printable string.

  ## Options

  Same as `encode/2`, plus:

    - `:quiet_zone` — quiet zone modules (default: 4)
    - `:compact` — use compact 2-row-per-line rendering (default: `true`)

  ## Examples

      {:ok, str} = Qiroex.to_terminal("Hello")

  ## Returns

    `{:ok, terminal_string}` or `{:error, reason}`
  """
  @spec to_terminal(binary(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def to_terminal(data, opts \\ []) do
    {render_opts, encode_opts} = split_render_opts(opts, @terminal_render_keys)

    with :ok <- Validate.terminal_render_opts(render_opts),
         {:ok, qr} <- encode(data, encode_opts) do
      {:ok, Terminal.render(qr.matrix, render_opts)}
    end
  end

  @doc """
  Generates a QR code terminal string, raising on error.

  Same options as `to_terminal/2`.
  """
  @spec to_terminal!(binary(), keyword()) :: String.t()
  def to_terminal!(data, opts \\ []) do
    case to_terminal(data, opts) do
      {:ok, str} -> str
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @doc """
  Generates a QR code and prints it directly to the terminal.

  Same options as `to_terminal/2`.

  ## Examples

      Qiroex.print("Hello")
      Qiroex.print("Hello", compact: false)
  """
  @spec print(binary(), keyword()) :: :ok
  def print(data, opts \\ []) do
    str = to_terminal!(data, opts)
    IO.puts(str)
  end

  # ─── Payload Helpers ─────────────────────────────────────────────────

  @doc """
  Encodes a structured payload and generates a QR code in one step.

  ## Parameters

    - `type` — payload type atom (`:wifi`, `:url`, `:email`, `:sms`, `:phone`, `:geo`,
      `:vcard`, `:vevent`, `:mecard`, `:bitcoin`, `:whatsapp`)
    - `payload_opts` — keyword list of payload-specific options
    - `format` — output format (`:svg`, `:png`, `:terminal`, `:matrix`, `:encode`)
    - `render_opts` — keyword list of render/encode options (optional)

  ## Examples

      {:ok, svg} = Qiroex.payload(:wifi, [ssid: "MyNet", password: "secret"], :svg)
      {:ok, png} = Qiroex.payload(:url, [url: "https://elixir-lang.org"], :png)
      {:ok, svg} = Qiroex.payload(:vcard, [first_name: "Jane", last_name: "Doe"], :svg)

  ## Returns

    `{:ok, result}` or `{:error, reason}`
  """
  @spec payload(atom(), keyword(), atom(), keyword()) ::
          {:ok, term()} | {:error, String.t()}
  def payload(type, payload_opts, format, render_opts \\ []) do
    with :ok <- Validate.payload_format(format),
         {:ok, data} <- build_payload(type, payload_opts) do
      case format do
        :svg -> to_svg(data, render_opts)
        :png -> to_png(data, render_opts)
        :terminal -> to_terminal(data, render_opts)
        :matrix -> to_matrix(data, render_opts)
        :encode -> encode(data, render_opts)
      end
    end
  end

  @doc """
  Same as `payload/4` but raises on error.
  """
  @spec payload!(atom(), keyword(), atom(), keyword()) :: term()
  def payload!(type, payload_opts, format, render_opts \\ []) do
    case payload(type, payload_opts, format, render_opts) do
      {:ok, result} -> result
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  # ─── Introspection ──────────────────────────────────────────────────

  @doc """
  Returns metadata about an encoded QR code.

  ## Examples

      {:ok, qr} = Qiroex.encode("Hello")
      Qiroex.info(qr)
      # => %{version: 1, ec_level: :m, mode: :byte, mask: 4,
      #      modules: 21, data_bytes: 5}
  """
  @spec info(QR.t()) :: map()
  def info(%QR{} = qr) do
    size = qr.matrix.size

    %{
      version: qr.version,
      ec_level: qr.ec_level,
      mode: qr.mode,
      mask: qr.mask,
      modules: size,
      data_bytes: byte_size(qr.data)
    }
  end

  # ─── Private ─────────────────────────────────────────────────────────

  @payload_modules %{
    wifi: Qiroex.Payload.WiFi,
    url: Qiroex.Payload.URL,
    email: Qiroex.Payload.Email,
    sms: Qiroex.Payload.SMS,
    phone: Qiroex.Payload.Phone,
    geo: Qiroex.Payload.Geo,
    vcard: Qiroex.Payload.VCard,
    vevent: Qiroex.Payload.VEvent,
    mecard: Qiroex.Payload.MeCard,
    bitcoin: Qiroex.Payload.Bitcoin,
    whatsapp: Qiroex.Payload.WhatsApp
  }

  defp build_payload(type, opts) do
    case Map.fetch(@payload_modules, type) do
      {:ok, module} -> module.encode(opts)
      :error -> {:error, "unknown payload type: #{inspect(type)}. Valid types: #{inspect(Map.keys(@payload_modules))}"}
    end
  end

  defp split_render_opts(opts, render_keys) do
    Keyword.split(opts, render_keys)
  end

  defp validate_logo_coverage(render_opts, qr) do
    case Keyword.get(render_opts, :logo) do
      nil ->
        :ok

      %Qiroex.Logo{} = logo ->
        module_size = Keyword.get(render_opts, :module_size, 10)
        Qiroex.Logo.validate_coverage(logo, qr.matrix.size, module_size, qr.ec_level)
    end
  end
end
