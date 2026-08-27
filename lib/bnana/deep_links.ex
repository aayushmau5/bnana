defmodule Bnana.DeepLinks do
  @moduledoc "Routes URLs captured through Bnana's iOS Shortcut into the active Mob screen."

  @pending_filename ".pending_capture_url"
  @max_url_bytes 16_384

  def consume do
    case Process.whereis(:mob_screen) do
      screen when is_pid(screen) -> consume_pending()
      nil -> :ok
    end

    :ok
  end

  def open(raw_url) do
    case {Process.whereis(:mob_screen), validate_url(raw_url)} do
      {screen, {:ok, url}} when is_pid(screen) ->
        if Mob.Screen.get_current_module(screen) != Bnana.SavedLinksScreen do
          GenServer.call(screen, {:navigate, {:push, Bnana.SavedLinksScreen, %{}}})
        end

        GenServer.call(screen, {:navigate, {:push, Bnana.LinkCaptureScreen, %{url: url}}})

      _other ->
        :ok
    end

    :ok
  end

  def validate_url(raw_url) when is_binary(raw_url) do
    url = String.trim(raw_url)
    parsed = URI.parse(url)

    if byte_size(url) <= @max_url_bytes and
         String.downcase(parsed.scheme || "") in ["http", "https"] and
         is_binary(parsed.host) and parsed.host != "" do
      {:ok, url}
    else
      :error
    end
  end

  def validate_url(_raw_url), do: :error

  defp consume_pending do
    path = Path.join(Mob.Storage.dir(:app_support), @pending_filename)

    case File.read(path) do
      {:ok, raw_url} ->
        File.rm(path)
        open(raw_url)

      {:error, _reason} ->
        :ok
    end
  end
end
