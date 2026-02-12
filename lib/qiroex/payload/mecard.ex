defmodule Qiroex.Payload.MeCard do
  @moduledoc """
  MeCard contact payload builder.

  Generates a MECARD format string, a simpler alternative to vCard
  commonly used for QR code contact sharing on mobile devices.

  ## Format
      MECARD:N:<name>;TEL:<phone>;EMAIL:<email>;URL:<url>;ADR:<address>;NOTE:<note>;;

  ## Examples
      {:ok, payload} = Qiroex.Payload.MeCard.encode(
        name: "Doe,John",
        phone: "+1234567890",
        email: "john@example.com"
      )
  """

  @behaviour Qiroex.Payload

  @impl true
  @spec encode(keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def encode(opts) do
    name = Keyword.get(opts, :name)

    with :ok <- validate_name(name) do
      parts =
        ["MECARD:N:#{Qiroex.Payload.escape(name)}"]
        |> maybe_add("TEL:", Keyword.get(opts, :phone))
        |> maybe_add("EMAIL:", Keyword.get(opts, :email))
        |> maybe_add("URL:", Keyword.get(opts, :url))
        |> maybe_add("ADR:", Keyword.get(opts, :address))
        |> maybe_add("NOTE:", Keyword.get(opts, :note))
        |> maybe_add("BDAY:", Keyword.get(opts, :birthday))
        |> maybe_add("ORG:", Keyword.get(opts, :org))

      {:ok, Enum.join(parts, ";") <> ";;"}
    end
  end

  defp validate_name(nil), do: {:error, "Name is required"}
  defp validate_name(""), do: {:error, "Name cannot be empty"}
  defp validate_name(name) when is_binary(name), do: :ok
  defp validate_name(_), do: {:error, "Name must be a string"}

  defp maybe_add(parts, _prefix, nil), do: parts
  defp maybe_add(parts, _prefix, ""), do: parts
  defp maybe_add(parts, prefix, value), do: parts ++ ["#{prefix}#{Qiroex.Payload.escape(value)}"]
end
