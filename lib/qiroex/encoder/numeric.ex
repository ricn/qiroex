defmodule Qiroex.Encoder.Numeric do
  @moduledoc """
  Numeric mode encoder for QR codes.

  Encodes digit strings (0-9) by grouping into triplets:
  - 3 digits → 10 bits
  - 2 digits → 7 bits
  - 1 digit → 4 bits
  """

  @doc """
  Encodes a string of digits into a bitstring.

  ## Parameters
    - `data` - string containing only digits 0-9

  ## Returns
    Bitstring of encoded data (without mode indicator or character count).
  """
  @spec encode(String.t()) :: bitstring()
  def encode(data) do
    data
    |> String.to_charlist()
    |> Enum.map(&(&1 - ?0))
    |> Enum.chunk_every(3)
    |> Enum.reduce(<<>>, fn group, acc ->
      case group do
        [a, b, c] ->
          value = a * 100 + b * 10 + c
          <<acc::bitstring, value::10>>

        [a, b] ->
          value = a * 10 + b
          <<acc::bitstring, value::7>>

        [a] ->
          <<acc::bitstring, a::4>>
      end
    end)
  end

  @doc "Returns true if the string contains only digits 0-9."
  @spec valid?(String.t()) :: boolean()
  def valid?(data) do
    String.match?(data, ~r/\A[0-9]+\z/)
  end
end
