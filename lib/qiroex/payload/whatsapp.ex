defmodule Qiroex.Payload.WhatsApp do
  @moduledoc """
  WhatsApp message payload builder.

  Generates a WhatsApp URL for QR encoding that opens a chat with
  the specified phone number and optional pre-filled message.

  ## Format
      https://wa.me/<number>?text=<message>

  ## Examples
      {:ok, payload} = Qiroex.Payload.WhatsApp.encode(number: "1234567890")
      {:ok, payload} = Qiroex.Payload.WhatsApp.encode(number: "1234567890", message: "Hello!")
  """

  @behaviour Qiroex.Payload

  @impl true
  @spec encode(keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def encode(opts) do
    number = Keyword.get(opts, :number)
    message = Keyword.get(opts, :message)

    with :ok <- validate_number(number) do
      # Strip leading + and any non-digit characters for wa.me format
      clean_number = String.replace(number, ~r/[^\d]/, "")

      payload =
        if message && message != "" do
          "https://wa.me/#{clean_number}?text=#{URI.encode(message)}"
        else
          "https://wa.me/#{clean_number}"
        end

      {:ok, payload}
    end
  end

  defp validate_number(nil), do: {:error, "Phone number is required"}
  defp validate_number(""), do: {:error, "Phone number cannot be empty"}
  defp validate_number(number) when is_binary(number), do: :ok
  defp validate_number(_), do: {:error, "Phone number must be a string"}
end
