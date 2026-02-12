defmodule Qiroex.Payload.VCard do
  @moduledoc """
  vCard contact payload builder.

  Generates a vCard 3.0 format string for QR encoding, recognized by
  most contact applications.

  ## Format
      BEGIN:VCARD
      VERSION:3.0
      N:<last>;<first>
      FN:<full_name>
      ...
      END:VCARD

  ## Examples
      {:ok, payload} = Qiroex.Payload.VCard.encode(
        first_name: "John",
        last_name: "Doe",
        phone: "+1234567890",
        email: "john@example.com"
      )
  """

  @behaviour Qiroex.Payload

  @impl true
  @spec encode(keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def encode(opts) do
    first = Keyword.get(opts, :first_name, "")
    last = Keyword.get(opts, :last_name, "")

    with :ok <- validate_name(first, last) do
      lines =
        [
          "BEGIN:VCARD",
          "VERSION:3.0",
          "N:#{last};#{first};;;",
          "FN:#{full_name(first, last)}"
        ]
        |> maybe_add("ORG:", Keyword.get(opts, :org))
        |> maybe_add("TITLE:", Keyword.get(opts, :title))
        |> maybe_add_phone(Keyword.get(opts, :phone))
        |> maybe_add_phone_work(Keyword.get(opts, :work_phone))
        |> maybe_add("EMAIL:", Keyword.get(opts, :email))
        |> maybe_add_email_work(Keyword.get(opts, :work_email))
        |> maybe_add_address(opts)
        |> maybe_add("URL:", Keyword.get(opts, :url))
        |> maybe_add("NOTE:", Keyword.get(opts, :note))
        |> Kernel.++(["END:VCARD"])

      {:ok, Enum.join(lines, "\r\n")}
    end
  end

  defp validate_name("", ""), do: {:error, "At least one of first_name or last_name is required"}
  defp validate_name(_, _), do: :ok

  defp full_name(first, ""), do: first
  defp full_name("", last), do: last
  defp full_name(first, last), do: "#{first} #{last}"

  defp maybe_add(lines, _prefix, nil), do: lines
  defp maybe_add(lines, _prefix, ""), do: lines
  defp maybe_add(lines, prefix, value), do: lines ++ ["#{prefix}#{value}"]

  defp maybe_add_phone(lines, nil), do: lines
  defp maybe_add_phone(lines, ""), do: lines
  defp maybe_add_phone(lines, phone), do: lines ++ ["TEL;TYPE=CELL:#{phone}"]

  defp maybe_add_phone_work(lines, nil), do: lines
  defp maybe_add_phone_work(lines, ""), do: lines
  defp maybe_add_phone_work(lines, phone), do: lines ++ ["TEL;TYPE=WORK:#{phone}"]

  defp maybe_add_email_work(lines, nil), do: lines
  defp maybe_add_email_work(lines, ""), do: lines
  defp maybe_add_email_work(lines, email), do: lines ++ ["EMAIL;TYPE=WORK:#{email}"]

  defp maybe_add_address(lines, opts) do
    street = Keyword.get(opts, :street)
    city = Keyword.get(opts, :city)
    state = Keyword.get(opts, :state)
    zip = Keyword.get(opts, :zip)
    country = Keyword.get(opts, :country)

    if Enum.any?([street, city, state, zip, country], & &1) do
      addr = "ADR;TYPE=HOME:;;#{street || ""};#{city || ""};#{state || ""};#{zip || ""};#{country || ""}"
      lines ++ [addr]
    else
      lines
    end
  end
end
