defmodule Qiroex.Payload.Geo do
  @moduledoc """
  Geographic location payload builder.

  Generates a `geo:` URI for QR encoding, recognized by mapping applications.

  ## Format
      geo:<latitude>,<longitude>
      geo:<latitude>,<longitude>?q=<query>

  ## Examples
      {:ok, payload} = Qiroex.Payload.Geo.encode(latitude: 40.7128, longitude: -74.0060)
      {:ok, payload} = Qiroex.Payload.Geo.encode(latitude: 48.8566, longitude: 2.3522, query: "Eiffel Tower")
  """

  @behaviour Qiroex.Payload

  @impl true
  @spec encode(keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def encode(opts) do
    lat = Keyword.get(opts, :latitude)
    lng = Keyword.get(opts, :longitude)
    query = Keyword.get(opts, :query)

    with :ok <- validate_coordinate(:latitude, lat, -90, 90),
         :ok <- validate_coordinate(:longitude, lng, -180, 180) do
      lat_s = format_number(lat)
      lng_s = format_number(lng)

      payload =
        if query && query != "" do
          "geo:#{lat_s},#{lng_s}?q=#{URI.encode(query)}"
        else
          "geo:#{lat_s},#{lng_s}"
        end

      {:ok, payload}
    end
  end

  defp validate_coordinate(name, nil, _min, _max), do: {:error, "#{name} is required"}

  defp validate_coordinate(name, val, min, max) when is_number(val) do
    if val >= min and val <= max do
      :ok
    else
      {:error, "#{name} must be between #{min} and #{max}"}
    end
  end

  defp validate_coordinate(name, _, _min, _max), do: {:error, "#{name} must be a number"}

  defp format_number(n) when is_float(n), do: :erlang.float_to_binary(n, decimals: 6)
  defp format_number(n) when is_integer(n), do: Integer.to_string(n)
end
