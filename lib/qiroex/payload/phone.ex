defmodule Qiroex.Payload.Phone do
  @moduledoc """
  Phone call payload builder.

  Generates a `tel:` URI for QR encoding.

  ## Format
      tel:<number>

  ## Examples
      {:ok, payload} = Qiroex.Payload.Phone.encode(number: "+1234567890")
  """

  @behaviour Qiroex.Payload

  @impl true
  @spec encode(keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def encode(opts) do
    number = Keyword.get(opts, :number)

    with :ok <- validate_number(number) do
      {:ok, "tel:#{number}"}
    end
  end

  defp validate_number(nil), do: {:error, "Phone number is required"}
  defp validate_number(""), do: {:error, "Phone number cannot be empty"}
  defp validate_number(number) when is_binary(number), do: :ok
  defp validate_number(_), do: {:error, "Phone number must be a string"}
end
