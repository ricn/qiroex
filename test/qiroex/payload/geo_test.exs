defmodule Qiroex.Payload.GeoTest do
  use ExUnit.Case, async: true

  alias Qiroex.Payload.Geo

  describe "encode/1" do
    test "basic coordinates" do
      {:ok, payload} = Geo.encode(latitude: 40.7128, longitude: -74.006)
      assert String.starts_with?(payload, "geo:40.712800,-74.006000")
    end

    test "integer coordinates" do
      {:ok, payload} = Geo.encode(latitude: 0, longitude: 0)
      assert payload == "geo:0,0"
    end

    test "with query label" do
      {:ok, payload} = Geo.encode(latitude: 48.8566, longitude: 2.3522, query: "Eiffel Tower")
      assert String.contains?(payload, "?q=Eiffel%20Tower")
    end

    test "error when latitude is missing" do
      assert {:error, _} = Geo.encode(longitude: 0)
    end

    test "error when longitude is missing" do
      assert {:error, _} = Geo.encode(latitude: 0)
    end

    test "error when latitude out of range" do
      assert {:error, _} = Geo.encode(latitude: 91, longitude: 0)
      assert {:error, _} = Geo.encode(latitude: -91, longitude: 0)
    end

    test "error when longitude out of range" do
      assert {:error, _} = Geo.encode(latitude: 0, longitude: 181)
      assert {:error, _} = Geo.encode(latitude: 0, longitude: -181)
    end

    test "boundary values accepted" do
      assert {:ok, _} = Geo.encode(latitude: 90, longitude: 180)
      assert {:ok, _} = Geo.encode(latitude: -90, longitude: -180)
    end
  end
end
