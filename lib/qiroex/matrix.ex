defmodule Qiroex.Matrix do
  @moduledoc """
  QR code matrix data structure.

  Represents the QR code as a map of `{row, col} => value` for O(1) access.
  Values are `:dark`, `:light`, or `nil` (unset/available for data).

  Also tracks which modules are "reserved" (function patterns, format/version info)
  vs available for data placement.
  """

  @type position :: {non_neg_integer(), non_neg_integer()}
  @type value :: :dark | :light | nil
  @type t :: %__MODULE__{
          size: non_neg_integer(),
          version: non_neg_integer(),
          modules: %{position() => value()},
          reserved: MapSet.t()
        }

  defstruct [:size, :version, modules: %{}, reserved: MapSet.new()]

  @dialyzer {:no_contracts, new: 1}

  @doc "Creates a new empty matrix for the given version."
  @spec new(non_neg_integer()) :: t()
  def new(version) do
    size = Qiroex.Spec.matrix_size(version)
    %__MODULE__{size: size, version: version}
  end

  @doc "Gets the value of a module at the given position."
  @spec get(t(), position()) :: value()
  def get(%__MODULE__{modules: modules}, pos) do
    Map.get(modules, pos)
  end

  @doc "Sets a module value and marks the position as reserved."
  @spec set(t(), position(), value()) :: t()
  def set(%__MODULE__{} = matrix, pos, value) do
    %{
      matrix
      | modules: Map.put(matrix.modules, pos, value),
        reserved: MapSet.put(matrix.reserved, pos)
    }
  end

  @doc "Sets a data module (not reserved, can be masked)."
  @spec set_data(t(), position(), value()) :: t()
  def set_data(%__MODULE__{} = matrix, pos, value) do
    %{matrix | modules: Map.put(matrix.modules, pos, value)}
  end

  @doc "Checks if a position is reserved (function pattern area)."
  @spec reserved?(t(), position()) :: boolean()
  def reserved?(%__MODULE__{reserved: reserved}, pos) do
    MapSet.member?(reserved, pos)
  end

  @doc "Checks if a position is within the matrix bounds."
  @spec in_bounds?(t(), position()) :: boolean()
  def in_bounds?(%__MODULE__{size: size}, {row, col}) do
    row >= 0 and row < size and col >= 0 and col < size
  end

  @doc "Returns the value as a boolean (true = dark, false = light)."
  @spec dark?(t(), position()) :: boolean()
  def dark?(%__MODULE__{} = matrix, pos) do
    get(matrix, pos) == :dark
  end

  @doc """
  Converts the matrix to a 2D list of booleans with quiet zone.
  `true` = dark module, `false` = light module.
  """
  @spec to_list(t(), non_neg_integer()) :: list(list(0 | 1))
  def to_list(%__MODULE__{size: size} = matrix, margin \\ 4) do
    total = size + 2 * margin

    for row <- 0..(total - 1) do
      for col <- 0..(total - 1) do
        mr = row - margin
        mc = col - margin

        if mr >= 0 and mr < size and mc >= 0 and mc < size do
          if dark?(matrix, {mr, mc}), do: 1, else: 0
        else
          0
        end
      end
    end
  end
end
