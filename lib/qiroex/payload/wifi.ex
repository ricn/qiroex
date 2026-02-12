defmodule Qiroex.Payload.WiFi do
  @moduledoc """
  WiFi network payload builder.

  Generates the `WIFI:` string format recognized by most QR code readers
  to automatically connect to a WiFi network.

  ## Format
      WIFI:T:<auth>;S:<ssid>;P:<password>;H:<hidden>;;

  ## Examples
      {:ok, payload} = Qiroex.Payload.WiFi.encode(ssid: "MyNetwork", password: "secret", auth: :wpa)
      #=> {:ok, "WIFI:T:WPA;S:MyNetwork;P:secret;;"}
  """

  @behaviour Qiroex.Payload

  @impl true
  @spec encode(keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def encode(opts) do
    ssid = Keyword.get(opts, :ssid)
    password = Keyword.get(opts, :password, "")
    auth = Keyword.get(opts, :auth, :wpa)
    hidden = Keyword.get(opts, :hidden, false)

    with :ok <- validate_ssid(ssid),
         :ok <- validate_auth(auth) do
      auth_str = auth_to_string(auth)
      hidden_str = if hidden, do: "H:true;", else: ""

      payload =
        "WIFI:T:#{auth_str};S:#{Qiroex.Payload.escape(ssid)};P:#{Qiroex.Payload.escape(password)};#{hidden_str};"

      {:ok, payload}
    end
  end

  defp validate_ssid(nil), do: {:error, "SSID is required"}
  defp validate_ssid(""), do: {:error, "SSID cannot be empty"}
  defp validate_ssid(ssid) when is_binary(ssid), do: :ok
  defp validate_ssid(_), do: {:error, "SSID must be a string"}

  defp validate_auth(auth) when auth in [:wpa, :wep, :nopass, :wpa2_eap], do: :ok
  defp validate_auth(auth), do: {:error, "Invalid auth type: #{inspect(auth)}"}

  defp auth_to_string(:wpa), do: "WPA"
  defp auth_to_string(:wep), do: "WEP"
  defp auth_to_string(:nopass), do: "nopass"
  defp auth_to_string(:wpa2_eap), do: "WPA2-EAP"
end
