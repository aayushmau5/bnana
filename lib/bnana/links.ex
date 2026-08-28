defmodule Bnana.Links do
  @moduledoc "Persistence API for links captured on this device."

  import Ecto.Query

  require Logger

  alias Bnana.{Repo, SavedLink}

  @max_html_bytes 131_072
  @dns_retry_attempts 3
  @dns_retry_backoff_ms 250
  @title_pattern ~r/<title(?:\s[^>]*)?>(.*?)<\/title\s*>/isu
  @tag_pattern ~r/<[^>]*>/u
  @decimal_entity ~r/&#(\d+);/u
  @hex_entity ~r/&#x([0-9a-f]+);/iu

  def list_links do
    Repo.all(from(link in SavedLink, order_by: [desc: link.inserted_at, desc: link.id]))
  end

  def create_link(attrs) do
    %SavedLink{}
    |> SavedLink.changeset(attrs)
    |> Repo.insert()
  end

  def get_link(id), do: Repo.get(SavedLink, id)

  def cache_incentives(%SavedLink{} = link, incentives) when is_map(incentives) do
    link
    |> Ecto.Changeset.change(
      incentives: incentives,
      incentives_fetched_at: DateTime.utc_now()
    )
    |> Repo.update()
  end

  def fetch_title(url) do
    with host when is_binary(host) <- URI.parse(url).host,
         :ok <- resolve_host(host),
         {:ok, %Req.Response{status: status, body: body}} when status in 200..299 <-
           Req.get(url,
             headers: [{"user-agent", "Bnana/1.0"}],
             connect_options: [timeout: 4_000],
             receive_timeout: 4_000,
             request_timeout: 6_000,
             max_redirects: 5,
             retry: false,
             decode_body: false,
             into: &collect_html/2
           ) do
      title_from_html(body)
    else
      _error -> :error
    end
  rescue
    _error -> :error
  catch
    :exit, _reason -> :error
  end

  def title_from_html(html) when is_binary(html) do
    case Regex.run(@title_pattern, html, capture: :all_but_first) do
      [title] ->
        title =
          title
          |> then(&Regex.replace(@tag_pattern, &1, " "))
          |> decode_entities()
          |> String.replace(~r/\s+/u, " ")
          |> String.trim()
          |> String.slice(0, 500)

        if title == "", do: :error, else: {:ok, title}

      nil ->
        :error
    end
  end

  def title_from_html(_html), do: :error

  defp resolve_host(host) do
    case resolve_with_retries(host, @dns_retry_attempts) do
      {:ok, _ip} ->
        :ok

      {:error, :nif_not_loaded} ->
        :ok

      {:error, reason} ->
        Logger.warning("Bnana.Links: DNS resolution failed for #{host}: #{inspect(reason)}")
        :error
    end
  end

  # :timeout (EAI_AGAIN) and :nxdomain are transient in practice — they fire
  # right after app cold-start / share-sheet handoff when the network stack
  # isn't ready yet. Retry a few times before giving up; everything else
  # (:badarg, :no_address, {:gai, _}) is permanent and fails fast.
  defp resolve_with_retries(host, attempts_left) do
    case Mob.DNS.resolve(host) do
      {:ok, _ip} = ok ->
        ok

      {:error, :nif_not_loaded} = err ->
        err

      {:error, reason} when reason in [:timeout, :nxdomain] and attempts_left > 1 ->
        Logger.info(
          "Bnana.Links: DNS for #{host} returned #{inspect(reason)}, retrying " <>
            "(#{@dns_retry_attempts - attempts_left + 1}/#{@dns_retry_attempts})"
        )

        Process.sleep(@dns_retry_backoff_ms)
        resolve_with_retries(host, attempts_left - 1)

      {:error, _reason} = err ->
        err
    end
  end

  defp collect_html({:data, chunk}, {request, response}) do
    previous = if is_binary(response.body), do: response.body, else: ""
    body = IO.iodata_to_binary([previous, chunk])
    complete? = Regex.match?(@title_pattern, body)
    body = binary_part(body, 0, min(byte_size(body), @max_html_bytes))
    result = {request, %{response | body: body}}

    if complete? or byte_size(body) == @max_html_bytes,
      do: {:halt, result},
      else: {:cont, result}
  end

  defp decode_entities(title) do
    title
    |> String.replace("&amp;", "&")
    |> String.replace("&quot;", "\"")
    |> String.replace("&apos;", "'")
    |> String.replace("&#39;", "'")
    |> String.replace("&lt;", "<")
    |> String.replace("&gt;", ">")
    |> then(
      &Regex.replace(@decimal_entity, &1, fn match, digits -> entity(match, digits, 10) end)
    )
    |> then(&Regex.replace(@hex_entity, &1, fn match, digits -> entity(match, digits, 16) end))
  end

  defp entity(original, digits, base) do
    case Integer.parse(digits, base) do
      {value, ""} when value <= 0x10FFFF and value not in 0xD800..0xDFFF -> <<value::utf8>>
      _invalid -> original
    end
  end
end
