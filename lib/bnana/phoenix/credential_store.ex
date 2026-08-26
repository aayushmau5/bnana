defmodule Bnana.CredentialStore do
  @moduledoc false

  @filename ".phoenix_session"

  def load do
    with {:ok, secret} <- File.read(path()),
         secret <- String.trim(secret),
         true <- secret != "" do
      {:ok, secret}
    else
      _ -> :not_found
    end
  rescue
    _ -> :not_found
  end

  def save(secret) when is_binary(secret) and byte_size(secret) > 0 do
    session_path = path()

    with :ok <- File.mkdir_p(Path.dirname(session_path)),
         :ok <- File.write(session_path, secret, [:binary]) do
      File.chmod(session_path, 0o600)
    end
  rescue
    error -> {:error, error}
  end

  def delete do
    case File.rm(path()) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      error -> error
    end
  rescue
    error -> {:error, error}
  end

  defp path do
    Path.join(Mob.Storage.dir(:app_support), @filename)
  end
end
