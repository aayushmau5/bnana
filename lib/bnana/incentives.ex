defmodule Bnana.Incentives do
  @moduledoc false

  # TODO: refactor to get it from env
  @default_url "http://100.92.53.98:4100"
  @token_file ".incentives_token"

  def configured?, do: is_binary(token())

  def save_token(value) when is_binary(value) do
    value = String.trim(value)

    if value == "" do
      {:error, :empty_token}
    else
      path = token_path()

      with :ok <- File.mkdir_p(Path.dirname(path)),
           :ok <- File.write(path, value, [:binary]) do
        File.chmod(path, 0o600)
      end
    end
  rescue
    error -> {:error, error}
  end

  def forget_token do
    case File.rm(token_path()) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      error -> error
    end
  rescue
    error -> {:error, error}
  end

  def fetch(url) when is_binary(url) do
    with token when is_binary(token) <- token(),
         {:ok, %Req.Response{status: 200, body: body}} when is_map(body) <-
           Req.post(endpoint(),
             json: %{url: url},
             headers: [{"authorization", "Bearer " <> token}],
             connect_options: [timeout: 10_000],
             receive_timeout: 180_000,
             request_timeout: 190_000,
             retry: false
           ) do
      {:ok, body}
    else
      nil -> {:error, :not_configured}
      {:ok, %Req.Response{status: 401}} -> {:error, :unauthorized}
      {:ok, %Req.Response{status: 503, body: %{"error" => reason}}} -> {:error, reason}
      {:ok, %Req.Response{status: status}} -> {:error, {:http, status}}
      {:error, reason} -> {:error, {:request, reason}}
      _invalid -> {:error, :invalid_response}
    end
  rescue
    error -> {:error, {:request, error}}
  catch
    :exit, reason -> {:error, {:request, reason}}
  end

  defp endpoint do
    base =
      System.get_env("BNANA_INCENTIVES_URL") ||
        Application.get_env(:bnana, :incentives_url, @default_url)

    String.trim_trailing(base, "/") <> "/v1/incentives"
  end

  defp token do
    case System.get_env("BNANA_INCENTIVES_TOKEN") ||
           Application.get_env(:bnana, :incentives_token) do
      token when is_binary(token) and token != "" -> String.trim(token)
      _unset -> stored_token()
    end
  end

  defp stored_token do
    with {:ok, token} <- File.read(token_path()),
         token <- String.trim(token),
         true <- token != "" do
      token
    else
      _ -> nil
    end
  rescue
    _ -> nil
  end

  defp token_path do
    Path.join(Mob.Storage.dir(:app_support), @token_file)
  end
end
