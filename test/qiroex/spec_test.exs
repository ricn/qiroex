defmodule Qiroex.SpecTest do
  use ExUnit.Case, async: true

  alias Qiroex.Spec

  describe "alphanumeric_value/1" do
    test "digits 0-9 map to values 0-9" do
      for {char, val} <- Enum.zip(?0..?9, 0..9) do
        assert Spec.alphanumeric_value(char) == val
      end
    end

    test "uppercase A-Z map to values 10-35" do
      for {char, val} <- Enum.zip(?A..?Z, 10..35) do
        assert Spec.alphanumeric_value(char) == val
      end
    end

    test "special characters map correctly" do
      assert Spec.alphanumeric_value(?\s) == 36
      assert Spec.alphanumeric_value(?$) == 37
      assert Spec.alphanumeric_value(?%) == 38
      assert Spec.alphanumeric_value(?*) == 39
      assert Spec.alphanumeric_value(?+) == 40
      assert Spec.alphanumeric_value(?-) == 41
      assert Spec.alphanumeric_value(?.) == 42
      assert Spec.alphanumeric_value(?/) == 43
      assert Spec.alphanumeric_value(?:) == 44
    end

    test "lowercase letters return nil" do
      assert Spec.alphanumeric_value(?a) == nil
    end
  end

  describe "alphanumeric_char?/1" do
    test "valid characters return true" do
      assert Spec.alphanumeric_char?(?A)
      assert Spec.alphanumeric_char?(?0)
      assert Spec.alphanumeric_char?(?\s)
    end

    test "invalid characters return false" do
      refute Spec.alphanumeric_char?(?a)
      refute Spec.alphanumeric_char?(?!)
    end
  end

  describe "numeric_char?/1" do
    test "digits return true" do
      for char <- ?0..?9, do: assert(Spec.numeric_char?(char))
    end

    test "non-digits return false" do
      refute Spec.numeric_char?(?A)
      refute Spec.numeric_char?(?a)
    end
  end

  describe "char_count_bits/2" do
    test "numeric mode bit lengths" do
      assert Spec.char_count_bits(:numeric, 1) == 10
      assert Spec.char_count_bits(:numeric, 9) == 10
      assert Spec.char_count_bits(:numeric, 10) == 12
      assert Spec.char_count_bits(:numeric, 26) == 12
      assert Spec.char_count_bits(:numeric, 27) == 14
      assert Spec.char_count_bits(:numeric, 40) == 14
    end

    test "alphanumeric mode bit lengths" do
      assert Spec.char_count_bits(:alphanumeric, 1) == 9
      assert Spec.char_count_bits(:alphanumeric, 10) == 11
      assert Spec.char_count_bits(:alphanumeric, 27) == 13
    end

    test "byte mode bit lengths" do
      assert Spec.char_count_bits(:byte, 1) == 8
      assert Spec.char_count_bits(:byte, 10) == 16
      assert Spec.char_count_bits(:byte, 27) == 16
    end

    test "kanji mode bit lengths" do
      assert Spec.char_count_bits(:kanji, 1) == 8
      assert Spec.char_count_bits(:kanji, 10) == 10
      assert Spec.char_count_bits(:kanji, 27) == 12
    end
  end

  describe "mode_indicator/1" do
    test "returns correct 4-bit indicators" do
      assert Spec.mode_indicator(:numeric) == 0b0001
      assert Spec.mode_indicator(:alphanumeric) == 0b0010
      assert Spec.mode_indicator(:byte) == 0b0100
      assert Spec.mode_indicator(:kanji) == 0b1000
    end
  end

  describe "matrix_size/1" do
    test "version 1 is 21x21" do
      assert Spec.matrix_size(1) == 21
    end

    test "version 40 is 177x177" do
      assert Spec.matrix_size(40) == 177
    end

    test "each version adds 4 modules per side" do
      assert Spec.matrix_size(2) == 25
      assert Spec.matrix_size(3) == 29
      assert Spec.matrix_size(10) == 57
    end
  end

  describe "remainder_bits/1" do
    test "version 1 has 0 remainder bits" do
      assert Spec.remainder_bits(1) == 0
    end

    test "versions 2-6 have 7 remainder bits" do
      for v <- 2..6, do: assert(Spec.remainder_bits(v) == 7)
    end

    test "versions 7-13 have 0 remainder bits" do
      for v <- 7..13, do: assert(Spec.remainder_bits(v) == 0)
    end

    test "versions 14-20 have 3 remainder bits" do
      for v <- 14..20, do: assert(Spec.remainder_bits(v) == 3)
    end
  end

  describe "alignment_pattern_positions/1" do
    test "version 1 has no alignment patterns" do
      assert Spec.alignment_pattern_positions(1) == []
    end

    test "version 2 has centers at [6, 18]" do
      assert Spec.alignment_pattern_positions(2) == [6, 18]
    end

    test "version 7 has centers at [6, 22, 38]" do
      assert Spec.alignment_pattern_positions(7) == [6, 22, 38]
    end

    test "version 40 has centers at [6, 30, 58, 86, 114, 142, 170]" do
      assert Spec.alignment_pattern_positions(40) == [6, 30, 58, 86, 114, 142, 170]
    end
  end

  describe "ec_info/2" do
    test "version 1-M returns correct structure" do
      {total, ec_per_block, groups} = Spec.ec_info(1, :m)
      assert total == 16
      assert ec_per_block == 10
      assert groups == [{1, 16}]
    end

    test "version 5-Q has two groups" do
      {total, ec_per_block, groups} = Spec.ec_info(5, :q)
      assert total == 62
      assert ec_per_block == 18
      assert groups == [{2, 15}, {2, 16}]
    end

    test "version 40-L" do
      {total, ec_per_block, groups} = Spec.ec_info(40, :l)
      assert total == 2956
      assert ec_per_block == 30
      assert groups == [{19, 118}, {6, 119}]
    end
  end

  describe "total_data_codewords/2" do
    test "version 1 levels" do
      assert Spec.total_data_codewords(1, :l) == 19
      assert Spec.total_data_codewords(1, :m) == 16
      assert Spec.total_data_codewords(1, :q) == 13
      assert Spec.total_data_codewords(1, :h) == 9
    end
  end

  describe "capacity/3" do
    test "version 1-M alphanumeric capacity is 20" do
      assert Spec.capacity(1, :m, :alphanumeric) == 20
    end

    test "version 40-L numeric capacity is 7089" do
      assert Spec.capacity(40, :l, :numeric) == 7089
    end

    test "version 40-H byte capacity is 1273" do
      assert Spec.capacity(40, :h, :byte) == 1273
    end

    test "version 40-H kanji capacity is 784" do
      assert Spec.capacity(40, :h, :kanji) == 784
    end
  end

  describe "ec_level_bits/1" do
    test "returns correct 2-bit values" do
      assert Spec.ec_level_bits(:l) == 0b01
      assert Spec.ec_level_bits(:m) == 0b00
      assert Spec.ec_level_bits(:q) == 0b11
      assert Spec.ec_level_bits(:h) == 0b10
    end
  end
end
