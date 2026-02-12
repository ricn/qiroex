defmodule Qiroex.Encoder.Byte do
  @moduledoc """
  Byte mode encoder for QR codes.

  Encodes any 8-bit data. Each byte maps directly to 8 bits.
  Default encoding is ISO 8859-1; UTF-8 is commonly auto-detected by readers.
  """

  @doc """
  Encodes binary data into a bitstring.

  ## Parameters
    - `data` - binary string (any bytes)

  ## Returns
    Bitstring of encoded data (without mode indicator or character count).
  """
  @spec encode(binary()) :: bitstring()
  def encode(data) when is_binary(data) do
    # Each byte directly becomes 8 bits - the data itself is the encoding
    data
  end

  @doc "Byte mode accepts any binary data, always returns true."
  @spec valid?(binary()) :: boolean()
  def valid?(data) when is_binary(data), do: true
end
