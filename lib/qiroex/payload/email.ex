defmodule Qiroex.Payload.Email do
  @moduledoc """
  Email payload builder.

  Generates a `mailto:` URI for QR encoding, optionally including
  subject and body fields.

  ## Format
      mailto:<address>?subject=<subject>&body=<body>

  ## Examples
      {:ok, payload} = Qiroex.Payload.Email.encode(to: "user@example.com")
      {:ok, payload} = Qiroex.Payload.Email.encode(
        to: "user@example.com",
        subject: "Hello",
        body: "How are you?"
      )
  """

  @behaviour Qiroex.Payload

  @impl true
  @spec encode(keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def encode(opts) do
    to = Keyword.get(opts, :to)
    subject = Keyword.get(opts, :subject)
    body = Keyword.get(opts, :body)
    cc = Keyword.get(opts, :cc)
    bcc = Keyword.get(opts, :bcc)

    with :ok <- validate_email(to) do
      params =
        [
          if(subject, do: {"subject", subject}),
          if(body, do: {"body", body}),
          if(cc, do: {"cc", cc}),
          if(bcc, do: {"bcc", bcc})
        ]
        |> Enum.filter(& &1)

      query =
        if params == [] do
          ""
        else
          "?" <> Enum.map_join(params, "&", fn {k, v} -> "#{k}=#{URI.encode_www_form(v)}" end)
        end

      {:ok, "mailto:#{to}#{query}"}
    end
  end

  defp validate_email(nil), do: {:error, "Email address is required"}
  defp validate_email(""), do: {:error, "Email address cannot be empty"}

  defp validate_email(email) when is_binary(email) do
    if String.contains?(email, "@") do
      :ok
    else
      {:error, "Invalid email address: #{email}"}
    end
  end

  defp validate_email(_), do: {:error, "Email address must be a string"}
end
