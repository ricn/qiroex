defmodule Qiroex.Scanability do
  @moduledoc """
  Scanability scoring for generated QR codes.

  Evaluates a `%Qiroex.QR{}` struct across five factors and produces a
  structured result with an overall score (0–100), a rating atom, a
  human-readable summary, and a per-factor breakdown.

  ## Factors

  | Factor              | Weight | What it measures                                    |
  |---------------------|--------|-----------------------------------------------------|
  | Error Correction    | 25%    | Higher EC level → more damage tolerance             |
  | Version Complexity  | 25%    | Higher version → finer modules → harder for cameras |
  | Capacity Utilization| 20%    | How full the version is (sweet spot: 30–70%)        |
  | Mask Penalty        | 15%    | ISO 18004 penalty on the final matrix (lower = better) |
  | Data Density        | 15%    | Ratio of EC codewords to total codewords             |

  ## Ratings

  | Score   | Rating       |
  |---------|--------------|
  | 80–100  | `:excellent` |
  | 60–79   | `:good`      |
  | 40–59   | `:moderate`  |
  | 0–39    | `:poor`      |

  ## Usage

      {:ok, qr} = Qiroex.encode("Hello, World!", level: :m)
      result = Qiroex.Scanability.evaluate(qr)
      result.rating   #=> :good
      result.score    #=> 72
      result.summary  #=> "Good — version 1, EC level M, 38% capacity used"

  Or use the convenience function in the main module:

      result = Qiroex.scanability("Hello, World!", level: :m)
  """

  alias Qiroex.Encoder.Mode
  alias Qiroex.Matrix.Mask
  alias Qiroex.{QR, Spec}

  @type rating :: :excellent | :good | :moderate | :poor

  @type factor :: %{
          name: String.t(),
          score: 0..100,
          rating: rating(),
          detail: String.t()
        }

  @type t :: %__MODULE__{
          score: 0..100,
          rating: rating(),
          summary: String.t(),
          factors: [factor()]
        }

  defstruct [:score, :rating, :summary, :factors]

  # Factor weights (must sum to 100)
  @weights %{
    ec_level: 25,
    version_complexity: 25,
    capacity_utilization: 20,
    mask_penalty: 15,
    data_density: 15
  }

  @doc """
  Evaluates the scanability of a generated QR code.

  ## Parameters

    - `qr` — a `%Qiroex.QR{}` struct produced by `Qiroex.encode/2`

  ## Returns

    A `%Qiroex.Scanability{}` struct.

  ## Examples

      {:ok, qr} = Qiroex.encode("Hello")
      result = Qiroex.Scanability.evaluate(qr)
      result.rating  #=> :good
  """
  @spec evaluate(QR.t()) :: t()
  def evaluate(%QR{} = qr) do
    factors = [
      factor_ec_level(qr.ec_level),
      factor_version_complexity(qr.version),
      factor_capacity_utilization(qr),
      factor_mask_penalty(qr.matrix),
      factor_data_density(qr.version, qr.ec_level)
    ]

    score = weighted_score(factors)
    rating = score_to_rating(score)
    summary = build_summary(rating, qr, score)

    %__MODULE__{
      score: score,
      rating: rating,
      summary: summary,
      factors: factors
    }
  end

  # ─── Factor: Error Correction Level ──────────────────────────────────

  defp factor_ec_level(ec_level) do
    {score, recovery, label} =
      case ec_level do
        :h -> {100, "~30%", "H"}
        :q -> {80, "~25%", "Q"}
        :m -> {60, "~15%", "M"}
        :l -> {30, "~7%", "L"}
      end

    %{
      name: "error_correction",
      score: score,
      rating: score_to_rating(score),
      detail: "EC level #{label} provides #{recovery} error recovery"
    }
  end

  # ─── Factor: Version Complexity ──────────────────────────────────────

  defp factor_version_complexity(version) do
    score =
      cond do
        version <= 5 -> 100
        version <= 10 -> 85
        version <= 20 -> 65
        version <= 30 -> 45
        true -> 25
      end

    size = Spec.matrix_size(version)

    %{
      name: "version_complexity",
      score: score,
      rating: score_to_rating(score),
      detail: "Version #{version} produces a #{size}×#{size} module matrix"
    }
  end

  # ─── Factor: Capacity Utilization ────────────────────────────────────

  defp factor_capacity_utilization(%QR{
         data: data,
         version: version,
         ec_level: ec_level,
         mode: mode
       }) do
    actual_mode = if mode == :auto, do: Mode.detect(data), else: mode
    char_count = data_char_count(data, actual_mode)
    capacity = Spec.capacity(version, ec_level, actual_mode)
    utilization = char_count / capacity

    {score, description} =
      cond do
        utilization < 0.15 -> {80, "#{format_pct(utilization)} used (version may be oversized)"}
        utilization <= 0.70 -> {100, "#{format_pct(utilization)} used (optimal range)"}
        utilization <= 0.85 -> {70, "#{format_pct(utilization)} used (approaching capacity)"}
        utilization <= 0.95 -> {40, "#{format_pct(utilization)} used (near capacity limit)"}
        true -> {15, "#{format_pct(utilization)} used (at capacity limit)"}
      end

    %{
      name: "capacity_utilization",
      score: score,
      rating: score_to_rating(score),
      detail: description
    }
  end

  # ─── Factor: Mask Penalty ────────────────────────────────────────────

  defp factor_mask_penalty(matrix) do
    penalty = Mask.evaluate_penalty(matrix)
    size = matrix.size
    # Normalize penalty relative to matrix area for a version-independent metric
    ratio = penalty / (size * size)

    score =
      cond do
        ratio < 0.3 -> 100
        ratio < 0.6 -> 85
        ratio < 1.0 -> 70
        ratio < 2.0 -> 50
        ratio < 3.5 -> 35
        true -> 20
      end

    %{
      name: "mask_penalty",
      score: score,
      rating: score_to_rating(score),
      detail:
        "Mask penalty #{penalty} (normalized #{Float.round(ratio, 2)} per module; lower is better)"
    }
  end

  # ─── Factor: Data Density ────────────────────────────────────────────

  defp factor_data_density(version, ec_level) do
    data_codewords = Spec.total_data_codewords(version, ec_level)
    total_codewords = Spec.total_codewords(version)
    ec_codewords = total_codewords - data_codewords
    ec_ratio = ec_codewords / total_codewords

    # Higher EC codeword ratio means more redundancy → better scanability
    score =
      cond do
        ec_ratio >= 0.30 -> 100
        ec_ratio >= 0.25 -> 85
        ec_ratio >= 0.15 -> 65
        ec_ratio >= 0.07 -> 40
        true -> 20
      end

    %{
      name: "data_density",
      score: score,
      rating: score_to_rating(score),
      detail:
        "#{ec_codewords} of #{total_codewords} codewords are EC (#{format_pct(ec_ratio)} redundancy)"
    }
  end

  # ─── Aggregation ─────────────────────────────────────────────────────

  defp weighted_score(factors) do
    factor_map = Map.new(factors, fn f -> {f.name, f.score} end)

    total =
      Enum.reduce(@weights, 0, fn {key, weight}, acc ->
        factor_score = Map.get(factor_map, Atom.to_string(key), 0)
        acc + factor_score * weight / 100
      end)

    round(total)
  end

  defp score_to_rating(score) when score >= 80, do: :excellent
  defp score_to_rating(score) when score >= 60, do: :good
  defp score_to_rating(score) when score >= 40, do: :moderate
  defp score_to_rating(_score), do: :poor

  # ─── Summary ─────────────────────────────────────────────────────────

  defp build_summary(rating, qr, score) do
    rating_label = rating |> Atom.to_string() |> String.capitalize()
    ec_label = qr.ec_level |> Atom.to_string() |> String.upcase()

    actual_mode = if qr.mode == :auto, do: Mode.detect(qr.data), else: qr.mode
    char_count = data_char_count(qr.data, actual_mode)
    capacity = Spec.capacity(qr.version, qr.ec_level, actual_mode)
    utilization_pct = round(char_count / capacity * 100)

    "#{rating_label} (#{score}/100) — version #{qr.version}, EC level #{ec_label}, #{utilization_pct}% capacity used"
  end

  # ─── Helpers ─────────────────────────────────────────────────────────

  defp data_char_count(data, :byte), do: byte_size(data)
  defp data_char_count(data, :kanji), do: div(byte_size(data), 2)
  defp data_char_count(data, _mode), do: String.length(data)

  defp format_pct(ratio), do: "#{round(ratio * 100)}%"
end
