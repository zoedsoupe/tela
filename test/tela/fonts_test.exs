defmodule Tela.FontsTest do
  use Tela.DataCase, async: false

  alias Tela.Fonts
  alias Tela.Fonts.Family

  setup do
    uploads_dir = Path.join(System.tmp_dir!(), "tela-fonts-test-#{Ecto.UUID.generate()}")
    previous_uploads_dir = Application.get_env(:tela, :uploads_dir)
    Application.put_env(:tela, :uploads_dir, uploads_dir)

    on_exit(fn ->
      if previous_uploads_dir do
        Application.put_env(:tela, :uploads_dir, previous_uploads_dir)
      else
        Application.delete_env(:tela, :uploads_dir)
      end

      File.rm_rf!(uploads_dir)
    end)

    Tela.Fonts.Seed.seed!()
    {:ok, uploads_dir: uploads_dir}
  end

  test "searches family names without accents and applies category and page limits" do
    Repo.insert!(
      Family.changeset(%Family{}, %{
        family: "Café Ronde",
        normalized_name: Fonts.normalized_name("Café Ronde"),
        category: "serif",
        scripts: %{values: ["latin"]},
        is_variable: false,
        is_user_font: false,
        variants: %{items: []},
        popularity: 20
      })
    )

    assert {:ok, %{count: 1, results: [family]}} =
             Fonts.list(%{
               "q" => "cafe",
               "category" => "serif",
               "page" => "1",
               "page_size" => "1"
             })

    assert Fonts.to_api(family) == %{
             id: family.id,
             family: "Café Ronde",
             category: "serif",
             scripts: ["latin"],
             is_variable: false,
             is_user_font: false,
             variants: [],
             popularity: 20
           }
  end

  test "paginates and clamps requested page sizes" do
    assert {:ok, %{count: 12, page: 2, page_size: 100, results: results}} =
             Fonts.list(%{"page" => "2", "page_size" => "1000", "ordering" => "family"})

    assert results == []
  end

  test "uploads a signature-checked font as a workspace-shared family and removes it", %{
    uploads_dir: uploads_dir
  } do
    {upload, temp_path} = font_upload("../../Lato-Bold.woff2", "wOF2")
    on_exit(fn -> File.rm(temp_path) end)

    assert {:ok, family} = Fonts.upload(%{"files" => [upload], "category" => "sans-serif"})
    assert family.family == "Lato"
    assert family.is_user_font

    variants = Map.get(family.variants, "items", Map.get(family.variants, :items))
    assert [stored_variant] = variants
    file_id = stored_variant["file_id"]
    storage_path = stored_variant["storage_path"]
    assert stored_variant["extension"] == ".woff2"
    assert stored_variant["style"] == "normal"
    assert stored_variant["url"] == "/api/fonts/files/" <> file_id
    assert stored_variant["weight"] == 700

    assert String.starts_with?(storage_path, Path.join(uploads_dir, "fonts"))
    assert {:ok, path, "font/woff2"} = Fonts.get_file(file_id)
    assert File.read!(path) == "wOF2font bytes"
    assert {:ok, page} = Fonts.list_mine(%{"page" => "1"})
    assert page.count == 1
    assert [api_family] = Enum.map(page.results, &Fonts.to_api/1)
    assert api_family.is_user_font
    assert [variant] = api_family.variants

    assert variant == %{
             "url" => "/api/fonts/files/" <> file_id,
             "weight" => 700,
             "style" => "normal"
           }

    assert {:ok, _deleted} = Fonts.delete_mine(family.id)
    refute File.exists?(storage_path)
    assert {:error, :not_found} = Fonts.get_file(file_id)
  end

  test "rejects a font whose file signature does not match the extension" do
    {upload, temp_path} = font_upload("Invalid.woff2", "nope")
    on_exit(fn -> File.rm(temp_path) end)

    assert {:error, :invalid_font_file} = Fonts.upload(%{"files" => [upload]})
    assert {:ok, %{count: 0, results: []}} = Fonts.list_mine()
  end

  test "rejects font uploads over the per-file limit" do
    path = Path.join(System.tmp_dir!(), "oversized-font-#{Ecto.UUID.generate()}")

    {:ok, file} = File.open(path, [:write, :binary])
    :file.position(file, 10_000_001)
    IO.binwrite(file, "x")
    File.close(file)
    on_exit(fn -> File.rm(path) end)

    upload = %Plug.Upload{path: path, filename: "Large.woff2", content_type: "font/woff2"}
    assert {:error, :font_upload_too_large} = Fonts.upload(%{"files" => [upload]})
  end

  test "rejects duplicate variants before storing files" do
    {regular, regular_path} = font_upload("Inter-Regular.woff2", "wOF2")
    {numeric, numeric_path} = font_upload("Inter-400.woff2", "wOF2")
    on_exit(fn -> File.rm(regular_path) end)
    on_exit(fn -> File.rm(numeric_path) end)

    assert {:error, :font_variant_exists} =
             Fonts.upload(%{"family" => "Inter", "files" => [regular, numeric]})

    assert {:ok, %{count: 0, results: []}} = Fonts.list_mine()
  end

  defp font_upload(filename, signature) do
    path = Path.join(System.tmp_dir!(), "font-upload-#{Ecto.UUID.generate()}")
    File.write!(path, signature <> "font bytes")
    {%Plug.Upload{path: path, filename: filename, content_type: "font/woff2"}, path}
  end
end
