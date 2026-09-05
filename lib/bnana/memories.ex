defmodule Bnana.Memories do
  @moduledoc "Local persistence for Memory Book entries and their photos."

  import Ecto.Query

  alias Bnana.{Memory, Repo}

  @photo_extensions ~w(.heic .heif .jpeg .jpg .png .webp)
  @max_photo_bytes 50_000_000

  def list_memories do
    Repo.all(from(memory in Memory, order_by: [desc: memory.memory_date, desc: memory.id]))
  end

  def get_memory(id), do: Repo.get(Memory, id)

  def create_memory(attrs) do
    photo_source = Map.get(attrs, :photo_source)

    with {:ok, photo_path} <- store_photo(photo_source) do
      attrs =
        attrs
        |> Map.delete(:photo_source)
        |> Map.put_new(:memory_date, local_today())
        |> Map.put(:photo_path, photo_path)

      case %Memory{} |> Memory.changeset(attrs) |> Repo.insert() do
        {:ok, memory} ->
          {:ok, memory}

        {:error, changeset} ->
          remove_photo(photo_path)
          {:error, changeset}
      end
    end
  end

  def delete_memory(%Memory{} = memory) do
    case Repo.delete(memory) do
      {:ok, deleted} ->
        remove_photo(deleted.photo_path)
        {:ok, deleted}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def local_today do
    {date, _time} = :calendar.local_time()
    Date.from_erl!(date)
  end

  @doc "Checks that a camera or picker result is a usable local image file."
  def validate_photo_source(source) when is_binary(source) do
    extension = source |> Path.extname() |> String.downcase()

    with true <- extension in @photo_extensions,
         {:ok, %{type: :regular, size: size}} when size > 0 and size <= @max_photo_bytes <-
           File.stat(source) do
      :ok
    else
      _invalid -> {:error, :invalid_photo}
    end
  end

  def validate_photo_source(_source), do: {:error, :invalid_photo}

  defp store_photo(nil), do: {:ok, nil}
  defp store_photo(""), do: {:ok, nil}

  defp store_photo(source) when is_binary(source) do
    with :ok <- validate_photo_source(source),
         :ok <- File.mkdir_p(photo_dir()) do
      extension = source |> Path.extname() |> String.downcase()

      destination =
        Path.join(
          photo_dir(),
          "#{System.system_time(:microsecond)}-#{System.unique_integer([:positive])}#{extension}"
        )

      case File.cp(source, destination) do
        :ok -> {:ok, destination}
        {:error, reason} -> {:error, reason}
      end
    else
      _invalid -> {:error, :invalid_photo}
    end
  end

  defp store_photo(_source), do: {:error, :invalid_photo}

  defp photo_dir, do: Path.join(Repo.data_dir(), "memory_photos")
  defp remove_photo(nil), do: :ok
  defp remove_photo(path), do: File.rm(path)
end
