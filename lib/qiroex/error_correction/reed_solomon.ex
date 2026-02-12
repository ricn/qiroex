defmodule Qiroex.ErrorCorrection.ReedSolomon do
  @moduledoc """
  Reed-Solomon error correction encoding for QR codes.

  Generates error correction codewords by performing polynomial division
  in GF(2⁸). The message polynomial is divided by the generator polynomial,
  and the remainder becomes the error correction codewords.
  """

  alias Qiroex.ErrorCorrection.GaloisField, as: GF

  @doc """
  Generates error correction codewords for the given data codewords.

  ## Parameters
    - `data_codewords` - list of data codeword integers (0-255)
    - `ec_count` - number of error correction codewords to generate

  ## Returns
    List of `ec_count` error correction codeword integers.
  """
  @spec encode(list(non_neg_integer()), non_neg_integer()) :: list(non_neg_integer())
  def encode(data_codewords, ec_count) do
    gen_poly = generator_polynomial(ec_count)

    # Start with message polynomial padded with ec_count zeros
    # (equivalent to multiplying by x^ec_count)
    message = data_codewords ++ List.duplicate(0, ec_count)

    # Perform polynomial long division
    remainder = poly_divide(message, gen_poly, length(data_codewords))

    # The remainder is the EC codewords, padded to ec_count length
    pad_count = ec_count - length(remainder)
    List.duplicate(0, pad_count) ++ remainder
  end

  @doc """
  Builds the generator polynomial for the given number of error correction codewords.

  The generator polynomial is: g(x) = (x - α⁰)(x - α¹)(x - α²)...(x - α^(n-1))

  Returns the polynomial as a list of coefficients [highest_degree, ..., constant].
  """
  @spec generator_polynomial(non_neg_integer()) :: list(non_neg_integer())
  def generator_polynomial(ec_count) do
    # Start with (x - α⁰) = [1, α⁰] = [1, 1]
    Enum.reduce(0..(ec_count - 1), [1], fn i, poly ->
      multiply_polynomials(poly, [1, GF.exp(i)])
    end)
  end

  # Multiply two polynomials in GF(2⁸)
  defp multiply_polynomials(p1, p2) do
    len1 = length(p1)
    len2 = length(p2)
    result_len = len1 + len2 - 1
    result = List.duplicate(0, result_len)

    Enum.reduce(Enum.with_index(p1), result, fn {coeff1, i}, acc ->
      Enum.reduce(Enum.with_index(p2), acc, fn {coeff2, j}, acc2 ->
        product = GF.multiply(coeff1, coeff2)
        current = Enum.at(acc2, i + j)
        List.replace_at(acc2, i + j, GF.add(current, product))
      end)
    end)
  end

  # Perform polynomial long division, returning the remainder
  defp poly_divide(message, gen_poly, steps) do
    Enum.reduce(0..(steps - 1), message, fn _step, msg ->
      lead = hd(msg)

      if lead == 0 do
        tl(msg)
      else
        # Multiply generator by the lead coefficient
        scaled = Enum.map(gen_poly, fn coeff -> GF.multiply(coeff, lead) end)

        # XOR with the current message (dropping the leading term)
        msg_tail = tl(msg)
        scaled_tail = tl(scaled)

        # XOR element-wise, the rest of msg_tail continues unchanged
        xored =
          Enum.zip_with(
            scaled_tail ++ List.duplicate(0, length(msg_tail) - length(scaled_tail)),
            msg_tail,
            fn a, b -> GF.add(a, b) end
          )

        xored
      end
    end)
  end
end
