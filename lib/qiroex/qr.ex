defmodule Qiroex.QR do
  @moduledoc """
  Core QR code generation pipeline.

  Orchestrates the full encoding flow:
  data → mode analysis → version selection → bit encoding →
  error correction → interleaving → matrix placement → masking
  """

  alias Qiroex.{Spec, Version, Matrix}
  alias Qiroex.Encoder.{Mode, Segment}
  alias Qiroex.ErrorCorrection.ReedSolomon
  alias Qiroex.Matrix.{Builder, DataPlacer, Mask}

  @type t :: %__MODULE__{
          data: binary(),
          version: Spec.version(),
          ec_level: Spec.ec_level(),
          mask: non_neg_integer(),
          mode: Spec.mode() | :auto,
          segments: [{Spec.mode(), binary()}],
          matrix: Matrix.t(),
          codewords: list(non_neg_integer())
        }

  defstruct [:data, :version, :ec_level, :mask, :mode, :segments, :matrix, :codewords]

  @doc """
  Encodes data into a QR code.

  ## Options
    - `:ec_level` - error correction level (:l, :m, :q, :h). Default: :m
    - `:version` - force a specific version (1-40) or :auto. Default: :auto
    - `:mode` - force encoding mode or :auto. Default: :auto
    - `:mask` - force mask pattern (0-7) or :auto. Default: :auto

  ## Returns
    `{:ok, %Qiroex.QR{}}` or `{:error, reason}`
  """
  @spec encode(binary(), keyword()) :: {:ok, t()} | {:error, String.t()}
  def encode(data, opts \\ []) do
    ec_level = Keyword.get(opts, :level, Keyword.get(opts, :ec_level, :m))
    version_opt = Keyword.get(opts, :version, :auto)
    mode_opt = Keyword.get(opts, :mode, :auto)
    mask_opt = Keyword.get(opts, :mask, :auto)

    with :ok <- validate_data(data),
         {:ok, detected_mode} <- detect_mode(data, mode_opt),
         {:ok, version} <- resolve_version(data, ec_level, detected_mode, version_opt),
         segments <- build_segments(data, detected_mode, version),
         data_codewords <- Segment.encode(segments, version, ec_level),
         all_codewords <- generate_ec_and_interleave(data_codewords, version, ec_level),
         data_bits <- codewords_to_bits(all_codewords, version),
         matrix <- build_matrix(version, data_bits, ec_level, mask_opt) do
      {mask, final_matrix} = matrix

      {:ok,
       %__MODULE__{
         data: data,
         version: version,
         ec_level: ec_level,
         mask: mask,
         mode: detected_mode,
         segments: segments,
         matrix: final_matrix,
         codewords: all_codewords
       }}
    end
  end

  @doc "Encodes data into a QR code, raising on error."
  @spec encode!(binary(), keyword()) :: t()
  def encode!(data, opts \\ []) do
    case encode(data, opts) do
      {:ok, qr} -> qr
      {:error, reason} -> raise ArgumentError, reason
    end
  end

  @doc "Returns the matrix as a 2D boolean list with quiet zone margin."
  @spec to_matrix(t(), non_neg_integer()) :: list(list(0 | 1))
  def to_matrix(%__MODULE__{matrix: matrix}, margin \\ 4) do
    Matrix.to_list(matrix, margin)
  end

  # === Private Pipeline Steps ===

  defp validate_data(""), do: {:error, "Data cannot be empty"}
  defp validate_data(data) when is_binary(data), do: :ok
  defp validate_data(_), do: {:error, "Data must be a binary string"}

  defp detect_mode(data, :auto), do: {:ok, Mode.detect(data)}

  defp detect_mode(_data, mode) when mode in [:numeric, :alphanumeric, :byte, :kanji],
    do: {:ok, mode}

  defp detect_mode(_, mode), do: {:error, "Invalid mode: #{inspect(mode)}"}

  defp resolve_version(data, ec_level, mode, :auto) do
    Version.select(data, ec_level, mode)
  end

  defp resolve_version(data, ec_level, mode, version) when is_integer(version) do
    if Version.fits?(data, version, ec_level, mode) do
      {:ok, version}
    else
      {:error, "Data does not fit in version #{version} at EC level #{ec_level}"}
    end
  end

  defp build_segments(data, mode, version) do
    if mode == :auto or mode in [:numeric, :alphanumeric, :byte] do
      # Try mixed-mode for auto, use single segment for forced mode
      case mode do
        :auto -> Mode.segment(data, version)
        _ -> [{mode, data}]
      end
    else
      [{mode, data}]
    end
  end

  @doc false
  def generate_ec_and_interleave(data_codewords, version, ec_level) do
    {_total_data, ec_per_block, groups} = Spec.ec_info(version, ec_level)

    # Split data into blocks
    blocks = split_into_blocks(data_codewords, groups)

    # Generate EC for each block
    ec_blocks =
      Enum.map(blocks, fn block ->
        ReedSolomon.encode(block, ec_per_block)
      end)

    # Interleave data codewords
    interleaved_data = interleave(blocks)

    # Interleave EC codewords
    interleaved_ec = interleave(ec_blocks)

    # Concatenate
    interleaved_data ++ interleaved_ec
  end

  # Split data codewords into blocks according to group structure
  defp split_into_blocks(data_codewords, groups) do
    {blocks, _remaining} =
      Enum.reduce(groups, {[], data_codewords}, fn {block_count, cw_per_block},
                                                   {acc, remaining} ->
        {new_blocks, rest} =
          Enum.reduce(1..block_count, {[], remaining}, fn _, {blk_acc, rem_data} ->
            {block, rest} = Enum.split(rem_data, cw_per_block)
            {blk_acc ++ [block], rest}
          end)

        {acc ++ new_blocks, rest}
      end)

    blocks
  end

  # Interleave codewords from multiple blocks column-by-column
  defp interleave(blocks) do
    max_len = blocks |> Enum.map(&length/1) |> Enum.max(fn -> 0 end)

    Enum.flat_map(0..(max_len - 1), fn i ->
      blocks
      |> Enum.filter(fn block -> i < length(block) end)
      |> Enum.map(fn block -> Enum.at(block, i) end)
    end)
  end

  # Convert codewords to bit list and add remainder bits
  defp codewords_to_bits(codewords, version) do
    import Bitwise

    bits =
      Enum.flat_map(codewords, fn cw ->
        for i <- 7..0//-1, do: band(bsr(cw, i), 1)
      end)

    # Add remainder bits
    remainder = Spec.remainder_bits(version)
    bits ++ List.duplicate(0, remainder)
  end

  # Build matrix with function patterns, place data, and apply masking
  defp build_matrix(version, data_bits, ec_level, mask_opt) do
    matrix = Builder.build(version)
    matrix = DataPlacer.place(matrix, data_bits)

    case mask_opt do
      :auto ->
        Mask.select_best(matrix, ec_level)

      mask when is_integer(mask) and mask >= 0 and mask <= 7 ->
        masked = Mask.apply_mask(matrix, mask)
        finalized = Builder.finalize(masked, ec_level, mask)
        {mask, finalized}
    end
  end
end
