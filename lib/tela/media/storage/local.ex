defmodule Tela.Media.Storage.Local do
  @moduledoc false

  @spec store(binary(), binary(), binary()) :: {:ok, binary()} | {:error, term()}
  def store(temp_path, extension, uuid) do
    uploads_dir = Application.get_env(:tela, :uploads_dir, "uploads")
    destination_dir = Path.expand(uploads_dir)
    destination = Path.join(destination_dir, uuid <> extension)

    with :ok <- File.mkdir_p(destination_dir),
         :ok <- File.cp(temp_path, destination) do
      {:ok, destination}
    end
  end
end
