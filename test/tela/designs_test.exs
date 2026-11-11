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

    assert {:error, {:revision_conflict, 2}} =
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

  test "organizes folders hierarchically and reparents content when deleting a folder", %{
    profile: profile
  } do
    assert {:ok, parent} = Designs.create_folder(%{name: "Projetos", created_by_id: profile.id})

    assert {:ok, child} =
             Designs.create_folder(%{
               name: "Campanhas",
               parent_id: parent.id,
               created_by_id: profile.id
             })

    assert {:ok, design} =
             Designs.create(%{
               title: "Dentro da pasta",
               preset_id: "story",
               folder_id: child.id,
               created_by_id: profile.id
             })

    assert {:error, :folder_cycle} = Designs.update_folder(parent.id, %{parent_id: child.id})
    assert {:error, :folder_depth_exceeded} = create_folder_chain(profile.id, 6)

    assert {:ok, folders} = Designs.list_folders()
    listed_child = Enum.find(folders, &(&1.id == child.id))
    assert listed_child.design_count == 1

    assert {:ok, _} = Designs.delete_folder(child.id)
    assert {:ok, updated_design} = Designs.get(design.id)
    assert updated_design.folder_id == parent.id
  end

  test "supports trash, restore, permanent deletion, and library filters" do
    {:ok, starred} = Designs.create(%{title: "Logo favorita", preset_id: "story"})
    {:ok, other} = Designs.create(%{title: "Outra", preset_id: "a4"})
    {:ok, _} = Designs.update(starred.id, %{starred: true})

    assert {:ok, [found]} = Designs.list(%{search: "LOGO", starred: true})
    assert found.id == starred.id

    assert {:ok, _} = Designs.trash(starred.id)
    assert {:ok, [listed_other]} = Designs.list()
    assert listed_other.id == other.id
    assert {:ok, [listed_trashed]} = Designs.list(%{trashed: true})
    assert listed_trashed.id == starred.id
    assert {:error, :not_trashed} = Designs.permanently_delete(other.id)

    assert {:ok, restored} = Designs.restore(starred.id)
    assert is_nil(restored.trashed_at)

    assert {:ok, _} = Designs.trash(starred.id)
    assert {:ok, _} = Designs.permanently_delete(starred.id)
    assert {:error, :not_found} = Designs.get(starred.id)
  end

  test "snapshots a document and restores it as a new optimistic revision" do
    {:ok, design} = Designs.create(%{title: "Versões", preset_id: "story"})

    assert {:ok, version} = Designs.create_version(design.id, "Antes da edição")

    updated_document =
      put_in(design.document, ["pages", Access.at(0), "background", "color"], "#123456")

    assert {:ok, saved} =
             Designs.update(design.id, %{
               document: updated_document,
               expected_revision: design.revision
             })

    assert saved.revision == 2
    assert {:ok, restored} = Designs.restore_version(design.id, version.id)
    assert restored.revision == 3
    assert restored.document == design.document
    assert {:ok, [listed]} = Designs.list_versions(design.id)
    assert listed.id == version.id
  end

  defp create_folder_chain(_profile_id, 0), do: {:ok, :created}

  defp create_folder_chain(profile_id, depth) do
    Enum.reduce_while(1..depth, {:ok, nil}, fn _index, {:ok, parent} ->
      attrs = %{
        name: Ecto.UUID.generate(),
        parent_id: if(parent, do: parent.id),
        created_by_id: profile_id
      }

      case Designs.create_folder(attrs) do
        {:ok, folder} -> {:cont, {:ok, folder}}
        error -> {:halt, error}
      end
    end)
  end
end
