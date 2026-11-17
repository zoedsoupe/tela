defmodule TelaWeb.SharedControllerTest do
  use TelaWeb.ConnCase, async: false

  alias Tela.Designs
  alias Tela.Profiles
  alias Tela.Sharing
  alias TelaWeb.SharedController

  test "view token returns only its document and cannot expose comment data or save", %{
    conn: conn
  } do
    {:ok, design} = Designs.create(%{title: "Visível", preset_id: "story"})
    {:ok, %{token: token}} = Sharing.create_share_link(design.id, %{role: "view"})
    {:ok, _comment} = Sharing.create_comment(design.id, %{body: "Privado no endpoint"})

    response = SharedController.show(conn, %{"token" => token})
    body = json_response(response, 200)
    assert body["design_id"] == design.id
    assert body["document"] == design.document
    refute Map.has_key?(body, "comments")
    refute Map.has_key?(body, "designs")

    rejected =
      SharedController.update(conn, %{
        "token" => token,
        "title" => "Mutação",
        "expected_revision" => 1
      })

    assert rejected.status == 403
    assert %{"error" => %{"code" => "read_only"}} = json_response(rejected, 403)

    assert %{"error" => %{"code" => "read_only"}} =
             get(conn, "/api/shared/#{token}/versions") |> json_response(403)

    assert %{"error" => %{"code" => "read_only"}} =
             post(conn, "/api/shared/#{token}/versions", %{label: "Visitante"})
             |> json_response(403)
  end

  test "comment token reads and creates comments but is not an edit capability", %{conn: conn} do
    {:ok, design} = Designs.create(%{title: "Comentável", preset_id: "story"})
    {:ok, %{token: token}} = Sharing.create_share_link(design.id, %{role: "comment"})

    missing_name = SharedController.create_comment(conn, %{"token" => token, "body" => "Oi"})
    assert missing_name.status == 422
    assert %{"error" => %{"code" => "author_name_required"}} = json_response(missing_name, 422)
    assert is_nil(Map.get(conn.assigns, :current_profile))

    created =
      SharedController.create_comment(conn, %{
        "token" => token,
        "body" => "Oi",
        "author_name" => "Pessoa",
        "page_id" => "p1",
        "x" => 2,
        "y" => 3
      })

    assert created.status == 201
    comment = json_response(created, 201)
    assert comment["profile_id"] == nil
    assert comment["author_name"] == "Pessoa"
    assert comment["author"]["name"] == "Pessoa"

    comments = SharedController.comments(conn, %{"token" => token})
    assert [listed] = json_response(comments, 200)
    assert listed["id"] == comment["id"]

    denied =
      SharedController.update(conn, %{"token" => token, "title" => "No", "expected_revision" => 1})

    assert denied.status == 403

    assert %{"error" => %{"code" => "read_only"}} =
             get(conn, "/api/shared/#{token}/versions") |> json_response(403)

    assert %{"error" => %{"code" => "read_only"}} =
             post(conn, "/api/shared/#{token}/versions", %{label: "Comentário"})
             |> json_response(403)
  end

  test "guest attribution does not inherit a workspace profile from the session", %{conn: conn} do
    {:ok, profile} = Profiles.create_profile(%{name: "Perfil do workspace"})
    {:ok, design} = Designs.create(%{title: "Visitante", preset_id: "story"})
    {:ok, %{token: comment_token}} = Sharing.create_share_link(design.id, %{role: "comment"})
    {:ok, %{token: edit_token}} = Sharing.create_share_link(design.id, %{role: "edit"})
    conn = assign(conn, :current_profile, profile)

    created_comment =
      SharedController.create_comment(conn, %{
        "token" => comment_token,
        "body" => "Nome do link",
        "author_name" => "Pessoa visitante"
      })

    assert %{"author_name" => "Pessoa visitante", "profile_id" => nil} =
             json_response(created_comment, 201)

    created_version =
      SharedController.create_version(conn, %{"token" => edit_token, "label" => "Versão"})

    assert %{"version" => %{"created_by_id" => nil}} = json_response(created_version, 201)
  end

  test "edit token enforces expected revision for saves and restores versions on only its design",
       %{conn: conn} do
    {:ok, design} = Designs.create(%{title: "Editável", preset_id: "story"})
    {:ok, other} = Designs.create(%{title: "Outro", preset_id: "story"})
    {:ok, version} = Designs.create_version(design.id, "Versão inicial")
    {:ok, %{token: token}} = Sharing.create_share_link(design.id, %{role: "edit"})
    document = put_in(design.document, ["pages", Access.at(0), "background", "color"], "#abcdef")

    created_version =
      post(conn, "/api/shared/#{token}/versions", %{label: "Versão de visitante"})

    assert %{
             "version" =>
               %{
                 "design_id" => design_id,
                 "label" => "Versão de visitante",
                 "is_auto" => false,
                 "page_count" => page_count,
                 "thumbnail_url" => nil,
                 "created_by_id" => nil,
                 "created_at" => created_at
               } = created_version_body
           } = json_response(created_version, 201)

    assert design_id == design.id
    assert page_count == design.page_count
    assert is_binary(created_version_body["id"])
    assert is_binary(created_at)

    assert %{"versions" => listed_versions} =
             get(conn, "/api/shared/#{token}/versions") |> json_response(200)

    assert Enum.any?(listed_versions, &(&1["id"] == created_version_body["id"]))
    assert Enum.any?(listed_versions, &(&1["id"] == version.id))

    saved =
      SharedController.update(conn, %{
        "token" => token,
        "document" => document,
        "expected_revision" => 1
      })

    assert json_response(saved, 200)["revision"] == 2

    conflict =
      SharedController.update(conn, %{
        "token" => token,
        "document" => document,
        "expected_revision" => 1
      })

    assert conflict.status == 409

    assert %{
             "error" => %{"code" => "revision_conflict"},
             "current" => %{"revision" => 2}
           } = json_response(conflict, 409)

    renamed =
      SharedController.update(conn, %{
        "token" => token,
        "title" => "Trocado",
        "expected_revision" => 2
      })

    assert json_response(renamed, 200)["title"] == "Trocado"

    restored =
      SharedController.restore_version(conn, %{
        "token" => token,
        "id" => version.id,
        "expected_revision" => 3
      })

    assert json_response(restored, 200)["revision"] == 4
    assert {:ok, restored_design} = Designs.get(design.id)
    assert restored_design.document == design.document
    assert {:ok, untouched} = Designs.get(other.id)
    assert untouched.revision == 1

    {:ok, foreign_version} = Designs.create_version(other.id, "Não pertence")

    denied =
      SharedController.restore_version(conn, %{
        "token" => token,
        "id" => foreign_version.id,
        "expected_revision" => 4
      })

    assert denied.status == 404
  end
end
