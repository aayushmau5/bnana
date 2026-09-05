defmodule Bnana.Photos do
  @moduledoc false

  def pick(socket) do
    :bnana_photos_nif.pick()
    socket
  end
end
