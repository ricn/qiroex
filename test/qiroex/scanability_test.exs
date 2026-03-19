defmodule Qiroex.ScanabilityTest do
  use ExUnit.Case, async: true

  alias Qiroex.Scanability

  # ─── Struct shape ────────────────────────────────────────────────────

  describe "evaluate/1 struct shape" do
    test "returns a Scanability struct with all required fields" do
      qr = Qiroex.encode!("Hello")
      result = Scanability.evaluate(qr)

      assert %Scanability{} = result
      assert is_integer(result.score)
      assert result.score in 0..100
      assert result.rating in [:excellent, :good, :moderate, :poor]
      assert is_binary(result.summary)
      assert is_list(result.factors)
    end

    test "factors list contains all five expected factor names" do
      qr = Qiroex.encode!("Hello")
      result = Scanability.evaluate(qr)
      names = Enum.map(result.factors, & &1.name)

      assert "error_correction" in names
      assert "version_complexity" in names
      assert "capacity_utilization" in names
      assert "mask_penalty" in names
      assert "data_density" in names
    end

    test "each factor has required keys with correct types" do
      qr = Qiroex.encode!("Hello")
      result = Scanability.evaluate(qr)

      for factor <- result.factors do
        assert is_binary(factor.name)
        assert is_integer(factor.score)
        assert factor.score in 0..100
        assert factor.rating in [:excellent, :good, :moderate, :poor]
        assert is_binary(factor.detail)
      end
    end

    test "summary contains rating, version, EC level, and capacity utilization" do
      qr = Qiroex.encode!("Hello", level: :m)
      result = Scanability.evaluate(qr)

      assert result.summary =~ ~r/version \d+/i
      assert result.summary =~ ~r/EC level M/i
      assert result.summary =~ ~r/\d+% capacity used/
    end
  end

  # ─── Error Correction factor ─────────────────────────────────────────

  describe "error correction factor" do
    test ":h level scores 100" do
      qr = Qiroex.encode!("Hi", level: :h)
      result = Scanability.evaluate(qr)
      factor = find_factor(result, "error_correction")

      assert factor.score == 100
      assert factor.rating == :excellent
      assert factor.detail =~ "H"
      assert factor.detail =~ "30%"
    end

    test ":q level scores 80" do
      qr = Qiroex.encode!("Hi", level: :q)
      result = Scanability.evaluate(qr)
      factor = find_factor(result, "error_correction")

      assert factor.score == 80
      # 80 maps to :excellent per the rating scale
      assert factor.rating == :excellent
    end

    test ":m level scores 60" do
      qr = Qiroex.encode!("Hi", level: :m)
      result = Scanability.evaluate(qr)
      factor = find_factor(result, "error_correction")

      assert factor.score == 60
      assert factor.rating == :good
    end

    test ":l level scores 30" do
      qr = Qiroex.encode!("Hi", level: :l)
      result = Scanability.evaluate(qr)
      factor = find_factor(result, "error_correction")

      assert factor.score == 30
      assert factor.rating == :poor
    end
  end

  # ─── Version Complexity factor ───────────────────────────────────────

  describe "version complexity factor" do
    test "low version (1–5) scores 100" do
      qr = Qiroex.encode!("Hi")
      assert qr.version in 1..5
      result = Scanability.evaluate(qr)
      factor = find_factor(result, "version_complexity")

      assert factor.score == 100
      assert factor.detail =~ "#{qr.version}"
      assert factor.detail =~ "21×21" or factor.detail =~ "×"
    end

    test "detail includes matrix dimensions" do
      qr = Qiroex.encode!("Hi", version: 10)
      result = Scanability.evaluate(qr)
      factor = find_factor(result, "version_complexity")

      assert factor.detail =~ "10"
      assert factor.detail =~ "57×57"
    end

    test "version 1 scores 100" do
      qr = Qiroex.encode!("HI", version: 1, mode: :alphanumeric)
      result = Scanability.evaluate(qr)
      factor = find_factor(result, "version_complexity")

      assert factor.score == 100
    end

    test "version 15 scores 65" do
      qr = Qiroex.encode!("Hello", version: 15)
      result = Scanability.evaluate(qr)
      factor = find_factor(result, "version_complexity")

      assert factor.score == 65
    end

    test "version 25 scores 45" do
      qr = Qiroex.encode!("Hello", version: 25)
      result = Scanability.evaluate(qr)
      factor = find_factor(result, "version_complexity")

      assert factor.score == 45
    end

    test "version 35 scores 25" do
      qr = Qiroex.encode!("Hello", version: 35)
      result = Scanability.evaluate(qr)
      factor = find_factor(result, "version_complexity")

      assert factor.score == 25
    end
  end

  # ─── Capacity Utilization factor ─────────────────────────────────────

  describe "capacity utilization factor" do
    test "detail includes utilization percentage" do
      qr = Qiroex.encode!("HELLO", level: :m, mode: :alphanumeric)
      result = Scanability.evaluate(qr)
      factor = find_factor(result, "capacity_utilization")

      assert factor.detail =~ ~r/\d+% used/
    end

    test "scores 100 when utilization is in optimal 15–70% range" do
      # "HELLO" in alphanumeric = 5 chars; version 1 :m capacity = 20 alphanumeric
      # 5/20 = 25% → optimal
      qr = Qiroex.encode!("HELLO", level: :m, mode: :alphanumeric)
      result = Scanability.evaluate(qr)
      factor = find_factor(result, "capacity_utilization")

      assert factor.score == 100
    end

    test "scores 80 when utilization is very low (< 15%)" do
      # Force a high version with short data → very low utilization
      qr = Qiroex.encode!("Hi", version: 10, level: :m)
      result = Scanability.evaluate(qr)
      factor = find_factor(result, "capacity_utilization")

      assert factor.score == 80
      assert factor.detail =~ "oversized"
    end
  end

  # ─── Mask Penalty factor ─────────────────────────────────────────────

  describe "mask penalty factor" do
    test "detail includes the numeric penalty value" do
      qr = Qiroex.encode!("Hello")
      result = Scanability.evaluate(qr)
      factor = find_factor(result, "mask_penalty")

      assert factor.detail =~ ~r/Mask penalty \d+/
      assert factor.detail =~ "lower is better"
    end

    test "score is within valid range" do
      qr = Qiroex.encode!("Hello, World!", level: :h)
      result = Scanability.evaluate(qr)
      factor = find_factor(result, "mask_penalty")

      assert factor.score in 0..100
      assert factor.rating in [:excellent, :good, :moderate, :poor]
    end
  end

  # ─── Data Density factor ─────────────────────────────────────────────

  describe "data density factor" do
    test "higher EC level results in higher data density score" do
      qr_h = Qiroex.encode!("Hello", level: :h)
      qr_l = Qiroex.encode!("Hello", level: :l)

      result_h = Scanability.evaluate(qr_h)
      result_l = Scanability.evaluate(qr_l)

      factor_h = find_factor(result_h, "data_density")
      factor_l = find_factor(result_l, "data_density")

      assert factor_h.score >= factor_l.score
    end

    test "detail includes codeword counts and redundancy percentage" do
      qr = Qiroex.encode!("Hello", level: :h)
      result = Scanability.evaluate(qr)
      factor = find_factor(result, "data_density")

      assert factor.detail =~ "codewords"
      assert factor.detail =~ ~r/\d+% redundancy/
    end
  end

  # ─── Overall score and rating ─────────────────────────────────────────

  describe "overall scoring" do
    test "short numeric data with :h EC level scores good or better" do
      # Very short numeric data at highest EC → small version, maximum recovery
      qr = Qiroex.encode!("12345", level: :h, mode: :numeric)
      result = Scanability.evaluate(qr)

      assert result.score >= 60
      assert result.rating in [:excellent, :good]
    end

    test "small data with :m EC level scores good or moderate" do
      qr = Qiroex.encode!("Hello, World!", level: :m)
      result = Scanability.evaluate(qr)

      assert result.score >= 50
      assert result.rating in [:excellent, :good, :moderate]
    end

    test ":h EC level factor always scores higher than :l for the same data" do
      # Compare only the EC factor, not the overall score (which also penalises
      # capacity utilisation — :h has less capacity so same data fills more of it)
      qr_h = Qiroex.encode!("Hello", level: :h)
      qr_l = Qiroex.encode!("Hello", level: :l)

      result_h = Scanability.evaluate(qr_h)
      result_l = Scanability.evaluate(qr_l)

      factor_h = find_factor(result_h, "error_correction")
      factor_l = find_factor(result_l, "error_correction")

      assert factor_h.score > factor_l.score
    end

    test "version 1 scores higher than version 30 for version complexity" do
      # Use uppercase data — alphanumeric mode only supports A-Z 0-9 and symbols
      qr_v1 = Qiroex.encode!("HI", version: 1, level: :l, mode: :alphanumeric)
      qr_v30 = Qiroex.encode!("HI", version: 30, level: :l, mode: :alphanumeric)

      result_v1 = Scanability.evaluate(qr_v1)
      result_v30 = Scanability.evaluate(qr_v30)

      factor_v1 = find_factor(result_v1, "version_complexity")
      factor_v30 = find_factor(result_v30, "version_complexity")

      assert factor_v1.score > factor_v30.score
    end
  end

  # ─── Convenience functions ───────────────────────────────────────────

  describe "Qiroex.scanability/1 (with QR struct)" do
    test "returns a Scanability struct" do
      qr = Qiroex.encode!("Hello")
      result = Qiroex.scanability(qr)

      assert %Scanability{} = result
      assert result.rating in [:excellent, :good, :moderate, :poor]
    end
  end

  describe "Qiroex.scanability/2 (with data and opts)" do
    test "returns {:ok, Scanability} for valid input" do
      assert {:ok, %Scanability{} = result} = Qiroex.scanability("Hello", level: :m)
      assert result.rating in [:excellent, :good, :moderate, :poor]
    end

    test "returns {:error, reason} for invalid data" do
      assert {:error, _reason} = Qiroex.scanability("", level: :m)
    end

    test "returns {:error, reason} for invalid options" do
      assert {:error, _reason} = Qiroex.scanability("Hello", level: :invalid)
    end
  end

  describe "Qiroex.scanability!/2" do
    test "returns Scanability struct for valid input" do
      result = Qiroex.scanability!("Hello", level: :h)

      assert %Scanability{} = result
      assert result.rating in [:excellent, :good]
    end

    test "raises ArgumentError for invalid data" do
      assert_raise ArgumentError, fn ->
        Qiroex.scanability!("", level: :m)
      end
    end
  end

  # ─── Helpers ─────────────────────────────────────────────────────────

  defp find_factor(%Scanability{factors: factors}, name) do
    Enum.find(factors, &(&1.name == name))
  end
end
