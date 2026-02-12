defmodule Qiroex.Encoder.Alphanumeric do
  @moduledoc """
  Alphanumeric mode encoder for QR codes.

  Encodes characters from the 45-character alphanumeric set:
  0-9, A-Z (uppercase only), space, $, %, *, +, -, ., /, :

  Characters are paired: pair_value = first * 45 + second → 11 bits.
  Odd remainder character → 6 bits.
  """

  alias Qiroex.Spec

  @doc """
  Encodes an alphanumeric string into a bitstring.

  ## Parameters
    - `data` - string containing only alphanumeric characters

  ## Returns
    Bitstring of encoded data (without mode indicator or character count).
  """
  @spec encode(String.t()) :: bitstring()
  def encode(data) do
    data
    |> String.to_charlist()
    |> Enum.map(&Spec.alphanumeric_value/1)
    |> Enum.chunk_every(2)
    |> Enum.reduce(<<>>, fn group, acc ->
      case group do
        [a, b] ->
          value = a * 45 + b
          <<acc::bitstring, value::11>>

        [a] ->
          <<acc::bitstring, a::6>>
      end
    end)
  end

  @doc "Returns true if the string contains only valid alphanumeric characters."
  @spec valid?(String.t()) :: boolean()
  def valid?(data) do
    data
    |> String.to_charlist()
    |> Enum.all?(&Spec.alphanumeric_char?/1)
  end
end
