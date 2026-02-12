defmodule Qiroex.QRTest do
  use ExUnit.Case, async: true

  alias Qiroex.QR

  describe "encode/2" do
    test "encodes HELLO WORLD successfully" do
      assert {:ok, qr} = QR.encode("HELLO WORLD", level: :m)
      assert qr.version >= 1
      assert qr.ec_level == :m
      assert qr.mask in 0..7
      assert %Qiroex.Matrix{} = qr.matrix
    end

    test "encodes numeric data" do
      assert {:ok, qr} = QR.encode("01234567", level: :m)
      assert qr.version >= 1
    end

    test "encodes byte data" do
      assert {:ok, qr} = QR.encode("hello world", level: :l)
      assert qr.version >= 1
    end

    test "defaults to :m error correction" do
      assert {:ok, qr} = QR.encode("TEST")
      assert qr.ec_level == :m
    end

    test "respects specified EC level with :level key" do
      assert {:ok, qr_l} = QR.encode("TEST", level: :l)
      assert {:ok, qr_h} = QR.encode("TEST", level: :h)
      assert qr_l.ec_level == :l
      assert qr_h.ec_level == :h
    end

    test "respects specified EC level with :ec_level key" do
      assert {:ok, qr} = QR.encode("TEST", ec_level: :q)
      assert qr.ec_level == :q
    end

    test "respects specified version" do
      assert {:ok, qr} = QR.encode("TEST", version: 5)
      assert qr.version == 5
    end

    test "returns error for data too large" do
      # 7089 numeric digits is the max for V40-L
      huge = String.duplicate("A", 5000)
      assert {:error, _reason} = QR.encode(huge, level: :h)
    end

    test "returns error for empty data" do
      assert {:error, _reason} = QR.encode("")
    end

    test "matrix has correct dimensions" do
      {:ok, qr} = QR.encode("TEST", level: :m)
      expected_size = 4 * qr.version + 17
      assert qr.matrix.size == expected_size
    end
  end

  describe "to_matrix/2" do
    test "returns 2D list with quiet zone" do
      {:ok, qr} = QR.encode("HI", level: :l)
      rows = QR.to_matrix(qr)

      # +8 for 4-module quiet zone on each side
      expected_size = 4 * qr.version + 17 + 8
      assert length(rows) == expected_size
      assert length(hd(rows)) == expected_size
    end

    test "quiet zone is all zeros" do
      {:ok, qr} = QR.encode("HI", level: :l)
      rows = QR.to_matrix(qr, 4)

      # Top quiet zone row should be all zeros
      assert Enum.all?(hd(rows), &(&1 == 0))
      # Bottom quiet zone row should be all zeros
      assert Enum.all?(List.last(rows), &(&1 == 0))
    end

    test "custom quiet zone size" do
      {:ok, qr} = QR.encode("HI", level: :l)
      rows = QR.to_matrix(qr, 2)

      # +4 for 2-module quiet zone on each side
      expected_size = 4 * qr.version + 17 + 4
      assert length(rows) == expected_size
    end
  end

  describe "generate_ec_and_interleave/3" do
    test "produces correct number of total codewords for V1-M" do
      # V1-M: 26 total codewords (16 data + 10 EC)
      data_codewords = List.duplicate(0, 16)
      result = QR.generate_ec_and_interleave(data_codewords, 1, :m)

      assert length(result) == 26
    end

    test "produces correct number of total codewords for V5-Q" do
      {total_data, _ec_per_block, _groups} = Qiroex.Spec.ec_info(5, :q)
      data_codewords = List.duplicate(0, total_data)

      result = QR.generate_ec_and_interleave(data_codewords, 5, :q)

      total_codewords = Qiroex.Spec.total_codewords(5)
      assert length(result) == total_codewords
    end
  end
end
