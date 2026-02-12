defmodule Qiroex.Encoder.Kanji do
  @moduledoc """
  Kanji mode encoder for QR codes.

  Encodes Shift JIS double-byte characters. Each character is encoded as 13 bits:
  1. Subtract 0x8140 (for range 0x8140-0x9FFC) or 0xC140 (for range 0xE040-0xEBBF)
  2. Multiply high byte by 0xC0 and add low byte
  3. Encode as 13-bit value
  """

  @doc """
  Encodes Shift JIS encoded binary data into a bitstring using Kanji mode.

  ## Parameters
    - `data` - binary containing Shift JIS encoded characters (2 bytes each)

  ## Returns
    Bitstring of encoded data (without mode indicator or character count).
  """
  @spec encode(binary()) :: bitstring()
  def encode(data) when is_binary(data) do
    encode_bytes(data, <<>>)
  end

  defp encode_bytes(<<>>, acc), do: acc
  defp encode_bytes(<<high, low, rest::binary>>, acc) do
    code = high * 256 + low

    adjusted =
      cond do
        code >= 0x8140 and code <= 0x9FFC ->
          code - 0x8140

        code >= 0xE040 and code <= 0xEBBF ->
          code - 0xC140

        true ->
          raise ArgumentError, "Invalid Shift JIS character: 0x#{Integer.to_string(code, 16)}"
      end

    high_byte = div(adjusted, 256)
    low_byte = rem(adjusted, 256)
    value = high_byte * 0xC0 + low_byte

    encode_bytes(rest, <<acc::bitstring, value::13>>)
  end

  @doc """
  Returns the number of Kanji characters in the Shift JIS binary.
  Each character is 2 bytes.
  """
  @spec char_count(binary()) :: non_neg_integer()
  def char_count(data) when is_binary(data) do
    div(byte_size(data), 2)
  end

  @doc """
  Returns true if the binary contains valid Shift JIS double-byte characters
  that can be encoded in Kanji mode.
  """
  @spec valid?(binary()) :: boolean()
  def valid?(data) when is_binary(data) do
    rem(byte_size(data), 2) == 0 and valid_sjis?(data)
  end

  defp valid_sjis?(<<>>), do: true
  defp valid_sjis?(<<high, low, rest::binary>>) do
    code = high * 256 + low
    ((code >= 0x8140 and code <= 0x9FFC) or (code >= 0xE040 and code <= 0xEBBF)) and
      valid_sjis?(rest)
  end
  defp valid_sjis?(_), do: false
end
