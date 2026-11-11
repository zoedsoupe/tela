defmodule Tela.Fonts.Storage do
  @moduledoc false

  @spec store(binary(), binary(), binary()) :: {:ok, binary()} | {:error, term()}
  def store(temp_path, extension, id)
      when is_binary(temp_path) and is_binary(extension) and is_binary(id) do
    path = path_for(id, extension)

    with :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- File.cp(temp_path, path) do
      {:ok, path}
    end
  end

  @spec path_for(binary(), binary()) :: binary()
  def path_for(id, extension) do
    uploads_dir = Application.get_env(:tela, :uploads_dir, "uploads") |> Path.expand()
    Path.join([uploads_dir, "fonts", id <> extension])
  end

  @spec regular_file?(binary()) :: boolean()
  def regular_file?(path) when is_binary(path) do
    uploads_dir = Application.get_env(:tela, :uploads_dir, "uploads") |> Path.expand()
    fonts_dir = Path.join(uploads_dir, "fonts")
    expanded = Path.expand(path)

    with true <- Path.dirname(expanded) == fonts_dir,
         {:ok, %{type: :regular}} <- File.lstat(expanded) do
      true
    else
      _ -> false
    end
  end

  def regular_file?(_path), do: false

  @spec remove(binary()) :: :ok
  def remove(path) do
    if regular_file?(path), do: File.rm(path), else: :ok
  end
end
