defmodule Tela.DesignsTest do
  use Tela.DataCase, async: false
  import Tela.AccountsFixtures
  alias Tela.Designs

  setup do
    %{user: user_fixture(), other_user: user_fixture()}
  end

  test "creates a design from a preset", %{user: user} do
    assert {:ok, design} =
             Designs.create(%{user_id: user.id, title: "Campanha", preset_id: "post-instagram"})

    assert design.owner_id == user.id
    assert design.title == "Campanha"
    assert design.width == 1080
    assert design.height == 1350
    assert design.page_count == 1
    assert design.revision == 1
    assert design.document["schemaVersion"] == 1
    assert length(design.document["pages"]) == 1
  end

  test "rejects an unknown preset", %{user: user} do
    assert {:error, :unknown_preset} =
             Designs.create(%{user_id: user.id, title: "Inválida", preset_id: "unknown"})
  end

  test "scopes reads and lists to the owner", %{user: user, other_user: other_user} do
    {:ok, design} = Designs.create(%{user_id: user.id, title: "Privada", preset_id: "story"})
    assert {:ok, found} = Designs.get_for_user(design.id, user.id)
    assert found.id == design.id
    assert {:error, :not_found} = Designs.get_for_user(design.id, other_user.id)
    assert {:ok, listed} = Designs.list_for_user(user.id)
    assert Enum.map(listed, & &1.id) == [design.id]
    assert {:ok, []} = Designs.list_for_user(other_user.id)
  end

  test "saves a valid document with optimistic revision checks", %{user: user} do
    {:ok, design} = Designs.create(%{user_id: user.id, title: "Revisão", preset_id: "thumbnail"})

    document =
      put_in(design.document, ["pages", Access.at(0), "objects"], [
        %{"id" => "title", "type" => "textbox", "text" => "Olá"}
      ])

    assert {:ok, saved} =
             Designs.save_document(%{
               design_id: design.id,
               user_id: user.id,
               document: document,
               expected_revision: 1,
               thumbnail_base64: nil
             })

    assert saved.revision == 2
    assert saved.document == document

    assert {:error, :revision_conflict} =
             Designs.save_document(%{
               design_id: design.id,
               user_id: user.id,
               document: document,
               expected_revision: 1,
               thumbnail_base64: nil
             })

    assert {:ok, current} = Designs.get_for_user(design.id, user.id)
    assert current.revision == 2
  end

  test "does not save an invalid document or another users design", %{
    user: user,
    other_user: other_user
  } do
    {:ok, design} = Designs.create(%{user_id: user.id, title: "Protegida", preset_id: "a4"})

    input = %{
      design_id: design.id,
      user_id: other_user.id,
      document: design.document,
      expected_revision: 1,
      thumbnail_base64: nil
    }

    assert {:error, :not_found} = Designs.save_document(input)

    assert {:error, :invalid_document} =
             Designs.save_document(%{input | user_id: user.id, document: %{}})
  end

  test "renames, duplicates, and deletes a design", %{user: user} do
    {:ok, design} = Designs.create(%{user_id: user.id, title: "Original", preset_id: "story"})
    assert {:ok, renamed} = Designs.rename(design.id, user.id, "Renomeada")
    assert renamed.title == "Renomeada"
    assert renamed.revision == design.revision

    assert {:ok, copy} = Designs.duplicate(design.id, user.id)
    assert copy.id != design.id
    assert copy.title == "Cópia de Renomeada"
    assert copy.document == renamed.document
    assert copy.revision == 1

    assert {:ok, _} = Designs.delete(design.id, user.id)
    assert {:error, :not_found} = Designs.get_for_user(design.id, user.id)
  end
end
