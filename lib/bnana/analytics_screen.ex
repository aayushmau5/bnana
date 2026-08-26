defmodule Bnana.AnalyticsScreen do
  @moduledoc "Native stats, daily chart, and device breakdowns."

  use Mob.Screen

  alias Bnana.{PhoenixClient, RemoteUI}

  @display_font "PlayfairDisplay-Regular"
  @ui_font "ShareTechMono-Regular"

  def mount(_params, _session, socket) do
    PhoenixClient.subscribe()
    refresh()

    {:ok,
     socket
     |> Mob.Socket.assign(:stats, nil)
     |> Mob.Socket.assign(:daily, nil)
     |> Mob.Socket.assign(:devices, nil)
     |> Mob.Socket.assign(:blogs_expanded, false)
     |> Mob.Socket.assign(:error, nil)}
  end

  def render(assigns) do
    content = dashboard(assigns)

    ~MOB"""
    <Column background={:background} fill_width={true} fill_height={true}>
      {RemoteUI.header("Analytics")}
      <Box background={:background} fill_width={true} fill_height={true} align="top">
        <Scroll id="analytics_scroll" background={:background}>
          <Column padding={:space_lg} fill_width={true}>
            {RemoteUI.intro("How the garden moves.", "Live totals, the last thirty days, and the shapes of visiting devices.")}
            <Spacer size={22} />
            {content}
            <Spacer size={:space_xl} />
          </Column>
        </Scroll>
      </Box>
    </Column>
    """
  end

  def handle_info({:tap, :back}, socket), do: {:noreply, Mob.Socket.pop_screen(socket)}

  def handle_info({:tap, :refresh}, socket) do
    refresh()
    {:noreply, Mob.Socket.assign(socket, :error, nil)}
  end

  def handle_info({:tap, :toggle_blog_breakdown}, socket) do
    {:noreply, Mob.Socket.assign(socket, :blogs_expanded, !socket.assigns.blogs_expanded)}
  end

  def handle_info({:phoenix_reply, _ref, "stats", "get-all", {:ok, stats}}, socket) do
    {:noreply, socket |> Mob.Socket.assign(:stats, stats) |> Mob.Socket.assign(:error, nil)}
  end

  def handle_info({:phoenix_reply, _ref, "daily-stats", "get-all", {:ok, data}}, socket) do
    {:noreply,
     socket |> Mob.Socket.assign(:daily, data["stats"] || []) |> Mob.Socket.assign(:error, nil)}
  end

  def handle_info({:phoenix_reply, _ref, "devices", "get-all", {:ok, devices}}, socket) do
    {:noreply, socket |> Mob.Socket.assign(:devices, devices) |> Mob.Socket.assign(:error, nil)}
  end

  def handle_info({:phoenix_reply, _ref, _event, _action, {:error, reason}}, socket) do
    {:noreply,
     Mob.Socket.assign(socket, :error, "Could not load analytics: #{format_reason(reason)}")}
  end

  def handle_info({:phoenix_event, event, _payload}, socket)
      when event in ["stats-updated", "presence-updated"] do
    refresh()
    {:noreply, socket}
  end

  def handle_info({:phoenix_status, %{status: :connected}}, socket) do
    refresh()
    {:noreply, socket}
  end

  def handle_info(_message, socket), do: {:noreply, socket}

  def terminate(_reason, _socket) do
    PhoenixClient.unsubscribe()
    :ok
  end

  defp refresh do
    PhoenixClient.request("stats", "get-all")
    PhoenixClient.request("daily-stats", "get-all", %{"slug" => "main", "days" => 30})
    PhoenixClient.request("devices", "get-all")
  end

  defp dashboard(%{stats: nil, daily: nil, devices: nil, error: nil}), do: RemoteUI.loading()

  defp dashboard(assigns) do
    error =
      if assigns.error, do: [RemoteUI.error(assigns.error), ~MOB(<Spacer size={16} />)], else: []

    ~MOB"""
    <Column fill_width={true}>
      {error}
      {stats_section(assigns.stats)}
      <Spacer size={28} />
      {daily_section(assigns.daily)}
      <Spacer size={28} />
      {devices_section(assigns.devices)}
      <Spacer size={24} />
      {blog_breakdown(assigns.stats, assigns.blogs_expanded)}
      <Spacer size={24} />
      {refresh_button()}
    </Column>
    """
  end

  defp stats_section(nil), do: RemoteUI.loading("Loading totals…")

  defp stats_section(stats) do
    main = stats["main"] || %{}
    battleship = stats["battleship"] || %{}

    ~MOB"""
    <Column fill_width={true}>
      {RemoteUI.eyebrow("Totals")}
      <Spacer size={10} />
      <Row fill_width={true}>
        {metric_card("SITE VIEWS", main["views"])}
        <Spacer size={10} />
        {metric_card("BATTLESHIP", battleship["views"])}
      </Row>
    </Column>
    """
  end

  defp blog_breakdown(nil, _expanded?), do: []

  defp blog_breakdown(stats, expanded?) do
    blogs = stats["blogs"] || []
    count = length(blogs)
    count_copy = "#{count} individual entries"
    gap = if expanded?, do: ~MOB(<Spacer size={10} />), else: []

    rows =
      if expanded? do
        blogs
        |> Enum.map(&blog_row/1)
        |> Enum.intersperse(~MOB(<Spacer size={10} />))
      else
        []
      end

    ~MOB"""
    <Column fill_width={true}>
      {RemoteUI.eyebrow("Individual blogs")}
      <Spacer size={10} />
      {RemoteUI.disclosure("Blog breakdown", count_copy, expanded?, :toggle_blog_breakdown)}
      {gap}
      {rows}
    </Column>
    """
  end

  defp metric_card(label, value) do
    display_font = @display_font
    ui_font = @ui_font

    ~MOB"""
    <Box
      background={:surface}
      border_color={:border}
      border_width={1}
      corner_radius={:radius_md}
      padding={:space_md}
      weight={1}
    >
      <Column fill_width={true}>
        <Text
          text={RemoteUI.format_number(value)}
          text_size={:"3xl"}
          font={display_font}
          font_weight="bold"
          text_color={:on_surface}
        />
        <Text
          text={label}
          text_size={:xs}
          font={ui_font}
          text_color={:muted}
          padding_top={:space_xs}
        />
      </Column>
    </Box>
    """
  end

  defp blog_row(blog) do
    title = (blog["slug"] || "blog") |> String.replace_prefix("blog:", "")

    numbers =
      "#{RemoteUI.format_number(blog["views"])} views  ·  #{RemoteUI.format_number(blog["likes"])} likes  ·  #{RemoteUI.format_number(blog["comments"])} comments"

    display_font = @display_font
    ui_font = @ui_font

    ~MOB"""
    <Box
      background={:surface}
      border_color={:border}
      border_width={1}
      corner_radius={:radius_md}
      padding={:space_md}
      fill_width={true}
    >
      <Column fill_width={true}>
        <Text
          text={title}
          text_size={:base}
          font={display_font}
          font_weight="bold"
          text_color={:on_surface}
        />
        <Text
          text={numbers}
          text_size={:xs}
          font={ui_font}
          text_color={:muted}
          padding_top={:space_xs}
        />
      </Column>
    </Box>
    """
  end

  defp daily_section(nil), do: RemoteUI.loading("Drawing thirty days…")

  defp daily_section(daily) do
    total = Enum.reduce(daily, 0, &((&1["views"] || 0) + &2))
    copy = "#{RemoteUI.format_number(total)} visits across the last 30 days"
    ui_font = @ui_font
    ops = chart_ops(daily)

    ~MOB"""
    <Column fill_width={true}>
      {RemoteUI.eyebrow("Daily movement")}
      <Spacer size={10} />
      <Box
        background={:surface}
        border_color={:border}
        border_width={1}
        corner_radius={:radius_lg}
        padding={:space_md}
        fill_width={true}
      >
        <Column fill_width={true}>
          <Text text={copy} text_size={:sm} font={ui_font} text_color={:muted} />
          <Spacer size={14} />
          <Box align="center" fill_width={true}>
            <Canvas width={288} height={176} draw={ops} />
          </Box>
        </Column>
      </Box>
    </Column>
    """
  end

  defp chart_ops([]) do
    [
      Mob.Canvas.line(32, 140, 280, 140, color: :border, width: 1),
      Mob.Canvas.text(26, 135, "0", color: :muted, size: 10, family: @ui_font, anchor: :end),
      Mob.Canvas.text(156, 72, "No visits yet",
        color: :muted,
        size: 14,
        family: @ui_font,
        anchor: :center
      )
    ]
  end

  defp chart_ops(daily) do
    values = Enum.map(daily, &(&1["views"] || 0))
    axis_max = axis_max(Enum.max(values, fn -> 0 end))
    count = max(length(values) - 1, 1)
    left = 32
    right = 280
    top = 10
    bottom = 140

    points =
      values
      |> Enum.with_index()
      |> Enum.map(fn {value, index} ->
        x = left + index / count * (right - left)
        y = bottom - value / axis_max * (bottom - top)
        {x, y}
      end)

    y_axis =
      for value <- [axis_max, div(axis_max, 2), 0] do
        y = bottom - value / axis_max * (bottom - top)

        [
          Mob.Canvas.line(left, y, right, y, color: :border, width: 1, opacity: 0.7),
          Mob.Canvas.text(left - 6, y - 5, RemoteUI.format_number(value),
            color: :muted,
            size: 10,
            family: @ui_font,
            anchor: :end
          )
        ]
      end
      |> List.flatten()

    x_axis =
      daily
      |> x_axis_entries()
      |> Enum.map(fn {entry, index, anchor} ->
        x = left + index / count * (right - left)

        Mob.Canvas.text(x, 153, chart_date(entry),
          color: :muted,
          size: 10,
          family: @ui_font,
          anchor: anchor
        )
      end)

    dots =
      Enum.map(points, fn {x, y} ->
        Mob.Canvas.circle(x, y, 2.5, color: :secondary, fill: true)
      end)

    y_axis ++
      x_axis ++
      [Mob.Canvas.path(points, color: :primary, width: 3, cap: :round, join: :round)] ++ dots
  end

  defp axis_max(value) when value <= 4, do: 4
  defp axis_max(value) when value <= 10, do: 10
  defp axis_max(value) when value <= 25, do: ceil_to(value, 5)
  defp axis_max(value) when value <= 100, do: ceil_to(value, 20)
  defp axis_max(value) when value <= 500, do: ceil_to(value, 100)
  defp axis_max(value), do: ceil_to(value, 500)

  defp ceil_to(value, step), do: div(value + step - 1, step) * step

  defp x_axis_entries(daily) do
    last = length(daily) - 1

    [
      {Enum.at(daily, 0), 0, :start},
      {Enum.at(daily, div(last, 2)), div(last, 2), :center},
      {Enum.at(daily, last), last, :end}
    ]
    |> Enum.uniq_by(fn {_entry, index, _anchor} -> index end)
  end

  defp chart_date(%{
         "date" =>
           <<_year::binary-size(4), "-", month::binary-size(2), "-", day::binary-size(2),
             _::binary>>
       }),
       do: "#{month}/#{day}"

  defp chart_date(_entry), do: ""

  defp devices_section(nil), do: RemoteUI.loading("Reading visitor devices…")

  defp devices_section(devices) do
    categories = [
      {"Browsers", aggregate(devices, "browser")},
      {"Operating systems", aggregate(devices, "os")},
      {"Devices", aggregate(devices, "device")}
    ]

    groups =
      categories
      |> Enum.map(fn {title, entries} -> device_group(title, entries) end)
      |> Enum.intersperse(~MOB(<Spacer size={20} />))

    ~MOB"""
    <Column fill_width={true}>
      {RemoteUI.eyebrow("Visitor devices")}
      <Spacer size={10} />
      {groups}
    </Column>
    """
  end

  defp aggregate(devices, key) do
    devices
    |> Enum.group_by(&(&1[key] || "Unknown"), &(&1["count"] || 0))
    |> Enum.map(fn {label, counts} -> {label, Enum.sum(counts)} end)
    |> Enum.sort_by(&elem(&1, 1), :desc)
    |> Enum.take(6)
  end

  defp device_group(title, entries) do
    total = max(Enum.reduce(entries, 0, fn {_label, count}, sum -> sum + count end), 1)
    rows = Enum.map(entries, fn {label, count} -> device_row(label, count, total) end)
    display_font = @display_font

    ~MOB"""
    <Box
      background={:surface}
      border_color={:border}
      border_width={1}
      corner_radius={:radius_md}
      padding={:space_md}
      fill_width={true}
    >
      <Column fill_width={true}>
        <Text
          text={title}
          text_size={:lg}
          font={display_font}
          font_weight="bold"
          text_color={:on_surface}
        />
        <Spacer size={10} />
        {rows}
      </Column>
    </Box>
    """
  end

  defp device_row(label, count, total) do
    ui_font = @ui_font
    fraction = count / total

    ~MOB"""
    <Column fill_width={true}>
      <Row fill_width={true}>
        <Text text={label} text_size={:sm} font={ui_font} text_color={:on_surface} />
        <Spacer />
        <Text
          text={RemoteUI.format_number(count)}
          text_size={:xs}
          font={ui_font}
          text_color={:muted}
        />
      </Row>
      <Spacer size={5} />
      <Progress value={fraction} />
      <Spacer size={10} />
    </Column>
    """
  end

  defp refresh_button do
    font = @ui_font
    tap = {self(), :refresh}
    ~MOB(<Button
  text="Refresh analytics"
  font={font}
  background={:surface_raised}
  text_color={:primary}
  on_tap={tap}
/>)
  end

  defp format_reason(reason) when is_binary(reason), do: reason
  defp format_reason(reason), do: inspect(reason)
end
