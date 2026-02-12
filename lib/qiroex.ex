defmodule Qiroex do
  @moduledoc """
  QR code generation library for Elixir.

  Generates valid, scannable QR codes supporting all 40 versions,
  4 encoding modes (numeric, alphanumeric, byte, kanji),
  4 error correction levels, and output in SVG, PNG, and terminal formats.

  ## Quick Start

      # Generate a QR code matrix
      {:ok, qr} = Qiroex.encode("Hello, World!")

      # Get as 2D boolean list
      matrix = Qiroex.to_matrix("Hello, World!")
  """

  alias Qiroex.QR

  @doc """
  Encodes data into a QR code.

  ## Options
    - `:ec_level` - error correction level (`:l`, `:m`, `:q`, `:h`). Default: `:m`
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
  Generates a QR code and returns it as a 2D boolean list.
  `true` = dark module, `false` = light module.

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
end
