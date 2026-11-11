defmodule Tela.DesignsTest do
  use Tela.DataCase, async: false
  import Tela.ProfilesFixtures
  alias Tela.Designs

  setup do
    %{profile: profile_fixture(), collaborator: profile_fixture()}
  end

  test "creates a design from a preset with optional authorship", %{profile: profile} do
    assert {:ok, design} =
             Designs.create(%{
               created_by_id: profile.id,
               title: "Campanha",
               preset_id: "post-instagram"
             })

    assert design.created_by_id == profile.id
    assert design.title == "Campanha"
    assert design.width == 1080
    assert design.height == 1350
    assert design.page_count == 1
    assert design.revision == 1
    assert design.document["schemaVersion"] == 1
    assert length(design.document["pages"]) == 1

    assert {:ok, anonymous} =
             Designs.create(%{created_by_id: nil, title: "Sem perfil", preset_id: "story"})

    assert is_nil(anonymous.created_by_id)
  end

  test "rejects an unknown preset" do
    assert {:error, :unknown_preset} =
             Designs.create(%{created_by_id: nil, title: "Inválida", preset_id: "unknown"})
  end

  test "shares reads and lists across the workspace", %{
    profile: profile,
    collaborator: collaborator
  } do
    {:ok, design} =
      Designs.create(%{created_by_id: profile.id, title: "Compartilhada", preset_id: "story"})

    assert {:ok, found} = Designs.get(design.id)
    assert found.id == design.id
    assert {:ok, listed} = Designs.list()
    assert Enum.map(listed, & &1.id) == [design.id]
    assert {:ok, copy} = Designs.duplicate(design.id, collaborator.id)
    assert copy.created_by_id == collaborator.id
  end

  test "saves a valid document with optimistic revision checks", %{profile: profile} do
    {:ok, design} =
      Designs.create(%{created_by_id: profile.id, title: "Revisão", preset_id: "thumbnail"})

    document =
      put_in(design.document, ["pages", Access.at(0), "objects"], [
        %{"id" => "title", "type" => "textbox", "text" => "Olá"}
      ])

    assert {:ok, saved} =
             Designs.save_document(%{
               design_id: design.id,
               document: document,
               expected_revision: 1,
               thumbnail_base64: nil
             })

    assert saved.revision == 2
    assert saved.document == document

    assert {:error, :revision_conflict} =
             Designs.save_document(%{
               design_id: design.id,
               document: document,
               expected_revision: 1,
               thumbnail_base64: nil
             })

    assert {:ok, current} = Designs.get(design.id)
    assert current.revision == 2
  end

  test "does not save an invalid document", %{profile: profile} do
    {:ok, design} =
      Designs.create(%{created_by_id: profile.id, title: "Documento", preset_id: "a4"})

    assert {:error, :invalid_document} =
             Designs.save_document(%{
               design_id: design.id,
               document: %{},
               expected_revision: 1,
               thumbnail_base64: nil
             })
  end

  test "renames, duplicates, and deletes a shared design", %{
    profile: profile,
    collaborator: collaborator
  } do
    {:ok, design} =
      Designs.create(%{created_by_id: profile.id, title: "Original", preset_id: "story"})

    assert {:ok, renamed} = Designs.rename(design.id, "Renomeada")
    assert renamed.title == "Renomeada"
    assert renamed.revision == design.revision

    assert {:ok, copy} = Designs.duplicate(design.id, collaborator.id)
    assert copy.id != design.id
    assert copy.title == "Cópia de Renomeada"
    assert copy.document == renamed.document
    assert copy.revision == 1

    assert {:ok, _} = Designs.delete(design.id)
    assert {:error, :not_found} = Designs.get(design.id)
  end
end
