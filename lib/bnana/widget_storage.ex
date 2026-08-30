defmodule Bnana.WidgetStorage do
  @moduledoc false

  @directory_env "BNANA_WIDGET_DIR"
  @filename "analytics.json"

  def write(snapshot) when is_map(snapshot) do
    case System.get_env(@directory_env) do
      directory when is_binary(directory) and directory != "" -> write(directory, snapshot)
      _unavailable -> :unavailable
    end
  end

  def cleanup do
    case System.get_env(@directory_env) do
      directory when is_binary(directory) and directory != "" ->
        directory |> Path.join(@filename <> ".tmp") |> remove_temporary_file()

      _unavailable ->
        :unavailable
    end
  end

  defp write(directory, snapshot) do
    path = Path.join(directory, @filename)
    temporary_path = path <> ".tmp"

    with :ok <- File.mkdir_p(directory),
         :ok <- remove_temporary_file(temporary_path) do
      try do
        case File.write(temporary_path, JSON.encode!(snapshot)) do
          :ok -> File.rename(temporary_path, path)
          error -> error
        end
      after
        remove_temporary_file(temporary_path)
      end
    end
  end

  defp remove_temporary_file(path) do
    case File.rm(path) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      error -> error
    end
  end
end
