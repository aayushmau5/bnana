defmodule Bnana.LastTime do
  @moduledoc "Calendar-day counters and their occurrence history."
  alias Bnana.LastTimeRepo
  alias Ecto.Adapters.SQL

  def today, do: Bnana.Memories.local_today()

  def list do
    query!("""
    SELECT i.id, i.name, i.interval_days, i.pinned, MAX(e.occurred_on) AS last_on
    FROM last_time_items i LEFT JOIN last_time_events e ON e.item_id = i.id
    GROUP BY i.id ORDER BY i.pinned DESC, i.id
    """)
  end

  def history(id) do
    query!(
      """
      SELECT id, occurred_on, recorded_at FROM last_time_events
      WHERE item_id = ? ORDER BY occurred_on DESC, recorded_at DESC, id DESC
      """,
      [id]
    )
  end

  def save(id, name, rhythm) do
    name = String.trim(name)

    with true <- String.length(name) in 1..80,
         {:ok, interval} <- parse_interval(String.trim(rhythm)) do
      if id do
        mutate("UPDATE last_time_items SET name = ?, interval_days = ? WHERE id = ?", [
          name,
          interval,
          id
        ])
      else
        mutate("INSERT INTO last_time_items (name, interval_days) VALUES (?, ?)", [name, interval])
      end
    else
      _ ->
        {:error, "Use a name of 1–80 characters and a rhythm of 1–3650 days, or leave it blank."}
    end
  end

  def pin(id) do
    case mutate(
           """
           UPDATE last_time_items SET pinned = 1 - pinned
           WHERE id = ? AND (pinned = 1 OR (SELECT COUNT(*) FROM last_time_items WHERE pinned = 1) < 3)
           """,
           [id]
         ) do
      {:ok, %{num_rows: 0}} ->
        {:error, "Unpin an item first. Your widget holds three favourites."}

      result ->
        result
    end
  end

  def delete(id), do: mutate("DELETE FROM last_time_items WHERE id = ?", [id])

  def log(id, date \\ today()) do
    with {:ok, date} <- parse_date(date),
         true <- date.year in 1..9999 and Date.compare(date, today()) != :gt do
      event_id = Ecto.UUID.generate()

      case mutate(
             "INSERT INTO last_time_events (id, item_id, occurred_on, recorded_at) VALUES (?, ?, ?, ?)",
             [event_id, id, Date.to_iso8601(date), System.system_time(:microsecond)]
           ) do
        {:ok, _} -> {:ok, event_id}
        error -> error
      end
    else
      _ -> {:error, "Choose a real date on or before today (YYYY-MM-DD)."}
    end
  end

  def undo(event_id), do: mutate("DELETE FROM last_time_events WHERE id = ?", [event_id])

  def elapsed(nil, _today), do: "Not logged yet"

  def elapsed(date, today) do
    case days_since(date, today) do
      0 -> "Today"
      1 -> "Yesterday"
      days -> "#{days} days ago"
    end
  end

  def due?(%{"last_on" => nil}, _today), do: false
  def due?(%{"interval_days" => nil}, _today), do: false
  def due?(item, today), do: days_since(item["last_on"], today) >= item["interval_days"]

  defp days_since(date, today), do: max(Date.diff(today, Date.from_iso8601!(date)), 0)
  defp parse_date(%Date{} = date), do: {:ok, date}
  defp parse_date(date) when is_binary(date), do: Date.from_iso8601(date)
  defp parse_date(_), do: :error
  defp parse_interval(""), do: {:ok, nil}

  defp parse_interval(value) do
    case Integer.parse(String.trim(value)) do
      {days, ""} when days in 1..3650 -> {:ok, days}
      _ -> :error
    end
  end

  defp mutate(sql, params) do
    case SQL.query(LastTimeRepo, sql, params) do
      {:ok, result} ->
        notify_widget()

        {:ok, result}

      {:error, _reason} ->
        {:error, "Couldn’t save that change. Please try again."}
    end
  end

  defp notify_widget do
    # Atomic rename wakes the app's directory watcher even when SQLite reuses its WAL.
    if directory = System.get_env("BNANA_WIDGET_DIR") do
      path = Path.join(directory, "last_time.changed")
      temporary = path <> ".#{System.unique_integer([:positive])}"
      with :ok <- File.write(temporary, ""), do: File.rename(temporary, path)
      File.rm(temporary)
    end
  end

  defp query!(sql, params \\ []) do
    %{columns: columns, rows: rows} = SQL.query!(LastTimeRepo, sql, params)
    Enum.map(rows, &Map.new(Enum.zip(columns, &1)))
  end
end
