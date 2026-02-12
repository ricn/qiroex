defmodule Qiroex.ErrorCorrection.BCH do
  @moduledoc """
  BCH (Bose-Chaudhuri-Hocquenghem) encoding for QR code format and version information.

  Format information: BCH(15,5) encoding of EC level + mask pattern.
  Version information: BCH(18,6) encoding of version number (V7+).
  """

  import Bitwise

  alias Qiroex.Spec

  # 0b10100110111 (degree 10)
  @format_generator Spec.format_generator()
  # 0b101010000010010
  @format_mask Spec.format_mask()
  # 0b1111100100101 (degree 12)
  @version_generator Spec.version_generator()

  @doc """
  Encodes format information (EC level + mask pattern) into a 15-bit BCH-encoded value.

  The format information consists of:
  - 2 bits: EC level (L=01, M=00, Q=11, H=10)
  - 3 bits: mask pattern number (0-7)
  - 10 bits: BCH error correction

  The result is XORed with the format mask (101010000010010).

  ## Parameters
    - `ec_level` - error correction level (:l, :m, :q, :h)
    - `mask` - mask pattern number (0-7)

  ## Returns
    15-bit integer representing the format information.
  """
  @spec format_info(Spec.ec_level(), 0..7) :: non_neg_integer()
  def format_info(ec_level, mask) when mask >= 0 and mask <= 7 do
    # Build the 5-bit data: [ec_level(2 bits)][mask(3 bits)]
    data = bsl(Spec.ec_level_bits(ec_level), 3) ||| mask

    # BCH encode: data(5 bits) + 10 error correction bits
    ec_bits = bch_remainder(data, 5, @format_generator, 10)

    # Combine and XOR with mask
    bxor(bsl(data, 10) ||| ec_bits, @format_mask)
  end

  @doc """
  Encodes version information into an 18-bit BCH-encoded value.

  Only applicable for versions 7-40. The version information consists of:
  - 6 bits: version number
  - 12 bits: BCH error correction

  ## Parameters
    - `version` - QR code version (7-40)

  ## Returns
    18-bit integer representing the version information.
  """
  @spec version_info(7..40) :: non_neg_integer()
  def version_info(version) when version >= 7 and version <= 40 do
    ec_bits = bch_remainder(version, 6, @version_generator, 12)
    bsl(version, 12) ||| ec_bits
  end

  @doc """
  Returns the format information as a list of 15 bits (MSB first).
  """
  @spec format_info_bits(Spec.ec_level(), 0..7) :: list(0 | 1)
  def format_info_bits(ec_level, mask) do
    value = format_info(ec_level, mask)
    for i <- 14..0//-1, do: band(bsr(value, i), 1)
  end

  @doc """
  Returns the version information as a list of 18 bits (MSB first).
  """
  @spec version_info_bits(7..40) :: list(0 | 1)
  def version_info_bits(version) do
    value = version_info(version)
    for i <- 17..0//-1, do: band(bsr(value, i), 1)
  end

  # Compute BCH remainder (error correction bits)
  # data: the data value
  # data_bits: number of bits in data
  # generator: the generator polynomial as integer
  # ec_bits: number of error correction bits to produce
  defp bch_remainder(data, data_bits, generator, ec_bits) do
    # Shift data left by ec_bits positions
    value = bsl(data, ec_bits)

    # Generator polynomial bit length
    gen_len = bit_length(generator)

    # XOR division
    Enum.reduce((data_bits + ec_bits - 1)..0//-1, value, fn i, acc ->
      if band(bsr(acc, i), 1) == 1 and i >= gen_len - 1 do
        bxor(acc, bsl(generator, i - gen_len + 1))
      else
        acc
      end
    end)
  end

  defp bit_length(0), do: 0

  defp bit_length(n) when n > 0 do
    :math.log2(n) |> floor() |> Kernel.+(1)
  end
end
