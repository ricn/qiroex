defmodule Qiroex.Payload.VEvent do
  @moduledoc """
  Calendar event (vEvent) payload builder.

  Generates a vCalendar/iCalendar event string for QR encoding,
  recognized by most calendar applications.

  ## Format
      BEGIN:VEVENT
      SUMMARY:<title>
      DTSTART:<start>
      DTEND:<end>
      LOCATION:<location>
      DESCRIPTION:<description>
      END:VEVENT

  ## Examples
      {:ok, payload} = Qiroex.Payload.VEvent.encode(
        summary: "Team Meeting",
        start: ~U[2026-03-01 10:00:00Z],
        end: ~U[2026-03-01 11:00:00Z],
        location: "Conference Room A"
      )
  """

  @behaviour Qiroex.Payload

  @impl true
  @spec encode(keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def encode(opts) do
    summary = Keyword.get(opts, :summary)
    dt_start = Keyword.get(opts, :start)
    dt_end = Keyword.get(opts, :end)
    location = Keyword.get(opts, :location)
    description = Keyword.get(opts, :description)

    with :ok <- validate_required(:summary, summary),
         :ok <- validate_required(:start, dt_start),
         :ok <- validate_datetime(dt_start) do
      lines =
        [
          "BEGIN:VEVENT",
          "SUMMARY:#{summary}",
          "DTSTART:#{format_datetime(dt_start)}"
        ]
        |> maybe_add("DTEND:", dt_end, &format_datetime/1)
        |> maybe_add_raw("LOCATION:", location)
        |> maybe_add_raw("DESCRIPTION:", description)
        |> Kernel.++(["END:VEVENT"])

      {:ok, Enum.join(lines, "\r\n")}
    end
  end

  defp validate_required(field, nil), do: {:error, "#{field} is required"}
  defp validate_required(field, "") when is_atom(field), do: {:error, "#{field} is required"}
  defp validate_required(_, _), do: :ok

  defp validate_datetime(%DateTime{}), do: :ok
  defp validate_datetime(%NaiveDateTime{}), do: :ok

  defp validate_datetime(str) when is_binary(str) do
    # Accept pre-formatted strings like "20260301T100000Z"
    :ok
  end

  defp validate_datetime(_), do: {:error, "start must be a DateTime, NaiveDateTime, or formatted string"}

  defp format_datetime(%DateTime{} = dt) do
    Calendar.strftime(dt, "%Y%m%dT%H%M%SZ")
  end

  defp format_datetime(%NaiveDateTime{} = dt) do
    Calendar.strftime(dt, "%Y%m%dT%H%M%S")
  end

  defp format_datetime(str) when is_binary(str), do: str

  defp maybe_add(lines, _prefix, nil, _formatter), do: lines

  defp maybe_add(lines, prefix, value, formatter) do
    lines ++ ["#{prefix}#{formatter.(value)}"]
  end

  defp maybe_add_raw(lines, _prefix, nil), do: lines
  defp maybe_add_raw(lines, _prefix, ""), do: lines
  defp maybe_add_raw(lines, prefix, value), do: lines ++ ["#{prefix}#{value}"]
end
