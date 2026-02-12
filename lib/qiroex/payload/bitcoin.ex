defmodule Qiroex.Payload.Bitcoin do
  @moduledoc """
  Bitcoin payment payload builder.

  Generates a BIP-21 `bitcoin:` URI for QR encoding, recognized by
  Bitcoin wallet applications.

  ## Format
      bitcoin:<address>?amount=<amount>&label=<label>&message=<message>

  ## Examples
      {:ok, payload} = Qiroex.Payload.Bitcoin.encode(
        address: "1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa",
        amount: 0.001,
        label: "Donation"
      )
  """

  @behaviour Qiroex.Payload

  @impl true
  @spec encode(keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def encode(opts) do
    address = Keyword.get(opts, :address)
    amount = Keyword.get(opts, :amount)
    label = Keyword.get(opts, :label)
    message = Keyword.get(opts, :message)

    with :ok <- validate_address(address) do
      params =
        [
          if(amount, do: {"amount", format_amount(amount)}),
          if(label, do: {"label", URI.encode(label)}),
          if(message, do: {"message", URI.encode(message)})
        ]
        |> Enum.filter(& &1)

      query =
        if params == [] do
          ""
        else
          "?" <> Enum.map_join(params, "&", fn {k, v} -> "#{k}=#{v}" end)
        end

      {:ok, "bitcoin:#{address}#{query}"}
    end
  end

  defp validate_address(nil), do: {:error, "Bitcoin address is required"}
  defp validate_address(""), do: {:error, "Bitcoin address cannot be empty"}
  defp validate_address(addr) when is_binary(addr), do: :ok
  defp validate_address(_), do: {:error, "Bitcoin address must be a string"}

  defp format_amount(amount) when is_float(amount) do
    :erlang.float_to_binary(amount, decimals: 8)
    |> String.trim_trailing("0")
    |> String.trim_trailing(".")
  end

  defp format_amount(amount) when is_integer(amount), do: Integer.to_string(amount)
end
