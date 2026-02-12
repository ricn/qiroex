defmodule Qiroex.Payload.SMS do
  @moduledoc """
  SMS payload builder.

  Generates an `smsto:` URI for QR encoding, optionally including a message body.

  ## Format
      smsto:<number>:<message>

  ## Examples
      {:ok, payload} = Qiroex.Payload.SMS.encode(number: "+1234567890")
      {:ok, payload} = Qiroex.Payload.SMS.encode(number: "+1234567890", message: "Hello!")
  """

  @behaviour Qiroex.Payload

  @impl true
  @spec encode(keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def encode(opts) do
    number = Keyword.get(opts, :number)
    message = Keyword.get(opts, :message)

    with :ok <- validate_number(number) do
      payload =
        if message && message != "" do
          "smsto:#{number}:#{message}"
        else
          "smsto:#{number}"
        end

      {:ok, payload}
    end
  end

  defp validate_number(nil), do: {:error, "Phone number is required"}
  defp validate_number(""), do: {:error, "Phone number cannot be empty"}
  defp validate_number(number) when is_binary(number), do: :ok
  defp validate_number(_), do: {:error, "Phone number must be a string"}
end
