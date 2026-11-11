defmodule Tela.Designs.DocumentTest do
  use ExUnit.Case, async: true
  alias Tela.Designs.Document

  test "builds a versioned blank document" do
    assert {:ok, document} = Document.blank(1080, 1350, "post-instagram") |> Document.validate()
    assert document["schemaVersion"] == 1
    assert [%{"objects" => []}] = document["pages"]
    assert document["meta"] == %{"presetId" => "post-instagram"}
  end

  test "accepts bounded animations and transitions" do
    document = Document.blank(1080, 1080)
    page = hd(document["pages"])

    page =
      page
      |> Map.put("durationSec", 4)
      |> Map.put("transition", %{"preset" => "fade", "durationMs" => 300, "easing" => "ease-out"})
      |> Map.put("objects", [
        %{
          "id" => "title",
          "type" => "textbox",
          "animation" => %{
            "enter" => %{
              "preset" => "rise",
              "durationMs" => 500,
              "delayMs" => 200,
              "easing" => "spring"
            },
            "emphasis" => %{
              "preset" => "pulse",
              "durationMs" => 800,
              "delayMs" => 0,
              "loop" => true
            }
          }
        }
      ])

    assert {:ok, _} = Document.validate(%{document | "pages" => [page]})
    assert Document.page_duration_ms(page) == 4_000
  end

  test "looping emphasis does not extend the minimum page duration" do
    page = %{
      "durationSec" => 1,
      "objects" => [
        %{
          "animation" => %{
            "emphasis" => %{"durationMs" => 10_000, "delayMs" => 0, "loop" => true}
          }
        }
      ]
    }

    assert Document.page_duration_ms(page) == 1_000
  end

  test "rejects invalid envelopes and animation limits" do
    assert {:error, :invalid_document} = Document.validate(%{})
    assert {:error, :invalid_document} = Document.blank(0, 1080) |> Document.validate()

    invalid_page =
      Document.blank(1080, 1080)
      |> hd_page()
      |> Map.put("objects", [
        %{
          "id" => "bad",
          "type" => "rect",
          "animation" => %{"enter" => %{"preset" => "fade", "durationMs" => 99}}
        }
      ])

    assert {:error, :invalid_document} =
             Document.blank(1080, 1080) |> Map.put("pages", [invalid_page]) |> Document.validate()
  end

  test "rejects duplicate page ids" do
    page = Document.blank(1080, 1080) |> hd_page()

    assert {:error, :invalid_document} =
             Document.blank(1080, 1080) |> Map.put("pages", [page, page]) |> Document.validate()
  end

  defp hd_page(document), do: hd(document["pages"])
end
