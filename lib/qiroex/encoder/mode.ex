defmodule Qiroex.Encoder.Mode do
  @moduledoc """
  Mode detection and auto-selection for QR code encoding.

  Analyzes input data to determine the most efficient encoding mode,
  or the optimal combination of modes for mixed-content strings.
  """

  alias Qiroex.Spec

  @doc """
  Detects the best single encoding mode for the entire input string.

  ## Returns
    - `:numeric` if all characters are digits
    - `:alphanumeric` if all characters are in the alphanumeric set
    - `:byte` otherwise (default fallback)
  """
  @spec detect(binary()) :: Spec.mode()
  def detect(data) when is_binary(data) do
    charlist = String.to_charlist(data)

    cond do
      Enum.all?(charlist, &Spec.numeric_char?/1) -> :numeric
      Enum.all?(charlist, &Spec.alphanumeric_char?/1) -> :alphanumeric
      true -> :byte
    end
  end

  @doc """
  Splits input data into optimally-encoded segments using a greedy algorithm.

  Each segment is `{mode, data}` where mode is the most efficient encoding
  for that portion of the string. Mode switches happen when they save bits.

  For simple inputs (all one mode), returns a single segment.

  ## Parameters
    - `data` - the input string
    - `version` - QR code version (affects character count indicator lengths)

  ## Returns
    List of `{mode, data}` tuples.
  """
  @spec segment(binary(), Spec.version()) :: [{Spec.mode(), binary()}]
  def segment(data, version) when is_binary(data) do
    # Classify each byte by its most compact mode
    chars = String.to_charlist(data)

    if chars == [] do
      [{:byte, data}]
    else
      chars
      |> Enum.map(fn ch -> {classify_char(ch), ch} end)
      |> merge_segments(version)
    end
  end

  # Classify a single character to its most compact mode
  defp classify_char(ch) do
    cond do
      Spec.numeric_char?(ch) -> :numeric
      Spec.alphanumeric_char?(ch) -> :alphanumeric
      true -> :byte
    end
  end

  # Merge classified characters into segments using greedy algorithm
  # Adjacent characters of the same mode are always merged.
  # Short runs of a "better" mode embedded in a "worse" mode are absorbed
  # if the mode switch overhead exceeds the savings.
  defp merge_segments(classified, version) do
    # First pass: group consecutive same-mode characters
    groups =
      classified
      |> Enum.chunk_by(fn {mode, _} -> mode end)
      |> Enum.map(fn chunk ->
        mode = elem(hd(chunk), 0)
        chars = Enum.map(chunk, &elem(&1, 1))
        {mode, chars}
      end)

    # Second pass: merge small segments into their neighbors when the
    # mode switch overhead costs more than the encoding savings
    merged = merge_small_segments(groups, version)

    # Convert charlists back to binaries
    Enum.map(merged, fn {mode, chars} ->
      {mode, List.to_string(chars)}
    end)
  end

  # Merge small segments into adjacent segments when beneficial
  defp merge_small_segments(groups, _version) when length(groups) <= 1, do: groups

  defp merge_small_segments(groups, version) do
    # Mode switch overhead: 4 bits mode indicator + char count indicator bits
    # Try merging adjacent segments and see if it reduces total bit count
    result = do_merge(groups, version)

    # Repeat until no more merges happen
    if result == groups do
      result
    else
      merge_small_segments(result, version)
    end
  end

  defp do_merge([], _version), do: []
  defp do_merge([single], _version), do: [single]

  defp do_merge([{mode1, chars1}, {mode2, chars2} | rest], version) do
    # Calculate cost of keeping separate vs merging
    separate_cost =
      segment_bits(mode1, length(chars1), version) +
        segment_bits(mode2, length(chars2), version)

    # Merged mode must accommodate both character sets
    merged_mode = broader_mode(mode1, mode2)
    merged_cost = segment_bits(merged_mode, length(chars1) + length(chars2), version)

    if merged_cost <= separate_cost do
      # Merge and continue
      do_merge([{merged_mode, chars1 ++ chars2} | rest], version)
    else
      [{mode1, chars1} | do_merge([{mode2, chars2} | rest], version)]
    end
  end

  # Returns the broader (less efficient but more general) of two modes
  defp broader_mode(:byte, _), do: :byte
  defp broader_mode(_, :byte), do: :byte
  defp broader_mode(:alphanumeric, _), do: :alphanumeric
  defp broader_mode(_, :alphanumeric), do: :alphanumeric
  defp broader_mode(:numeric, :numeric), do: :numeric

  # Calculate total bits for a segment (mode indicator + char count + data)
  defp segment_bits(mode, char_count, version) do
    mode_bits = 4
    count_bits = Spec.char_count_bits(mode, version)

    data_bits =
      case mode do
        :numeric ->
          full_groups = div(char_count, 3) * 10

          remainder =
            case rem(char_count, 3) do
              0 -> 0
              1 -> 4
              2 -> 7
            end

          full_groups + remainder

        :alphanumeric ->
          div(char_count, 2) * 11 + rem(char_count, 2) * 6

        :byte ->
          char_count * 8

        :kanji ->
          char_count * 13
      end

    mode_bits + count_bits + data_bits
  end
end
