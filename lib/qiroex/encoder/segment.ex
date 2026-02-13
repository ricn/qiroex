defmodule Qiroex.Encoder.Segment do
  @moduledoc """
  Segment assembly for QR code data encoding.

  Takes a list of {mode, data} segments and assembles the complete encoded
  bit stream including mode indicators, character counts, encoded data,
  terminator, byte padding, and pad codewords.
  """

  alias Qiroex.Encoder.{Alphanumeric, Byte, Kanji, Numeric}
  alias Qiroex.Spec

  @doc """
  Assembles the complete encoded data codewords from segments.

  ## Parameters
    - `segments` - list of `{mode, data}` tuples
    - `version` - QR code version (1-40)
    - `ec_level` - error correction level

  ## Returns
    List of data codeword integers (0-255).
  """
  @spec encode(list({Spec.mode(), binary()}), Spec.version(), Spec.ec_level()) ::
          list(non_neg_integer())
  def encode(segments, version, ec_level) do
    total_data_codewords = Spec.total_data_codewords(version, ec_level)
    total_data_bits = total_data_codewords * 8

    # Build the bit stream from all segments
    bits =
      Enum.reduce(segments, <<>>, fn {mode, data}, acc ->
        segment_bits = encode_segment(mode, data, version)
        <<acc::bitstring, segment_bits::bitstring>>
      end)

    # Add terminator (up to 4 zero bits, or fewer if at capacity)
    bits_remaining = total_data_bits - bit_size(bits)
    terminator_len = min(4, bits_remaining)
    bits = <<bits::bitstring, 0::size(terminator_len)>>

    # Pad to byte boundary
    pad_to_byte = rem(8 - rem(bit_size(bits), 8), 8)
    bits = <<bits::bitstring, 0::size(pad_to_byte)>>

    # Add pad codewords (alternating 0xEC and 0x11) until we reach total_data_codewords
    current_bytes = div(bit_size(bits), 8)
    remaining_bytes = total_data_codewords - current_bytes

    pad_bytes =
      if remaining_bytes > 0 do
        0..(remaining_bytes - 1)
        |> Enum.map(fn i ->
          if rem(i, 2) == 0, do: 0xEC, else: 0x11
        end)
      else
        []
      end

    bits =
      Enum.reduce(pad_bytes, bits, fn byte, acc ->
        <<acc::bitstring, byte::8>>
      end)

    # Convert bitstring to list of codeword integers
    bitstring_to_codewords(bits)
  end

  @doc """
  Encodes a single segment including mode indicator and character count.

  ## Returns
    Bitstring of the encoded segment.
  """
  @spec encode_segment(Spec.mode(), binary(), Spec.version()) :: bitstring()
  def encode_segment(mode, data, version) do
    mode_indicator = Spec.mode_indicator(mode)
    count_bits = Spec.char_count_bits(mode, version)

    char_count = character_count(mode, data)
    encoded_data = encode_data(mode, data)

    <<mode_indicator::4, char_count::size(count_bits), encoded_data::bitstring>>
  end

  # Count characters for the character count indicator
  defp character_count(:numeric, data), do: String.length(data)
  defp character_count(:alphanumeric, data), do: String.length(data)
  defp character_count(:byte, data), do: byte_size(data)
  defp character_count(:kanji, data), do: Kanji.char_count(data)

  # Encode data using the appropriate mode encoder
  defp encode_data(:numeric, data), do: Numeric.encode(data)
  defp encode_data(:alphanumeric, data), do: Alphanumeric.encode(data)
  defp encode_data(:byte, data), do: Byte.encode(data)
  defp encode_data(:kanji, data), do: Kanji.encode(data)

  # Convert a bitstring to a list of byte integers
  defp bitstring_to_codewords(bits) do
    for <<byte::8 <- bits>>, do: byte
  end
end
