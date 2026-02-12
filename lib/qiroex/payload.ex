defmodule Qiroex.Payload do
  @moduledoc """
  Behaviour and shared utilities for QR code payload builders.

  Payload builders encode structured data (WiFi credentials, contact info, etc.)
  into the string formats expected by QR code readers.
  """

  @doc "Encodes the payload into a string suitable for QR encoding."
  @callback encode(keyword()) :: {:ok, String.t()} | {:error, String.t()}

  @doc """
  Escapes special characters in a value for use in QR payloads.

  Escapes `\\`, `;`, `,`, and `:` with a backslash prefix.
  """
  @spec escape(String.t()) :: String.t()
  def escape(value) when is_binary(value) do
    value
    |> String.replace("\\", "\\\\")
    |> String.replace(";", "\\;")
    |> String.replace(",", "\\,")
    |> String.replace(":", "\\:")
  end

  def escape(value), do: to_string(value)
end
