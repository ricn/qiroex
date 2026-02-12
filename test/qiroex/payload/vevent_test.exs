defmodule Qiroex.Payload.VEventTest do
  use ExUnit.Case, async: true

  alias Qiroex.Payload.VEvent

  describe "encode/1" do
    test "basic event with DateTime" do
      start = ~U[2026-03-01 10:00:00Z]
      {:ok, payload} = VEvent.encode(summary: "Meeting", start: start)

      assert String.contains?(payload, "BEGIN:VEVENT")
      assert String.contains?(payload, "SUMMARY:Meeting")
      assert String.contains?(payload, "DTSTART:20260301T100000Z")
      assert String.contains?(payload, "END:VEVENT")
    end

    test "with end time" do
      start = ~U[2026-03-01 10:00:00Z]
      stop = ~U[2026-03-01 11:00:00Z]
      {:ok, payload} = VEvent.encode(summary: "Meeting", start: start, end: stop)

      assert String.contains?(payload, "DTEND:20260301T110000Z")
    end

    test "with NaiveDateTime (no Z suffix)" do
      start = ~N[2026-03-01 10:00:00]
      {:ok, payload} = VEvent.encode(summary: "Local Event", start: start)

      assert String.contains?(payload, "DTSTART:20260301T100000")
      refute String.contains?(payload, "DTSTART:20260301T100000Z")
    end

    test "with location and description" do
      {:ok, payload} =
        VEvent.encode(
          summary: "Meeting",
          start: ~U[2026-03-01 10:00:00Z],
          location: "Room A",
          description: "Weekly sync"
        )

      assert String.contains?(payload, "LOCATION:Room A")
      assert String.contains?(payload, "DESCRIPTION:Weekly sync")
    end

    test "with pre-formatted string datetime" do
      {:ok, payload} =
        VEvent.encode(
          summary: "Event",
          start: "20260301T100000Z"
        )

      assert String.contains?(payload, "DTSTART:20260301T100000Z")
    end

    test "uses CRLF line endings" do
      {:ok, payload} = VEvent.encode(summary: "E", start: ~U[2026-01-01 00:00:00Z])
      assert String.contains?(payload, "\r\n")
    end

    test "error when summary is missing" do
      assert {:error, _} = VEvent.encode(start: ~U[2026-01-01 00:00:00Z])
    end

    test "error when start is missing" do
      assert {:error, _} = VEvent.encode(summary: "Event")
    end
  end
end
