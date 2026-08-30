defmodule Bnana.WidgetAnalyticsCache do
  @moduledoc false

  use GenServer

  alias Bnana.{PhoenixClient, WidgetStorage}

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    PhoenixClient.subscribe()
    WidgetStorage.cleanup()
    {:ok, empty_state()}
  end

  @impl true
  def handle_info({:phoenix_status, %{status: :connected}}, state) do
    {:noreply, request_analytics(state)}
  end

  def handle_info({:phoenix_reply, ref, "stats", "get-all", {:ok, stats}}, state) do
    state = if ref == state.stats_ref, do: %{state | stats: stats}, else: state
    {:noreply, maybe_write(state)}
  end

  def handle_info({:phoenix_reply, ref, "daily-stats", "get-all", {:ok, data}}, state) do
    state = if ref == state.daily_ref, do: %{state | daily: data["stats"] || []}, else: state
    {:noreply, maybe_write(state)}
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp request_analytics(state) do
    stats_ref = PhoenixClient.request("stats", "get-all", nil, self())

    daily_ref =
      PhoenixClient.request(
        "daily-stats",
        "get-all",
        %{"slug" => "main", "days" => 7},
        self()
      )

    %{state | stats_ref: stats_ref, daily_ref: daily_ref, stats: nil, daily: nil}
  end

  defp maybe_write(%{stats: stats, daily: daily} = state)
       when is_map(stats) and is_list(daily) do
    WidgetStorage.write(snapshot(stats, daily))
    state
  end

  defp maybe_write(state), do: state

  defp snapshot(stats, daily) do
    main = stats["main"] || %{}
    daily_views = daily |> Enum.take(-7) |> Enum.map(&number(&1["views"]))

    %{
      version: 1,
      updated_at: DateTime.utc_now() |> DateTime.truncate(:second) |> DateTime.to_iso8601(),
      total_views: number(main["views"]),
      today_views: List.last(daily_views) || 0,
      daily_views: daily_views
    }
  end

  defp number(value) when is_integer(value), do: value
  defp number(value) when is_float(value), do: round(value)
  defp number(_value), do: 0

  defp empty_state do
    %{stats_ref: nil, daily_ref: nil, stats: nil, daily: nil}
  end
end
