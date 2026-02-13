defmodule Qiroex.Version do
  @moduledoc """
  QR code version selection and capacity checking.

  Automatically selects the smallest version (1-40) that can accommodate
  the encoded data at the chosen error correction level.
  """

  alias Qiroex.Encoder.Mode
  alias Qiroex.Spec

  @doc """
  Selects the smallest version that can fit the given data at the specified EC level.

  ## Parameters
    - `data` - the input data string
    - `ec_level` - error correction level (:l, :m, :q, :h)
    - `mode` - encoding mode or :auto for automatic detection

  ## Returns
    `{:ok, version}` or `{:error, reason}`
  """
  @spec select(binary(), Spec.ec_level(), Spec.mode() | :auto) ::
          {:ok, Spec.version()} | {:error, String.t()}
  def select(data, ec_level, mode \\ :auto) do
    actual_mode = if mode == :auto, do: Mode.detect(data), else: mode
    char_count = data_length(data, actual_mode)

    case Enum.find(1..40, fn v -> Spec.capacity(v, ec_level, actual_mode) >= char_count end) do
      nil ->
        max_cap = Spec.capacity(40, ec_level, actual_mode)

        {:error,
         "Data too large: #{char_count} #{actual_mode} characters exceeds maximum capacity of #{max_cap} at EC level #{ec_level}"}

      version ->
        {:ok, version}
    end
  end

  @doc """
  Checks if the given data fits in the specified version at the specified EC level.

  ## Returns
    `true` if the data fits, `false` otherwise.
  """
  @spec fits?(binary(), Spec.version(), Spec.ec_level(), Spec.mode() | :auto) :: boolean()
  def fits?(data, version, ec_level, mode \\ :auto) do
    actual_mode = if mode == :auto, do: Mode.detect(data), else: mode
    char_count = data_length(data, actual_mode)
    Spec.capacity(version, ec_level, actual_mode) >= char_count
  end

  @doc """
  Returns the version, raising if data doesn't fit.
  """
  @spec select!(binary(), Spec.ec_level(), Spec.mode() | :auto) :: Spec.version()
  def select!(data, ec_level, mode \\ :auto) do
    case select(data, ec_level, mode) do
      {:ok, version} -> version
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  defp data_length(data, :byte), do: byte_size(data)
  defp data_length(data, :kanji), do: div(byte_size(data), 2)
  defp data_length(data, _mode), do: String.length(data)
end
