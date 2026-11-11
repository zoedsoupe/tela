defmodule Tela.Designs.DocumentTest do
  use ExUnit.Case, async: true
  alias Tela.Designs.Document

  test "builds a versioned blank document" do
    assert {:ok, document} = Document.blank(1080, 1350, "post-instagram") |> Document.validate()
    assert document["schemaVersion"] == 1
    assert [%{"objects" => []}] = document["pages"]
    assert document["meta"] == %{"presetId" => "post-instagram"}
  end

  test "accepts the Doory envelope with page-specific dimensions and opaque editor data" do
    document = Document.blank(1080, 1080)
    page = hd(document["pages"])

    page =
      page
      |> Map.put("width", 960)
      |> Map.put("height", 540)
      |> Map.put("background", %{"type" => "gradient", "kind" => "radial", "stops" => []})
      |> Map.put("objects", [
        %{
          "id" => "title",
          "type" => "textbox",
          "fill" => %{"color" => "#123456", "unknownFabricField" => [1, 2, 3]}
        }
      ])

    assert {:ok, _} = Document.validate(%{document | "pages" => [page]})

    assert {:ok, _} =
             Document.validate(%{document | "pages" => [page |> Map.delete("height")]})
  end

  test "keeps page duration calculation tolerant of unknown editor fields" do
    assert Document.page_duration_ms(%{"durationSec" => 4, "objects" => [%{"animation" => %{}}]}) ==
             4_000
  end

  test "rejects invalid envelopes and dimensions" do
    assert {:error, :invalid_document} = Document.validate(%{})
    assert {:error, :invalid_document} = Document.blank(0, 1080) |> Document.validate()

    page =
      Document.blank(1080, 1080) |> hd_page() |> Map.put("width", 0) |> Map.put("height", 1080)

    assert {:error, :invalid_document} =
             Document.blank(1080, 1080) |> Map.put("pages", [page]) |> Document.validate()
  end

  test "accepts at most 100 pages and requires unique nonblank element ids" do
    document = Document.blank(1080, 1080)
    page = hd_page(document)
    pages = Enum.map(1..100, &Map.put(page, "id", "page-#{&1}"))

    assert {:ok, _} = Document.validate(%{document | "pages" => pages})

    assert {:error, :invalid_document} =
             Document.validate(%{
               document
               | "pages" => pages ++ [Map.put(page, "id", "page-101")]
             })

    duplicate_objects = [
      %{"id" => "same", "type" => "rect"},
      %{"id" => "same", "type" => "textbox"}
    ]

    invalid_page = Map.put(page, "objects", duplicate_objects)

    assert {:error, :invalid_document} =
             Document.validate(%{document | "pages" => [invalid_page]})
  end

  test "enforces the serialized document size limit" do
    document =
      Map.put(
        Document.blank(1080, 1080),
        "opaqueField",
        String.duplicate("x", 12 * 1_024 * 1_024)
      )

    assert {:error, :document_too_large} = Document.validate(document)
  end

  test "rejects duplicate page ids" do
    page = Document.blank(1080, 1080) |> hd_page()

    assert {:error, :invalid_document} =
             Document.blank(1080, 1080) |> Map.put("pages", [page, page]) |> Document.validate()
  end

  defp hd_page(document), do: hd(document["pages"])
end
