defmodule Qiroex do
  @moduledoc """
  QR code generation library for Elixir.

  Generates valid, scannable QR codes supporting all 40 versions,
  4 encoding modes (numeric, alphanumeric, byte, kanji),
  4 error correction levels, and output in SVG, PNG, and terminal formats.

  ## Quick Start

      # Generate a QR code
      {:ok, qr} = Qiroex.encode("Hello, World!")

      # Render as SVG
      svg = Qiroex.to_svg("Hello, World!")

      # Render as PNG binary
      png = Qiroex.to_png("Hello, World!")

      # Print to terminal
      Qiroex.print("Hello, World!")
  """

  alias Qiroex.QR
  alias Qiroex.Render.{SVG, PNG, Terminal}

  @svg_render_keys [:module_size, :quiet_zone, :dark_color, :light_color, :style, :logo]
  @png_render_keys [:module_size, :quiet_zone, :dark_color, :light_color, :style]

  @doc """
  Encodes data into a QR code.

  ## Options
    - `:level` / `:ec_level` - error correction level (`:l`, `:m`, `:q`, `:h`). Default: `:m`
    - `:version` - force a specific version (1-40) or `:auto`. Default: `:auto`
    - `:mode` - force encoding mode or `:auto`. Default: `:auto`
    - `:mask` - force mask pattern (0-7) or `:auto`. Default: `:auto`

  ## Returns
    `{:ok, %Qiroex.QR{}}` or `{:error, reason}`
  """
  @spec encode(binary(), keyword()) :: {:ok, QR.t()} | {:error, String.t()}
  defdelegate encode(data, opts \\ []), to: QR

  @doc "Encodes data into a QR code, raising on error."
  @spec encode!(binary(), keyword()) :: QR.t()
  defdelegate encode!(data, opts \\ []), to: QR

  @doc """
  Generates a QR code and returns it as a 2D list of 0s and 1s.

  ## Options
    Same as `encode/2`, plus:
    - `:margin` - quiet zone size in modules. Default: 4
  """
  @spec to_matrix(binary(), keyword()) :: {:ok, list(list(0 | 1))} | {:error, String.t()}
  def to_matrix(data, opts \\ []) do
    margin = Keyword.get(opts, :margin, 4)

    case QR.encode(data, opts) do
      {:ok, qr} -> {:ok, QR.to_matrix(qr, margin)}
      error -> error
    end
  end

  @doc "Generates a QR code matrix, raising on error."
  @spec to_matrix!(binary(), keyword()) :: list(list(0 | 1))
  def to_matrix!(data, opts \\ []) do
    margin = Keyword.get(opts, :margin, 4)
    qr = QR.encode!(data, opts)
    QR.to_matrix(qr, margin)
  end

  # === SVG ===

  @doc """
  Generates a QR code and renders it as an SVG string.

  ## Options
    Same as `encode/2`, plus:
    - `:module_size` - pixel size of each module (default: 10)
    - `:quiet_zone` - quiet zone modules (default: 4)
    - `:dark_color` - CSS color for dark modules (default: `"#000000"`)
    - `:light_color` - CSS color for background (default: `"#ffffff"`)

  ## Returns
    SVG string or `{:error, reason}`.
  """
  @spec to_svg(binary(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def to_svg(data, opts \\ []) do
    {render_opts, encode_opts} = split_render_opts(opts, @svg_render_keys)

    case QR.encode(data, encode_opts) do
      {:ok, qr} -> {:ok, SVG.render(qr.matrix, render_opts)}
      error -> error
    end
  end

  @doc "Generates a QR code SVG string, raising on error."
  @spec to_svg!(binary(), keyword()) :: String.t()
  def to_svg!(data, opts \\ []) do
    {render_opts, encode_opts} = split_render_opts(opts, @svg_render_keys)
    qr = QR.encode!(data, encode_opts)
    SVG.render(qr.matrix, render_opts)
  end

  # === PNG ===

  @doc """
  Generates a QR code and renders it as a PNG binary.

  ## Options
    Same as `encode/2`, plus:
    - `:module_size` - pixel size of each module (default: 10)
    - `:quiet_zone` - quiet zone modules (default: 4)
    - `:dark_color` - `{r, g, b}` tuple 0-255 (default: `{0, 0, 0}`)
    - `:light_color` - `{r, g, b}` tuple 0-255 (default: `{255, 255, 255}`)

  ## Returns
    PNG binary or `{:error, reason}`.
  """
  @spec to_png(binary(), keyword()) :: {:ok, binary()} | {:error, String.t()}
  def to_png(data, opts \\ []) do
    {render_opts, encode_opts} = split_render_opts(opts, @png_render_keys)

    case QR.encode(data, encode_opts) do
      {:ok, qr} -> {:ok, PNG.render(qr.matrix, render_opts)}
      error -> error
    end
  end

  @doc "Generates a QR code PNG binary, raising on error."
  @spec to_png!(binary(), keyword()) :: binary()
  def to_png!(data, opts \\ []) do
    {render_opts, encode_opts} = split_render_opts(opts, @png_render_keys)
    qr = QR.encode!(data, encode_opts)
    PNG.render(qr.matrix, render_opts)
  end

  @doc """
  Generates a QR code PNG and writes it to a file.

  ## Returns
    `:ok` or `{:error, reason}`
  """
  @spec save_png(binary(), Path.t(), keyword()) :: :ok | {:error, term()}
  def save_png(data, path, opts \\ []) do
    {render_opts, encode_opts} = split_render_opts(opts, @png_render_keys)
    qr = QR.encode!(data, encode_opts)
    PNG.save(qr.matrix, path, render_opts)
  end

  @doc """
  Generates a QR code SVG and writes it to a file.

  ## Returns
    `:ok` or `{:error, reason}`
  """
  @spec save_svg(binary(), Path.t(), keyword()) :: :ok | {:error, term()}
  def save_svg(data, path, opts \\ []) do
    {render_opts, encode_opts} = split_render_opts(opts, @svg_render_keys)
    qr = QR.encode!(data, encode_opts)
    svg = SVG.render(qr.matrix, render_opts)
    File.write(path, svg)
  end

  # === Terminal ===

  @doc """
  Generates a QR code and renders it as a terminal string.

  ## Options
    Same as `encode/2`, plus:
    - `:quiet_zone` - quiet zone modules (default: 4)
    - `:compact` - use compact 2-row-per-line rendering (default: `true`)
  """
  @spec to_terminal(binary(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def to_terminal(data, opts \\ []) do
    {render_opts, encode_opts} = split_render_opts(opts, [:quiet_zone, :compact])

    case QR.encode(data, encode_opts) do
      {:ok, qr} -> {:ok, Terminal.render(qr.matrix, render_opts)}
      error -> error
    end
  end

  @doc "Generates a QR code and prints it directly to the terminal."
  @spec print(binary(), keyword()) :: :ok
  def print(data, opts \\ []) do
    {render_opts, encode_opts} = split_render_opts(opts, [:quiet_zone, :compact])
    qr = QR.encode!(data, encode_opts)
    Terminal.print(qr.matrix, render_opts)
  end

  # Split options into render-specific and encode options
  defp split_render_opts(opts, render_keys) do
    {render_opts, encode_opts} = Keyword.split(opts, render_keys)
    {render_opts, encode_opts}
  end

  # === Payload Helpers ===

  @doc """
  Encodes a payload and generates a QR code in one step.

  ## Examples

      # WiFi
      {:ok, svg} = Qiroex.payload(:wifi, [ssid: "MyNet", password: "secret"], :svg)

      # vCard
      {:ok, png} = Qiroex.payload(:vcard, [first_name: "Jane", last_name: "Doe", phone: "+1234567890"], :png)

      # URL
      {:ok, svg} = Qiroex.payload(:url, [url: "https://elixir-lang.org"], :svg)

  ## Parameters
    - `type` - payload type atom (`:wifi`, `:url`, `:email`, `:sms`, `:phone`, `:geo`,
      `:vcard`, `:vevent`, `:mecard`, `:bitcoin`, `:whatsapp`)
    - `payload_opts` - keyword list of payload-specific options
    - `format` - output format (`:svg`, `:png`, `:terminal`, `:matrix`, `:encode`)
    - `render_opts` - keyword list of render/encode options (optional)
  """
  @spec payload(atom(), keyword(), atom(), keyword()) ::
          {:ok, term()} | {:error, String.t()}
  def payload(type, payload_opts, format, render_opts \\ []) do
    with {:ok, data} <- build_payload(type, payload_opts) do
      case format do
        :svg -> to_svg(data, render_opts)
        :png -> to_png(data, render_opts)
        :terminal -> to_terminal(data, render_opts)
        :matrix -> to_matrix(data, render_opts)
        :encode -> encode(data, render_opts)
        other -> {:error, "Unknown format: #{inspect(other)}"}
      end
    end
  end

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
      :error -> {:error, "Unknown payload type: #{inspect(type)}"}
    end
  end
end
