defmodule Qiroex.Payload.URL do
  @moduledoc """
  URL payload builder.

  Generates a URL string for QR encoding. Prepends `https://` if no scheme is present.

  ## Examples
      {:ok, payload} = Qiroex.Payload.URL.encode(url: "https://example.com")
      {:ok, payload} = Qiroex.Payload.URL.encode(url: "example.com")
      #=> {:ok, "https://example.com"}
  """

  @behaviour Qiroex.Payload

  @impl true
  @spec encode(keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def encode(opts) do
    url = Keyword.get(opts, :url)

    with :ok <- validate_url(url) do
      {:ok, normalize_url(url)}
    end
  end

  defp validate_url(nil), do: {:error, "URL is required"}
  defp validate_url(""), do: {:error, "URL cannot be empty"}
  defp validate_url(url) when is_binary(url), do: :ok
  defp validate_url(_), do: {:error, "URL must be a string"}

  defp normalize_url(url) do
    if String.contains?(url, "://") do
      url
    else
      "https://#{url}"
    end
  end
end
