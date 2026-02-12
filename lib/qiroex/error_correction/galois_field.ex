defmodule Qiroex.ErrorCorrection.GaloisField do
  @moduledoc """
  Galois Field GF(2⁸) arithmetic for QR code Reed-Solomon error correction.

  Uses primitive polynomial x⁸ + x⁴ + x³ + x² + 1 (integer 285).
  Provides exp/log lookup tables and field operations (add, multiply, power, inverse).
  Tables are generated at compile time for maximum performance.
  """

  @primitive_poly 285

  # Generate exp (antilog) and log tables at compile time
  # exp[i] = α^i where α = 2
  # log[i] = exponent n such that α^n = i
  {exp_table, log_table} =
    Enum.reduce(0..254, {%{}, %{}}, fn i, {exp_acc, log_acc} ->
      value =
        if i == 0 do
          1
        else
          prev = Map.fetch!(exp_acc, i - 1)
          v = Bitwise.bsl(prev, 1)
          if v >= 256, do: Bitwise.bxor(v, 285), else: v
        end

      {Map.put(exp_acc, i, value), Map.put(log_acc, value, i)}
    end)

  # α^255 = α^0 = 1, so we also need exp[255] for the wrap-around
  exp_table = Map.put(exp_table, 255, Map.fetch!(exp_table, 0))

  @exp_table exp_table
  @log_table log_table

  @doc "Returns α^n (the antilog/exponent table lookup). n is taken mod 255."
  @spec exp(non_neg_integer()) :: non_neg_integer()
  def exp(n) do
    Map.fetch!(@exp_table, rem(n, 255))
  end

  @doc "Returns the discrete log base α of value. Value must be 1..255."
  @spec log(non_neg_integer()) :: non_neg_integer()
  def log(0), do: raise(ArgumentError, "log(0) is undefined in GF(2^8)")
  def log(value) when value >= 1 and value <= 255 do
    Map.fetch!(@log_table, value)
  end

  @doc """
  Adds two elements in GF(2⁸). Addition in GF(2⁸) is XOR.
  Subtraction is the same as addition in characteristic 2.
  """
  @spec add(non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def add(a, b), do: Bitwise.bxor(a, b)

  @doc "Multiplies two elements in GF(2⁸) using log/exp tables."
  @spec multiply(non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def multiply(0, _), do: 0
  def multiply(_, 0), do: 0
  def multiply(a, b) do
    exp(Map.fetch!(@log_table, a) + Map.fetch!(@log_table, b))
  end

  @doc "Returns the multiplicative inverse of a in GF(2⁸)."
  @spec inverse(non_neg_integer()) :: non_neg_integer()
  def inverse(0), do: raise(ArgumentError, "inverse(0) is undefined in GF(2^8)")
  def inverse(a) do
    exp(255 - Map.fetch!(@log_table, a))
  end

  @doc "Returns a^n in GF(2⁸)."
  @spec power(non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def power(0, 0), do: raise(ArgumentError, "0^0 is undefined")
  def power(0, _), do: 0
  def power(_, 0), do: 1
  def power(a, n) do
    exp(rem(Map.fetch!(@log_table, a) * n, 255))
  end

  @doc "Returns the primitive polynomial used for this field."
  @spec primitive_polynomial() :: non_neg_integer()
  def primitive_polynomial, do: @primitive_poly

  @doc "Returns the full exp (antilog) table as a map."
  @spec exp_table() :: map()
  def exp_table, do: @exp_table

  @doc "Returns the full log table as a map."
  @spec log_table() :: map()
  def log_table, do: @log_table
end
