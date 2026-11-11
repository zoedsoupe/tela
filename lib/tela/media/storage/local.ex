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

  @spec regular_file?(binary()) :: boolean()
  def regular_file?(path) when is_binary(path) do
    root = Application.get_env(:tela, :uploads_dir, "uploads") |> Path.expand()
    expanded = Path.expand(path)

    with true <- Path.dirname(expanded) == root,
         {:ok, %{type: :regular}} <- File.lstat(expanded) do
      true
    else
      _ -> false
    end
  end

  def regular_file?(_path), do: false

  @spec remove(binary() | nil) :: :ok
  def remove(path) do
    if regular_file?(path), do: File.rm(path), else: :ok
  end
end
