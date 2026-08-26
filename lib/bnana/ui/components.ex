defmodule Bnana.RemoteUI do
  @moduledoc false

  import Mob.Sigil

  @display_font "PlayfairDisplay-Regular"
  @italic_font "PlayfairDisplay-Italic"
  @ui_font "ShareTechMono-Regular"

  def header(title) do
    display_font = @display_font
    tap = {self(), :back}

    ~MOB"""
    <Box background={:background} align="center" fill_width={true}>
      <Text
        text={title}
        text_size={:xl}
        text_color={:on_surface}
        font={display_font}
        font_weight="bold"
        padding_top={:space_sm}
        padding_bottom={:space_sm}
      />
      <Row fill_width={true}>
        <Icon
          name="back"
          text="Go back"
          text_size={20.0}
          text_color={:on_surface}
          padding={:space_sm}
          padding_left={10.0}
          on_tap={tap}
        />
        <Spacer />
      </Row>
    </Box>
    """
  end

  def eyebrow(text) do
    font = @ui_font
    label = String.upcase(text)

    ~MOB(<Text text={label} text_size={:xs} font={font} text_color={:secondary} letter_spacing={1.3} />)
  end

  def intro(title, copy) do
    display_font = @display_font
    italic_font = @italic_font

    ~MOB"""
    <Column fill_width={true}>
      <Text
        text={title}
        text_size={:"3xl"}
        font={display_font}
        font_weight="bold"
        text_color={:on_surface}
      />
      <Text
        text={copy}
        text_size={:base}
        font={italic_font}
        text_color={:muted}
        line_height={1.4}
        padding_top={:space_xs}
      />
    </Column>
    """
  end

  def menu_button(title, copy, tag) do
    display_font = @display_font
    italic_font = @italic_font
    ui_font = @ui_font
    tap = {self(), tag}

    ~MOB"""
    <Box
      background={:surface}
      border_color={:border}
      border_width={1}
      corner_radius={:radius_lg}
      padding={:space_lg}
      fill_width={true}
      on_tap={tap}
    >
      <Column fill_width={true}>
        <Row fill_width={true}>
          <Text
            text={title}
            text_size={:xl}
            font={display_font}
            font_weight="bold"
            text_color={:on_surface}
          />
          <Spacer />
          <Text text="→" text_size={:lg} font={ui_font} text_color={:primary} />
        </Row>
        <Text
          text={copy}
          text_size={:sm}
          font={italic_font}
          text_color={:muted}
          line_height={1.35}
          padding_top={:space_xs}
        />
      </Column>
    </Box>
    """
  end

  def disclosure(title, copy, expanded?, tag) do
    display_font = @display_font
    ui_font = @ui_font
    tap = {self(), tag}
    marker = if expanded?, do: "−", else: "+"

    ~MOB"""
    <Box
      background={:surface_raised}
      border_color={:border}
      border_width={1}
      corner_radius={:radius_md}
      padding={:space_md}
      fill_width={true}
      on_tap={tap}
    >
      <Row fill_width={true}>
        <Column>
          <Text
            text={title}
            text_size={:base}
            font={display_font}
            font_weight="bold"
            text_color={:on_surface}
          />
          <Text
            text={copy}
            text_size={:xs}
            font={ui_font}
            text_color={:muted}
            padding_top={:space_xs}
          />
        </Column>
        <Spacer />
        <Text text={marker} text_size={:xl} font={ui_font} text_color={:primary} />
      </Row>
    </Box>
    """
  end

  def status_pill(%{status: status} = connection) do
    {label, color} = status_copy(status)
    error = Map.get(connection, :error)
    ui_font = @ui_font

    error_copy =
      if is_binary(error) and error != "" do
        [
          ~MOB(<Text text={error} text_size={:xs} font={ui_font} text_color={:error} padding_top={:space_xs} />)
        ]
      else
        []
      end

    ~MOB"""
    <Box
      background={:surface_raised}
      border_color={:border}
      border_width={1}
      corner_radius={:radius_md}
      padding={:space_sm}
      fill_width={true}
    >
      <Column fill_width={true}>
        <Row fill_width={true}>
          <Text text="●" text_size={:sm} text_color={color} />
          <Spacer size={8} />
          <Text text={label} text_size={:xs} font={ui_font} text_color={:muted} />
        </Row>
        {error_copy}
      </Column>
    </Box>
    """
  end

  def loading(label \\ "Gathering data…") do
    font = @italic_font

    ~MOB"""
    <Column fill_width={true} padding={:space_lg}>
      <Progress />
      <Spacer size={12} />
      <Text text={label} text_size={:base} font={font} text_color={:muted} text_align="center" />
    </Column>
    """
  end

  def error(message) do
    font = @ui_font

    ~MOB"""
    <Box
      background={:surface}
      border_color={:error}
      border_width={1}
      corner_radius={:radius_md}
      padding={:space_md}
      fill_width={true}
    >
      <Text text={message} text_size={:sm} font={font} text_color={:error} />
    </Box>
    """
  end

  def format_number(nil), do: "—"

  def format_number(number) when is_integer(number) do
    number
    |> Integer.to_string()
    |> String.reverse()
    |> String.replace(~r/(\d{3})(?=\d)/, "\\1,")
    |> String.reverse()
  end

  def format_number(number), do: to_string(number)

  def short_time(value, fallback \\ "")
  def short_time(nil, fallback), do: fallback

  def short_time(value, _fallback) when is_binary(value),
    do: value |> String.slice(0, 16) |> String.replace("T", " ")

  def short_time(value, _fallback), do: to_string(value)

  defp status_copy(:connected), do: {"PHOENIX CONNECTED", :primary}
  defp status_copy(:connecting), do: {"CONNECTING TO PHOENIX", :secondary}
  defp status_copy(:needs_secret), do: {"AUTHENTICATION NEEDED", :secondary}
  defp status_copy(:suspended), do: {"PAUSED IN BACKGROUND", :muted}
  defp status_copy(:offline), do: {"OFFLINE", :error}
  defp status_copy(:error), do: {"CONNECTION ERROR", :error}
  defp status_copy(_), do: {"NOT CONNECTED", :muted}
end
