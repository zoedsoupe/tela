defmodule Tela.Sharing do
  @moduledoc "Workspace comments and per-design share-link capabilities."

  import Ecto.Query
  alias Tela.Designs
  alias Tela.Designs.Design
  alias Tela.Repo
  alias Tela.Sharing.{Comment, ShareLink}

  @coordinate_limit 1_000_000

  @type result(value) :: {:ok, value} | {:error, term()}

  @spec list_comments(binary()) :: result([Comment.t()])
  def list_comments(design_id) do
    with {:ok, design} <- workspace_design(design_id) do
      comments =
        from(comment in Comment,
          where: comment.design_id == ^design.id,
          order_by: [asc: comment.inserted_at, asc: comment.id]
        )
        |> Repo.all()

      {:ok, comments}
    end
  end

  @spec create_comment(binary(), map(), map()) :: result(Comment.t())
  def create_comment(design_id, attrs, identity \\ %{})

  def create_comment(design_id, attrs, identity) when is_map(attrs) and is_map(identity) do
    with {:ok, design} <- workspace_design(design_id),
         {:ok, author} <- author(identity, attrs),
         {:ok, parent} <-
           comment_parent(design.id, value(attrs, :parent_id) || value(attrs, :parent)),
         {:ok, anchor} <- comment_anchor(attrs, parent),
         changeset <-
           %Comment{
             design_id: design.id,
             profile_id: author.profile_id,
             parent_id: parent && parent.id
           }
           |> Comment.changeset(
             Map.merge(anchor, %{author_name: author.name, body: value(attrs, :body)})
           ),
         {:ok, comment} <- Repo.insert(changeset) do
      {:ok, comment}
    end
  end

  def create_comment(_design_id, _attrs, _identity), do: {:error, :invalid_input}

  @spec update_comment(binary(), map()) :: result(Comment.t())
  def update_comment(id, attrs) when is_map(attrs) do
    with {:ok, comment} <- get_comment(id),
         :ok <- validate_comment_update(comment, attrs),
         changeset <-
           Comment.changeset(
             comment,
             Map.take(attrs, [
               :body,
               "body",
               :page_id,
               "page_id",
               :x,
               "x",
               :y,
               "y",
               :resolved,
               "resolved"
             ])
           ),
         {:ok, updated} <- update_comment_and_replies(changeset, attrs) do
      {:ok, updated}
    end
  end

  def update_comment(_id, _attrs), do: {:error, :invalid_input}

  @spec delete_comment(binary()) :: result(Comment.t())
  def delete_comment(id) do
    with {:ok, comment} <- get_comment(id),
         {:ok, deleted} <- Repo.delete(comment) do
      {:ok, deleted}
    end
  end

  @spec list_share_links(binary()) :: result([ShareLink.t()])
  def list_share_links(design_id) do
    with {:ok, design} <- workspace_design(design_id) do
      links =
        from(link in ShareLink,
          where: link.design_id == ^design.id,
          order_by: [desc: link.inserted_at, desc: link.id]
        )
        |> Repo.all()

      {:ok, links}
    end
  end

  @spec create_share_link(binary(), map()) :: result(%{link: ShareLink.t(), token: String.t()})
  def create_share_link(design_id, attrs) when is_map(attrs) do
    with {:ok, design} <- workspace_design(design_id),
         {:ok, role} <- valid_role(value(attrs, :role)),
         {:ok, expires_at} <- share_link_expiration(attrs),
         token <- generate_token(),
         changeset <-
           %ShareLink{design_id: design.id, token: token, token_digest: token_digest(token)}
           |> ShareLink.changeset(%{role: role, expires_at: expires_at}),
         {:ok, link} <- Repo.insert(changeset) do
      {:ok, %{link: link, token: token}}
    end
  end

  def create_share_link(_design_id, _attrs), do: {:error, :invalid_input}

  @spec update_share_link(binary(), map()) :: result(ShareLink.t())
  def update_share_link(id, attrs) when is_map(attrs) do
    with {:ok, uuid} <- Ecto.UUID.cast(id),
         %ShareLink{revoked_at: nil} = link <- Repo.get(ShareLink, uuid),
         changeset <- ShareLink.changeset(link, Map.take(attrs, [:role, "role"])),
         {:ok, updated} <- Repo.update(changeset) do
      {:ok, updated}
    else
      nil -> {:error, :not_found}
      :error -> {:error, :not_found}
      {:error, changeset} -> {:error, changeset}
    end
  end

  def update_share_link(_id, _attrs), do: {:error, :invalid_input}

  @spec revoke_share_link(binary()) :: result(ShareLink.t())
  def revoke_share_link(id) do
    with {:ok, uuid} <- Ecto.UUID.cast(id),
         %ShareLink{} = link <- Repo.get(ShareLink, uuid) do
      now = now()

      if is_nil(link.revoked_at) do
        from(current in ShareLink, where: current.id == ^uuid and is_nil(current.revoked_at))
        |> Repo.update_all(set: [revoked_at: now, updated_at: now])
      end

      {:ok, %{link | revoked_at: link.revoked_at || now, updated_at: now}}
    else
      _ -> {:error, :not_found}
    end
  end

  @spec access_link(binary()) :: result(%{link: ShareLink.t(), design: Design.t()})
  def access_link(token) do
    now = now()

    with {:ok, digest} <- digest_token(token),
         %ShareLink{} = link <- Repo.get_by(ShareLink, token_digest: digest),
         true <- active_link?(link, now),
         {:ok, design} <- workspace_design(link.design_id),
         true <- touch_link(link.id, now) do
      {:ok, %{link: %{link | last_accessed_at: now}, design: design}}
    else
      _ -> {:error, :not_found}
    end
  end

  @spec shared_document(binary()) :: result(map())
  def shared_document(token) do
    with {:ok, %{link: link, design: design}} <- access_link(token) do
      {:ok,
       %{
         design_id: design.id,
         role: link.role,
         title: design.title,
         width: design.width,
         height: design.height,
         page_count: design.page_count,
         revision: design.revision,
         document: design.document,
         owner: %{name: "", avatar_url: nil},
         fonts: []
       }}
    end
  end

  @spec shared_comments(binary()) :: result([Comment.t()])
  def shared_comments(token) do
    with {:ok, %{link: link}} <- access_link(token),
         :ok <- require_comment_role(link),
         {:ok, comments} <- list_comments(link.design_id) do
      {:ok, comments}
    end
  end

  @spec create_shared_comment(binary(), map(), map()) :: result(Comment.t())
  def create_shared_comment(token, attrs, identity \\ %{})

  def create_shared_comment(token, attrs, identity) when is_map(attrs) and is_map(identity) do
    with {:ok, %{link: link}} <- access_link(token),
         :ok <- require_comment_role(link),
         {:ok, comment} <-
           create_comment(link.design_id, attrs, Map.put(identity, :require_name, true)) do
      {:ok, comment}
    end
  end

  def create_shared_comment(_token, _attrs, _identity), do: {:error, :invalid_input}

  @spec save_shared_document(binary(), map()) :: result(Design.t())
  def save_shared_document(token, attrs) when is_map(attrs) do
    with {:ok, %{link: link}} <- access_link(token),
         :ok <- require_edit_role(link),
         {:ok, document} <- required_value(attrs, :document),
         {:ok, expected_revision} <- positive_integer(value(attrs, :expected_revision)),
         result <-
           Designs.save_document(%{
             design_id: link.design_id,
             document: document,
             expected_revision: expected_revision
           }) do
      preserve_revision_conflict(result, link.design_id)
    end
  end

  def save_shared_document(_token, _attrs), do: {:error, :invalid_input}

  @spec rename_shared_design(binary(), map()) :: result(Design.t())
  def rename_shared_design(token, attrs) when is_map(attrs) do
    with {:ok, %{link: link, design: design}} <- access_link(token),
         :ok <- require_edit_role(link),
         {:ok, title} <- required_value(attrs, :title),
         {:ok, expected_revision} <- positive_integer(value(attrs, :expected_revision)),
         {:ok, title} <- valid_title(title),
         {:ok, updated} <- update_shared_title(design, title, expected_revision) do
      {:ok, updated}
    else
      {:error, _reason} = error -> error
    end
  end

  def rename_shared_design(_token, _attrs), do: {:error, :invalid_input}

  @spec restore_shared_version(binary(), binary(), map()) :: result(Design.t())
  def restore_shared_version(token, version_id, attrs) when is_map(attrs) do
    with {:ok, %{link: link, design: design}} <- access_link(token),
         :ok <- require_edit_role(link),
         {:ok, expected_revision} <- positive_integer(value(attrs, :expected_revision)),
         {:ok, version} <- version_for_design(design.id, version_id),
         {:ok, updated} <- restore_document(design, version, expected_revision) do
      {:ok, updated}
    end
  end

  def restore_shared_version(_token, _version_id, _attrs), do: {:error, :invalid_input}

  @spec shared_versions(binary()) :: result([Tela.Designs.DesignVersion.t()])
  def shared_versions(token) do
    with {:ok, %{link: link}} <- access_link(token),
         :ok <- require_edit_role(link),
         {:ok, versions} <- Designs.list_versions(link.design_id) do
      {:ok, versions}
    end
  end

  @spec create_shared_version(binary(), term(), binary() | nil) ::
          result(Tela.Designs.DesignVersion.t())
  def create_shared_version(token, label, created_by_id \\ nil) do
    with {:ok, %{link: link}} <- access_link(token),
         :ok <- require_edit_role(link) do
      Designs.create_version(link.design_id, label, created_by_id)
    end
  end

  @spec comment_json(Comment.t()) :: map()
  def comment_json(%Comment{} = comment) do
    %{
      id: comment.id,
      profile_id: comment.profile_id,
      author_name: comment.author_name,
      author: %{id: comment.profile_id, name: comment.author_name, avatar_url: nil},
      body: comment.body,
      page_id: comment.page_id,
      x: comment.x,
      y: comment.y,
      parent: comment.parent_id,
      parent_id: comment.parent_id,
      resolved: comment.resolved,
      created_at: iso8601(comment.inserted_at),
      updated_at: iso8601(comment.updated_at)
    }
  end

  @spec share_link_json(ShareLink.t(), String.t() | nil) :: map()
  def share_link_json(%ShareLink{} = link, token \\ nil) do
    payload = %{
      id: link.id,
      role: link.role,
      url: if(token, do: "/s/#{token}", else: nil),
      is_active: active_link?(link, now()),
      revoked_at: iso8601(link.revoked_at),
      last_accessed_at: iso8601(link.last_accessed_at),
      expires_at: iso8601(link.expires_at),
      has_password: false,
      created_at: iso8601(link.inserted_at),
      updated_at: iso8601(link.updated_at)
    }

    if is_binary(token), do: Map.put(payload, :token, token), else: payload
  end

  defp workspace_design(design_id) do
    case Designs.get(design_id) do
      {:ok, %Design{is_template: false} = design} -> {:ok, design}
      _ -> {:error, :not_found}
    end
  end

  defp comment_parent(_design_id, nil), do: {:ok, nil}

  defp comment_parent(design_id, id) do
    with {:ok, uuid} <- Ecto.UUID.cast(id),
         %Comment{parent_id: nil} = parent <- Repo.get_by(Comment, id: uuid, design_id: design_id) do
      {:ok, parent}
    else
      _ -> {:error, :invalid_parent}
    end
  end

  defp comment_anchor(_attrs, %Comment{} = parent) do
    {:ok, %{page_id: parent.page_id, x: parent.x, y: parent.y}}
  end

  defp comment_anchor(attrs, nil) do
    x = value(attrs, :x)
    y = value(attrs, :y)
    page_id = value(attrs, :page_id)

    cond do
      is_nil(x) != is_nil(y) -> {:error, :invalid_anchor}
      not valid_coordinate?(x) or not valid_coordinate?(y) -> {:error, :invalid_anchor}
      not valid_page_id?(page_id) -> {:error, :invalid_anchor}
      true -> {:ok, %{page_id: blank_to_nil(page_id), x: x, y: y}}
    end
  end

  defp author(identity, attrs) do
    profile = value(identity, :profile)
    profile_name = if profile, do: Map.get(profile, :name)
    supplied_name = value(attrs, :author_name)
    require_name = value(identity, :require_name) == true
    name = if is_binary(profile_name), do: profile_name, else: supplied_name

    cond do
      is_binary(name) and String.trim(name) != "" ->
        profile_id = if profile, do: Map.get(profile, :id)
        {:ok, %{name: String.trim(name), profile_id: profile_id}}

      require_name ->
        {:error, :author_name_required}

      true ->
        {:ok, %{name: "Anônimo", profile_id: nil}}
    end
  end

  defp validate_comment_update(comment, attrs) do
    allowed = [
      :id,
      "id",
      :body,
      "body",
      :page_id,
      "page_id",
      :x,
      "x",
      :y,
      "y",
      :resolved,
      "resolved"
    ]

    has_anchor? = Enum.any?([:page_id, "page_id", :x, "x", :y, "y"], &has_key?(attrs, &1))
    x_or_y? = has_key?(attrs, :x) or has_key?(attrs, :y)

    cond do
      Enum.any?(Map.keys(attrs), &(&1 not in allowed)) ->
        {:error, :invalid_input}

      comment.parent_id && (has_anchor? or has_key?(attrs, :resolved)) ->
        {:error, :thread_root_only}

      x_or_y? && has_key?(attrs, :x) != has_key?(attrs, :y) ->
        {:error, :invalid_anchor}

      not valid_update_anchor?(attrs) ->
        {:error, :invalid_anchor}

      true ->
        :ok
    end
  end

  defp valid_update_anchor?(attrs) do
    x = value(attrs, :x)
    y = value(attrs, :y)
    page_id = value(attrs, :page_id)

    (not has_key?(attrs, :x) or valid_coordinate?(x)) and
      (not has_key?(attrs, :y) or valid_coordinate?(y)) and
      (not has_key?(attrs, :page_id) or valid_page_id?(page_id)) and
      (not has_key?(attrs, :x) or not has_key?(attrs, :y) or is_nil(x) == is_nil(y))
  end

  defp update_comment_and_replies(changeset, attrs) do
    Repo.transaction(fn ->
      case Repo.update(changeset) do
        {:ok, updated} ->
          move_replies(updated, attrs)
          updated

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
    |> case do
      {:ok, updated} -> {:ok, updated}
      {:error, reason} -> {:error, reason}
    end
  end

  defp move_replies(comment, attrs) do
    fields =
      [:page_id, :x, :y]
      |> Enum.filter(&has_key?(attrs, &1))
      |> Map.new(fn field ->
        value = value(attrs, field)
        {field, if(field == :page_id, do: blank_to_nil(value), else: value)}
      end)

    if map_size(fields) > 0 do
      from(reply in Comment, where: reply.parent_id == ^comment.id)
      |> Repo.update_all(set: Keyword.new(fields) ++ [updated_at: now()])
    end
  end

  defp get_comment(id) do
    with {:ok, uuid} <- Ecto.UUID.cast(id),
         %Comment{} = comment <- Repo.get(Comment, uuid) do
      {:ok, comment}
    else
      _ -> {:error, :not_found}
    end
  end

  defp require_comment_role(%ShareLink{role: role}) when role in ["comment", "edit"], do: :ok
  defp require_comment_role(_link), do: {:error, :comments_disabled}
  defp require_edit_role(%ShareLink{role: "edit"}), do: :ok
  defp require_edit_role(_link), do: {:error, :read_only}

  defp valid_role(role) when role in ["view", "comment", "edit"], do: {:ok, role}
  defp valid_role(_role), do: {:error, :invalid_role}

  defp share_link_expiration(attrs) do
    cond do
      has_key?(attrs, :expires_at) ->
        {:error, :invalid_input}

      not has_key?(attrs, :expires_in) ->
        {:ok, DateTime.add(now(), 7, :day)}

      value(attrs, :expires_in) == "never" ->
        {:ok, nil}

      value(attrs, :expires_in) == "1d" ->
        {:ok, DateTime.add(now(), 1, :day)}

      value(attrs, :expires_in) == "7d" ->
        {:ok, DateTime.add(now(), 7, :day)}

      value(attrs, :expires_in) == "30d" ->
        {:ok, DateTime.add(now(), 30, :day)}

      true ->
        {:error, :invalid_input}
    end
  end

  defp generate_token, do: :crypto.strong_rand_bytes(24) |> Base.url_encode64(padding: false)

  defp digest_token(token) when is_binary(token) do
    case Base.url_decode64(token, padding: false) do
      {:ok, <<_entropy::binary-size(24)>>} -> {:ok, token_digest(token)}
      _ -> {:error, :not_found}
    end
  end

  defp digest_token(_token), do: {:error, :not_found}

  defp token_digest(token), do: :crypto.hash(:sha256, token) |> Base.encode16(case: :lower)

  defp touch_link(id, now) do
    case from(link in ShareLink,
           where:
             link.id == ^id and is_nil(link.revoked_at) and
               (is_nil(link.expires_at) or link.expires_at > ^now)
         )
         |> Repo.update_all(set: [last_accessed_at: now]) do
      {1, _} -> true
      _ -> false
    end
  end

  defp active_link?(%ShareLink{revoked_at: nil, expires_at: nil}, _now), do: true

  defp active_link?(%ShareLink{revoked_at: nil, expires_at: expires_at}, now)
       when not is_nil(expires_at),
       do: DateTime.compare(expires_at, now) == :gt

  defp active_link?(_link, _now), do: false

  defp valid_title(title) when is_binary(title) do
    title = String.trim(title)
    if String.length(title) in 1..160, do: {:ok, title}, else: {:error, :invalid_input}
  end

  defp valid_title(_title), do: {:error, :invalid_input}

  defp update_shared_title(design, title, expected_revision) do
    now = now()

    query =
      from(current in Design,
        where: current.id == ^design.id and current.revision == ^expected_revision
      )

    case Repo.update_all(query, set: [title: title, updated_at: now], inc: [revision: 1]) do
      {1, _} -> Designs.get(design.id)
      {0, _} -> current_revision_conflict(design.id)
    end
  end

  defp preserve_revision_conflict({:error, {:revision_conflict, _revision}} = error, _design_id),
    do: error

  defp preserve_revision_conflict({:error, :revision_conflict}, design_id),
    do: current_revision_conflict(design_id)

  defp preserve_revision_conflict(result, _design_id), do: result

  defp current_revision_conflict(design_id) do
    case Designs.get(design_id) do
      {:ok, design} -> {:error, {:revision_conflict, design.revision}}
      {:error, _reason} = error -> error
    end
  end

  defp version_for_design(design_id, version_id) do
    version_module = Module.concat(Tela.Designs, DesignVersion)

    with true <- Code.ensure_loaded?(version_module),
         {:ok, uuid} <- Ecto.UUID.cast(version_id),
         %{} = version <- Repo.get_by(version_module, id: uuid, design_id: design_id),
         document when is_map(document) <- Map.get(version, :document) do
      {:ok, version}
    else
      _ -> {:error, :not_found}
    end
  end

  defp restore_document(design, version, expected_revision) do
    case Tela.Designs.Document.validate(Map.get(version, :document)) do
      {:ok, document} ->
        now = now()

        values = [
          document: document,
          width: Map.get(document, "width"),
          height: Map.get(document, "height"),
          page_count: length(Map.get(document, "pages")),
          thumbnail_path: Map.get(version, :thumbnail_path),
          updated_at: now
        ]

        case from(current in Design,
               where: current.id == ^design.id and current.revision == ^expected_revision
             )
             |> Repo.update_all(set: values, inc: [revision: 1]) do
          {1, _} -> Designs.get(design.id)
          {0, _} -> current_revision_conflict(design.id)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp required_value(map, key) do
    case value(map, key) do
      nil -> {:error, :invalid_input}
      value -> {:ok, value}
    end
  end

  defp positive_integer(value) when is_integer(value) and value > 0, do: {:ok, value}

  defp positive_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} when integer > 0 -> {:ok, integer}
      _ -> {:error, :invalid_input}
    end
  end

  defp positive_integer(_value), do: {:error, :invalid_input}

  defp valid_coordinate?(nil), do: true
  defp valid_coordinate?(value) when is_integer(value), do: abs(value) <= @coordinate_limit

  defp valid_coordinate?(value) when is_float(value),
    do: value == value and abs(value) <= @coordinate_limit

  defp valid_coordinate?(_value), do: false

  defp valid_page_id?(nil), do: true
  defp valid_page_id?(""), do: true

  defp valid_page_id?(page_id) when is_binary(page_id),
    do: Regex.match?(~r/\A[A-Za-z0-9_.:-]{1,64}\z/, page_id)

  defp valid_page_id?(_page_id), do: false

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value

  defp value(map, key) when is_map(map), do: Map.get(map, key, Map.get(map, Atom.to_string(key)))
  defp value(_map, _key), do: nil

  defp has_key?(map, key), do: Map.has_key?(map, key) or Map.has_key?(map, to_string(key))

  defp now, do: DateTime.utc_now() |> DateTime.truncate(:second)
  defp iso8601(%DateTime{} = datetime), do: DateTime.to_iso8601(datetime)
  defp iso8601(_datetime), do: nil
end
