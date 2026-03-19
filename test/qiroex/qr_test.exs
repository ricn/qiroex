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

    test "rejects legacy :ec_level key" do
      assert {:error, msg} = QR.encode("TEST", ec_level: :q)
      assert msg =~ ":ec_level"
      assert msg =~ ":level"
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

    test "matches the published V5-Q interleaving example" do
      data_codewords = [
        67,
        85,
        70,
        134,
        87,
        38,
        85,
        194,
        119,
        50,
        6,
        18,
        6,
        103,
        38,
        246,
        246,
        66,
        7,
        118,
        134,
        242,
        7,
        38,
        86,
        22,
        198,
        199,
        146,
        6,
        182,
        230,
        247,
        119,
        50,
        7,
        118,
        134,
        87,
        38,
        82,
        6,
        134,
        151,
        50,
        7,
        70,
        247,
        118,
        86,
        194,
        6,
        151,
        50,
        224,
        236,
        17,
        236,
        17,
        236,
        17,
        236
      ]

      expected = [
        67,
        246,
        182,
        70,
        85,
        246,
        230,
        247,
        70,
        66,
        247,
        118,
        134,
        7,
        119,
        86,
        87,
        118,
        50,
        194,
        38,
        134,
        7,
        6,
        85,
        242,
        118,
        151,
        194,
        7,
        134,
        50,
        119,
        38,
        87,
        224,
        50,
        86,
        38,
        236,
        6,
        22,
        82,
        17,
        18,
        198,
        6,
        236,
        6,
        199,
        134,
        17,
        103,
        146,
        151,
        236,
        38,
        6,
        50,
        17,
        7,
        236,
        213,
        87,
        148,
        140,
        199,
        204,
        116,
        100,
        11,
        96,
        177,
        250,
        45,
        60,
        212,
        247,
        115,
        202,
        76,
        108,
        247,
        182,
        133,
        131,
        241,
        124,
        75,
        37,
        223,
        157,
        242,
        104,
        229,
        200,
        238,
        253,
        248,
        134,
        76,
        113,
        154,
        27,
        195,
        111,
        117,
        129,
        230,
        235,
        154,
        209,
        189,
        197,
        111,
        17,
        10,
        83,
        86,
        163,
        108,
        6,
        161,
        163,
        240,
        205,
        111,
        120,
        192,
        89,
        39,
        133,
        141,
        74
      ]

      assert QR.generate_ec_and_interleave(data_codewords, 5, :q) == expected
    end
  end

  describe "published matrix snapshots" do
    test "matches the published HELLO WORLD version 1 level Q output" do
      expected = [
        "00000000000000000000000000000",
        "00000000000000000000000000000",
        "00000000000000000000000000000",
        "00000000000000000000000000000",
        "00001111111000010011111110000",
        "00001000001011001010000010000",
        "00001011101001011010111010000",
        "00001011101011111010111010000",
        "00001011101011010010111010000",
        "00001000001001001010000010000",
        "00001111111010101011111110000",
        "00000000000011011000000000000",
        "00000101111011001110110100000",
        "00001011110100001111011100000",
        "00000010101100010011000000000",
        "00001011010001011000110000000",
        "00001101111111101110111110000",
        "00000000000010001001010000000",
        "00001111111001100110011110000",
        "00001000001010100100101110000",
        "00001011101011010010001110000",
        "00001011101010111000101000000",
        "00001011101001000010000110000",
        "00001000001011100111001100000",
        "00001111111001010000000100000",
        "00000000000000000000000000000",
        "00000000000000000000000000000",
        "00000000000000000000000000000",
        "00000000000000000000000000000"
      ]

      assert {:ok, qr} = QR.encode("HELLO WORLD", level: :q)
      assert qr.version == 1
      assert qr.mask == 6

      assert Qiroex.to_matrix!("HELLO WORLD", level: :q) ==
               Enum.map(expected, fn row ->
                 row
                 |> String.graphemes()
                 |> Enum.map(&String.to_integer/1)
               end)
    end
  end
end
