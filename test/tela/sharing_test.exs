defmodule Tela.SharingTest do
  use Tela.DataCase, async: false

  import Tela.ProfilesFixtures
  alias Tela.Designs
  alias Tela.Repo
  alias Tela.Sharing
  alias Tela.Sharing.ShareLink

  setup do
    profile = profile_fixture()

    {:ok, design} =
      Designs.create(%{created_by_id: profile.id, title: "Compartilhado", preset_id: "story"})

    %{profile: profile, design: design}
  end

  test "creates root comments and replies that inherit the thread anchor", %{
    profile: profile,
    design: design
  } do
    identity = %{profile: profile}

    assert {:ok, root} =
             Sharing.create_comment(
               design.id,
               %{body: "  Revisar título  ", page_id: "page-1", x: 10, y: 20},
               identity
             )

    assert root.body == "Revisar título"
    assert root.author_name == profile.name
    assert root.profile_id == profile.id

    assert {:ok, reply} =
             Sharing.create_comment(
               design.id,
               %{body: "Vou ajustar", parent_id: root.id, page_id: "other", x: 90, y: 80},
               identity
             )

    assert reply.parent_id == root.id
    assert {reply.page_id, reply.x, reply.y} == {root.page_id, root.x, root.y}
    assert {:ok, [^root, ^reply]} = Sharing.list_comments(design.id)
  end

  test "rejects one coordinate, nested replies, foreign parents, and long bodies", %{
    design: design
  } do
    assert {:error, :invalid_anchor} =
             Sharing.create_comment(design.id, %{body: "pin", x: 10})

    assert {:ok, root} = Sharing.create_comment(design.id, %{body: "root"})
    assert {:ok, reply} = Sharing.create_comment(design.id, %{body: "reply", parent_id: root.id})

    assert {:error, :invalid_parent} =
             Sharing.create_comment(design.id, %{body: "nested", parent_id: reply.id})

    assert {:error, :not_found} =
             Sharing.create_comment(Ecto.UUID.generate(), %{body: "foreign", parent_id: root.id})

    assert {:error, changeset} =
             Sharing.create_comment(design.id, %{body: String.duplicate("x", 2001)})

    assert %{body: [_ | _]} = errors_on(changeset)
  end

  test "workspace updates resolve and move root comments and propagates the pin to replies", %{
    design: design
  } do
    {:ok, root} = Sharing.create_comment(design.id, %{body: "root", page_id: "p1", x: 1, y: 2})
    {:ok, reply} = Sharing.create_comment(design.id, %{body: "reply", parent_id: root.id})

    assert {:ok, resolved} =
             Sharing.update_comment(root.id, %{resolved: true, page_id: "p2", x: 30, y: 40})

    assert resolved.resolved
    assert {resolved.page_id, resolved.x, resolved.y} == {"p2", 30, 40}
    assert {:ok, [updated_root, updated_reply]} = Sharing.list_comments(design.id)
    assert updated_root.id == root.id

    assert {updated_reply.parent_id, updated_reply.page_id, updated_reply.x, updated_reply.y} ==
             {root.id, "p2", 30, 40}

    assert {:error, :thread_root_only} = Sharing.update_comment(reply.id, %{resolved: true})
    assert {:error, :invalid_anchor} = Sharing.update_comment(root.id, %{x: nil, y: 9})
    assert {:ok, reopened} = Sharing.update_comment(root.id, %{resolved: false})
    refute reopened.resolved
  end

  test "share tokens are random 192-bit capabilities and revocation is immediate", %{
    design: design
  } do
    assert {:ok, %{link: link, token: token}} =
             Sharing.create_share_link(design.id, %{role: "view"})

    assert {:ok, entropy} = Base.url_decode64(token, padding: false)
    assert byte_size(entropy) == 24
    assert link.role == "view"
    assert link.token == token
    assert {:ok, %{design: shared}} = Sharing.access_link(token)
    assert shared.id == design.id
    assert {:ok, %{link: accessed}} = Sharing.access_link(token)
    assert %DateTime{} = accessed.last_accessed_at

    assert {:ok, _revoked} = Sharing.revoke_share_link(link.id)
    assert {:error, :not_found} = Sharing.access_link(token)
    assert {:error, :not_found} = Sharing.access_link("invalid-token")
  end

  test "share-link creation distinguishes an unknown design from an invalid role", %{
    design: design
  } do
    assert {:error, :not_found} =
             Sharing.create_share_link(Ecto.UUID.generate(), %{role: "view"})

    assert {:error, :invalid_role} =
             Sharing.create_share_link(design.id, %{role: "owner"})
  end

  test "share links default to seven days, support never, and reject arbitrary expirations", %{
    design: design
  } do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    assert {:ok, %{link: default_link}} =
             Sharing.create_share_link(design.id, %{role: "view"})

    assert expiration_in(default_link.expires_at) in 604_799..604_800

    assert {:ok, %{link: one_day_link}} =
             Sharing.create_share_link(design.id, %{role: "view", expires_in: "1d"})

    assert expiration_in(one_day_link.expires_at) in 86_399..86_400

    assert {:ok, %{link: seven_day_link}} =
             Sharing.create_share_link(design.id, %{role: "view", expires_in: "7d"})

    assert expiration_in(seven_day_link.expires_at) in 604_799..604_800

    assert {:ok, %{link: thirty_day_link}} =
             Sharing.create_share_link(design.id, %{role: "view", expires_in: "30d"})

    assert expiration_in(thirty_day_link.expires_at) in 2_591_999..2_592_000

    assert {:ok, %{link: never_link, token: never_token}} =
             Sharing.create_share_link(design.id, %{role: "view", expires_in: "never"})

    assert is_nil(never_link.expires_at)
    assert {:ok, _access} = Sharing.access_link(never_token)

    for expires_in <- ["2d", "Never", nil, 1] do
      assert {:error, :invalid_input} =
               Sharing.create_share_link(design.id, %{role: "view", expires_in: expires_in})
    end

    assert {:error, :invalid_input} =
             Sharing.create_share_link(design.id, %{
               role: "view",
               expires_at: DateTime.add(now, 30, :day)
             })
  end

  test "expired share links are inaccessible and inactive in their JSON", %{design: design} do
    assert {:ok, %{link: link, token: token}} =
             Sharing.create_share_link(design.id, %{role: "edit", expires_in: "1d"})

    assert {:ok, _access} = Sharing.access_link(token)

    expired_at = DateTime.add(DateTime.utc_now() |> DateTime.truncate(:second), -1, :day)

    assert {:ok, expired_link} =
             link
             |> ShareLink.changeset(%{expires_at: expired_at})
             |> Repo.update()

    assert {:error, :not_found} = Sharing.access_link(token)
    assert Sharing.share_link_json(expired_link).is_active == false
    assert Sharing.share_link_json(expired_link).expires_at == DateTime.to_iso8601(expired_at)
  end

  defp expiration_in(expires_at) do
    DateTime.diff(expires_at, DateTime.utc_now() |> DateTime.truncate(:second), :second)
  end

  test "view links expose one design and cannot read comments or edit", %{design: design} do
    {:ok, %{token: token}} = Sharing.create_share_link(design.id, %{role: "view"})
    {:ok, _comment} = Sharing.create_comment(design.id, %{body: "internal"})

    assert {:ok, payload} = Sharing.shared_document(token)
    assert payload.design_id == design.id
    assert payload.document == design.document
    refute Map.has_key?(payload, :designs)
    assert {:error, :comments_disabled} = Sharing.shared_comments(token)

    assert {:error, :read_only} =
             Sharing.save_shared_document(token, %{
               document: design.document,
               expected_revision: 1
             })
  end

  test "comment links require a name, allow comments and replies, but cannot edit", %{
    design: design
  } do
    {:ok, %{token: token}} = Sharing.create_share_link(design.id, %{role: "comment"})
    assert {:error, :author_name_required} = Sharing.create_shared_comment(token, %{body: "Hi"})

    assert {:ok, root} =
             Sharing.create_shared_comment(token, %{body: "Hi", author_name: "Visitante"})

    assert is_nil(root.profile_id)

    assert {:ok, reply} =
             Sharing.create_shared_comment(token, %{
               body: "Reply",
               author_name: "Outra",
               parent_id: root.id
             })

    assert reply.parent_id == root.id
    assert {:ok, comments} = Sharing.shared_comments(token)
    assert Enum.map(comments, & &1.id) == [root.id, reply.id]

    assert {:error, :read_only} =
             Sharing.rename_shared_design(token, %{title: "Sem permissão", expected_revision: 1})
  end

  test "edit links save, rename, and restore only the linked design with revision checks", %{
    design: design
  } do
    {:ok, %{token: token}} = Sharing.create_share_link(design.id, %{role: "edit"})
    {:ok, version} = Designs.create_version(design.id, "Base")

    next_document =
      put_in(design.document, ["pages", Access.at(0), "background", "color"], "#123456")

    assert {:ok, saved} =
             Sharing.save_shared_document(token, %{document: next_document, expected_revision: 1})

    assert saved.revision == 2

    assert {:error, {:revision_conflict, 2}} =
             Sharing.save_shared_document(token, %{
               document: design.document,
               expected_revision: 1
             })

    assert {:ok, renamed} =
             Sharing.rename_shared_design(token, %{title: "Renomeado", expected_revision: 2})

    assert renamed.title == "Renomeado"
    assert renamed.revision == 3

    assert {:ok, restored} =
             Sharing.restore_shared_version(token, version.id, %{expected_revision: 3})

    assert restored.revision == 4
    assert restored.document == design.document

    assert {:error, :not_found} =
             Sharing.restore_shared_version(token, Ecto.UUID.generate(), %{expected_revision: 4})
  end

  test "workspace can change link roles and only revoke its own known links", %{design: design} do
    {:ok, %{link: link}} = Sharing.create_share_link(design.id, %{role: "view"})
    assert {:ok, changed} = Sharing.update_share_link(link.id, %{role: "edit"})
    assert changed.role == "edit"
    assert {:error, changeset} = Sharing.update_share_link(link.id, %{role: "owner"})
    assert %{role: [_ | _]} = errors_on(changeset)
    assert {:error, :not_found} = Sharing.revoke_share_link(Ecto.UUID.generate())
  end
end
