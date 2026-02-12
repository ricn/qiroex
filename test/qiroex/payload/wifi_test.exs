defmodule Qiroex.Payload.WiFiTest do
  use ExUnit.Case, async: true

  alias Qiroex.Payload.WiFi

  describe "encode/1" do
    test "WPA with ssid and password" do
      assert {:ok, payload} = WiFi.encode(ssid: "MyNetwork", password: "secret123", auth: :wpa)
      assert payload == "WIFI:T:WPA;S:MyNetwork;P:secret123;;"
    end

    test "WEP auth type" do
      {:ok, payload} = WiFi.encode(ssid: "Net", password: "key", auth: :wep)
      assert String.contains?(payload, "T:WEP")
    end

    test "open/no password" do
      {:ok, payload} = WiFi.encode(ssid: "OpenNet", auth: :nopass)
      assert payload == "WIFI:T:nopass;S:OpenNet;P:;;"
    end

    test "defaults to WPA auth" do
      {:ok, payload} = WiFi.encode(ssid: "Net", password: "pass")
      assert String.contains?(payload, "T:WPA")
    end

    test "hidden network" do
      {:ok, payload} = WiFi.encode(ssid: "Hidden", password: "pass", hidden: true)
      assert String.contains?(payload, "H:true;")
    end

    test "escapes special chars in SSID" do
      {:ok, payload} = WiFi.encode(ssid: "My;Network", password: "p")
      assert String.contains?(payload, "S:My\\;Network")
    end

    test "escapes special chars in password" do
      {:ok, payload} = WiFi.encode(ssid: "Net", password: "pa:ss;word")
      assert String.contains?(payload, "P:pa\\:ss\\;word")
    end

    test "error when SSID is missing" do
      assert {:error, "SSID is required"} = WiFi.encode([])
    end

    test "error when SSID is empty" do
      assert {:error, "SSID cannot be empty"} = WiFi.encode(ssid: "")
    end

    test "error for invalid auth type" do
      assert {:error, _} = WiFi.encode(ssid: "Net", auth: :invalid)
    end
  end
end
