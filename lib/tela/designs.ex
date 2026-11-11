defmodule Tela.Designs do
  @moduledoc "Shared workspace designs, folders, versions, and document operations."

  import Ecto.Query

  alias Tela.Designs.{Design, DesignVersion, Document, Folder, Preset}
  alias Tela.Repo

  @max_folder_depth 5
  @max_thumbnail_bytes 2 * 1_024 * 1_024
  @thumbnail_id ~r/\A[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(?:png|jpg|webp)\z/
  @design_summary_fields [
    :id,
    :title,
    :width,
    :height,
    :page_count,
    :preset_id,
    :category,
    :folder_id,
    :starred,
    :trashed_at,
    :is_template,
    :revision,
    :thumbnail_path,
    :created_by_id,
    :updated_by_id,
    :inserted_at,
    :updated_at
  ]
  @version_summary_fields [
    :id,
    :design_id,
    :label,
    :page_count,
    :thumbnail_path,
    :is_auto,
    :created_by_id,
    :inserted_at
  ]

  @type result(value) :: {:ok, value} | {:error, term()}

  @spec create(map()) :: result(Design.t())
  def create(attrs) when is_map(attrs) do
    cond do
      is_binary(attr(attrs, :template_id)) ->
        create_from_template(attrs, attr(attrs, :template_id))

      has_attr?(attrs, :document) ->
        create_from_document(attrs, attr(attrs, :document))

      is_binary(attr(attrs, :preset_id)) ->
        create_from_preset(attrs, attr(attrs, :preset_id))

      true ->
        width = attr(attrs, :width) || 1080
        height = attr(attrs, :height) || 1080
        create_blank(attrs, width, height, nil, "custom")
    end
  end

  @spec get(binary()) :: result(Design.t())
  def get(design_id) do
    case Ecto.UUID.cast(design_id) do
      {:ok, id} ->
        case Repo.get(Design, id) do
          %Design{} = design -> {:ok, design}
          nil -> {:error, :not_found}
        end

      :error ->
        {:error, :not_found}
    end
  end

  @spec get_template(binary()) :: result(Design.t())
  def get_template(template_id) do
    case Ecto.UUID.cast(template_id) do
      {:ok, id} ->
        case Repo.get_by(Design, id: id, is_template: true) do
          %Design{} = template -> {:ok, template}
          nil -> {:error, :not_found}
        end

      :error ->
        {:error, :not_found}
    end
  end

  @spec list(map()) :: result([Design.t()])
  def list(filters \\ %{}) when is_map(filters) do
    designs =
      Design
      |> where([design], design.is_template == false)
      |> apply_filters(filters)
      |> order_by([design], desc: design.updated_at, desc: design.id)
      |> select([design], struct(design, ^@design_summary_fields))
      |> Repo.all()

    {:ok, designs}
  end

  @spec list_templates(map()) :: result([Design.t()])
  def list_templates(filters \\ %{}) when is_map(filters) do
    templates =
      Design
      |> where([design], design.is_template == true)
      |> maybe_filter(:category, filter_value(filters, :category))
      |> maybe_search(filter_value(filters, :search) || filter_value(filters, :q))
      |> order_by([design], asc: design.title, asc: design.id)
      |> select([design], struct(design, ^@design_summary_fields))
      |> Repo.all()

    {:ok, templates}
  end

  @spec update(binary(), map()) :: result(Design.t())
  def update(design_id, attrs) when is_map(attrs) do
    with {:ok, design} <- get(design_id),
         :ok <- editable(design),
         {:ok, changes} <- update_changes(design, attrs) do
      changeset = Design.changeset(design, changes)

      if changeset.valid? do
        persist_update(design, changeset, attrs)
      else
        {:error, changeset}
      end
    end
  end

  @spec save_document(map()) :: result(Design.t())
  def save_document(input) when is_map(input),
    do: __MODULE__.update(attr(input, :design_id), input)

  @spec rename(binary(), String.t()) :: result(Design.t())
  def rename(design_id, title) when is_binary(title),
    do: __MODULE__.update(design_id, %{title: title})

  @spec duplicate(binary(), binary() | nil) :: result(Design.t())
  def duplicate(design_id, created_by_id \\ nil) do
    with {:ok, design} <- get(design_id),
         :ok <- editable(design) do
      attrs = %{
        created_by_id: created_by_id,
        title: "Cópia de #{design.title}",
        document: design.document,
        width: design.width,
        height: design.height,
        page_count: design.page_count,
        preset_id: design.preset_id,
        category: design.category,
        folder_id: design.folder_id,
        is_template: false,
        revision: 1,
        thumbnail_path: nil
      }

      case %Design{} |> Design.changeset(attrs) |> Repo.insert() do
        {:ok, copy} ->
          {:ok, copy_thumbnail(copy, design.thumbnail_path)}

        error ->
          error
      end
    end
  end

  @spec trash(binary()) :: result(Design.t())
  def trash(design_id) do
    with {:ok, design} <- get(design_id),
         :ok <- editable(design) do
      design
      |> Design.changeset(%{trashed_at: DateTime.utc_now() |> DateTime.truncate(:second)})
      |> Repo.update()
    end
  end

  @spec restore(binary()) :: result(Design.t())
  def restore(design_id) do
    with {:ok, design} <- get(design_id),
         :ok <- editable(%{design | trashed_at: nil}) do
      design
      |> Design.changeset(%{trashed_at: nil})
      |> Repo.update()
    end
  end

  @spec delete(binary()) :: result(Design.t())
  def delete(design_id) do
    with {:ok, design} <- get(design_id),
         {:ok, versions} <- list_versions(design_id),
         {:ok, deleted} <- Repo.delete(design) do
      Enum.each(
        [design.thumbnail_path | Enum.map(versions, & &1.thumbnail_path)],
        &remove_thumbnail/1
      )

      {:ok, deleted}
    end
  end

  @spec permanently_delete(binary()) :: result(Design.t())
  def permanently_delete(design_id) do
    with {:ok, design} <- get(design_id),
         true <- not is_nil(design.trashed_at) do
      delete(design.id)
    else
      false -> {:error, :not_trashed}
      error -> error
    end
  end

  @spec list_folders() :: result([Folder.t()])
  def list_folders do
    folders =
      Repo.all(
        from folder in Folder, order_by: [asc: fragment("lower(?)", folder.name), asc: folder.id]
      )

    counts =
      Repo.all(
        from design in Design,
          where: is_nil(design.trashed_at) and not design.is_template,
          where: not is_nil(design.folder_id),
          group_by: design.folder_id,
          select: {design.folder_id, count(design.id)}
      )
      |> Map.new()

    {:ok, Enum.map(folders, &Map.put(&1, :design_count, Map.get(counts, &1.id, 0)))}
  end

  @spec create_folder(map()) :: result(Folder.t())
  def create_folder(attrs) when is_map(attrs) do
    with {:ok, parent_id} <- resolve_parent_id(attr(attrs, :parent_id)),
         :ok <- valid_placement(nil, parent_id),
         name when is_binary(name) <- clean_name(attr(attrs, :name)),
         :ok <- unique_folder_name(parent_id, name, nil) do
      %Folder{}
      |> Folder.changeset(%{
        name: name,
        parent_id: parent_id,
        created_by_id: attr(attrs, :created_by_id)
      })
      |> Repo.insert()
    else
      nil -> {:error, :invalid_name}
      error -> error
    end
  end

  @spec update_folder(binary(), map()) :: result(Folder.t())
  def update_folder(folder_id, attrs) when is_map(attrs) do
    with {:ok, folder} <- get_folder(folder_id),
         {:ok, parent_id} <- requested_parent_id(folder, attrs),
         :ok <- valid_placement(folder, parent_id),
         name when is_binary(name) <- requested_folder_name(folder, attrs),
         :ok <- unique_folder_name(parent_id, name, folder.id) do
      folder
      |> Folder.changeset(%{name: name, parent_id: parent_id})
      |> Repo.update()
    else
      nil -> {:error, :invalid_name}
      error -> error
    end
  end

  @spec delete_folder(binary()) :: result(Folder.t())
  def delete_folder(folder_id) do
    with {:ok, folder} <- get_folder(folder_id),
         {:ok, deleted} <- delete_folder_and_reparent(folder) do
      {:ok, deleted}
    end
  end

  @spec list_versions(binary()) :: result([DesignVersion.t()])
  def list_versions(design_id) do
    with {:ok, _design} <- get(design_id) do
      versions =
        Repo.all(
          from version in DesignVersion,
            where: version.design_id == ^design_id,
            order_by: [desc: version.inserted_at, desc: version.id],
            select: struct(version, ^@version_summary_fields)
        )

      {:ok, versions}
    end
  end

  @spec create_version(binary(), String.t(), binary() | nil) :: result(DesignVersion.t())
  def create_version(design_id, label \\ "Versão salva", created_by_id \\ nil) do
    with {:ok, design} <- get(design_id),
         :ok <- editable(design),
         {:ok, version} <- insert_version(design, clean_label(label), created_by_id) do
      {:ok, copy_version_thumbnail(version, design.thumbnail_path)}
    end
  end

  @spec get_version(binary(), binary()) :: result(DesignVersion.t())
  def get_version(design_id, version_id) do
    with {:ok, _design} <- get(design_id) do
      case {Ecto.UUID.cast(design_id), Ecto.UUID.cast(version_id)} do
        {{:ok, design_uuid}, {:ok, version_uuid}} ->
          case Repo.get_by(DesignVersion, id: version_uuid, design_id: design_uuid) do
            %DesignVersion{} = version -> {:ok, version}
            nil -> {:error, :not_found}
          end

        _ ->
          {:error, :not_found}
      end
    end
  end

  @spec restore_version(binary(), binary(), binary() | nil) :: result(Design.t())
  def restore_version(design_id, version_id, updated_by_id \\ nil) do
    with {:ok, design} <- get(design_id),
         :ok <- editable(design),
         {:ok, version} <- get_version(design_id, version_id) do
      __MODULE__.update(design.id, %{
        document: version.document,
        expected_revision: design.revision,
        updated_by_id: updated_by_id
      })
    end
  end

  @spec set_thumbnail(binary(), map()) :: result(Design.t())
  def set_thumbnail(design_id, upload) when is_map(upload) do
    with {:ok, design} <- get(design_id),
         :ok <- editable(design),
         {:ok, contents} <- read_thumbnail_upload(upload),
         {:ok, token} <- store_thumbnail(contents),
         {:ok, updated} <- persist_thumbnail(design, token) do
      remove_thumbnail(design.thumbnail_path)
      {:ok, updated}
    end
  end

  @spec get_thumbnail(String.t()) :: result(%{path: String.t(), content_type: String.t()})
  def get_thumbnail(token) when is_binary(token) do
    with true <- Regex.match?(@thumbnail_id, token),
         true <- thumbnail_record_exists?(token),
         {:ok, path} <- thumbnail_path(token),
         {:ok, stat} <- File.stat(path),
         true <- stat.type == :regular do
      {:ok, %{path: path, content_type: thumbnail_content_type(token)}}
    else
      _ -> {:error, :not_found}
    end
  end

  def get_thumbnail(_), do: {:error, :not_found}

  def thumbnail_url(nil), do: nil
  def thumbnail_url(token), do: "/uploads/design-thumbnails/#{token}"

  defp create_from_preset(attrs, preset_id) do
    with {:ok, preset} <- Preset.fetch(preset_id) do
      create_blank(attrs, preset.width, preset.height, preset.id, preset.category)
    end
  end

  defp create_from_document(attrs, document) do
    with {:ok, document} <- Document.validate(document),
         {:ok, folder_id} <- resolve_parent_id(attr(attrs, :folder_id)) do
      preset_id = get_in(document, ["meta", "presetId"]) || attr(attrs, :preset_id)

      insert_design(%{
        created_by_id: attr(attrs, :created_by_id),
        title: attr(attrs, :title) || "Design sem título",
        document: document,
        width: document["width"],
        height: document["height"],
        page_count: length(document["pages"]),
        preset_id: preset_id,
        category: attr(attrs, :category) || "custom",
        folder_id: folder_id,
        is_template: false,
        revision: 1,
        thumbnail_path: nil
      })
    end
  end

  defp create_blank(attrs, width, height, preset_id, category)
       when is_integer(width) and is_integer(height) do
    with {:ok, folder_id} <- resolve_parent_id(attr(attrs, :folder_id)),
         {:ok, document} <- Document.validate(Document.blank(width, height, preset_id)) do
      insert_design(%{
        created_by_id: attr(attrs, :created_by_id),
        title: attr(attrs, :title) || "Design sem título",
        document: document,
        width: width,
        height: height,
        page_count: 1,
        preset_id: preset_id,
        category: category,
        folder_id: folder_id,
        is_template: false,
        revision: 1,
        thumbnail_path: nil
      })
    end
  end

  defp create_blank(_attrs, _width, _height, _preset_id, _category),
    do: {:error, :invalid_document}

  defp create_from_template(attrs, template_id) do
    with {:ok, template} <- get_template(template_id),
         {:ok, folder_id} <- resolve_parent_id(attr(attrs, :folder_id)),
         {:ok, document} <- Document.validate(template.document) do
      insert_design(%{
        created_by_id: attr(attrs, :created_by_id),
        title: attr(attrs, :title) || template.title,
        document: document,
        width: document["width"],
        height: document["height"],
        page_count: length(document["pages"]),
        preset_id: template.preset_id,
        category: template.category,
        folder_id: folder_id,
        is_template: false,
        revision: 1,
        thumbnail_path: nil
      })
    end
  end

  defp insert_design(attrs) do
    %Design{}
    |> Design.changeset(attrs)
    |> Repo.insert()
  end

  defp update_changes(design, attrs) do
    document = attr(attrs, :document)

    with {:ok, validated_document} <- validate_document_attribute(attrs, document),
         {:ok, folder_id} <- requested_design_folder(design, attrs) do
      changes = %{}

      changes =
        if has_attr?(attrs, :title),
          do: Map.put(changes, :title, attr(attrs, :title)),
          else: changes

      changes =
        if has_attr?(attrs, :starred),
          do: Map.put(changes, :starred, attr(attrs, :starred)),
          else: changes

      changes =
        if has_attr?(attrs, :folder_id),
          do: Map.put(changes, :folder_id, folder_id),
          else: changes

      changes =
        if has_attr?(attrs, :updated_by_id),
          do: Map.put(changes, :updated_by_id, attr(attrs, :updated_by_id)),
          else: changes

      changes =
        if validated_document do
          changes
          |> Map.put(:document, validated_document)
          |> Map.put(:width, validated_document["width"])
          |> Map.put(:height, validated_document["height"])
          |> Map.put(:page_count, length(validated_document["pages"]))
        else
          changes
        end

      {:ok, changes}
    end
  end

  defp validate_document_attribute(attrs, document) do
    if has_attr?(attrs, :document), do: Document.validate(document), else: {:ok, nil}
  end

  defp requested_design_folder(design, attrs) do
    if has_attr?(attrs, :folder_id) do
      resolve_parent_id(attr(attrs, :folder_id))
    else
      {:ok, design.folder_id}
    end
  end

  defp persist_update(design, changeset, attrs) do
    if has_attr?(attrs, :document) do
      expected_revision = attr(attrs, :expected_revision)

      if is_integer(expected_revision) and expected_revision > 0 do
        now = DateTime.utc_now() |> DateTime.truncate(:second)
        values = changeset.changes |> Map.to_list() |> Keyword.put(:updated_at, now)

        query =
          from current in Design,
            where:
              current.id == ^design.id and current.revision == ^expected_revision and
                is_nil(current.trashed_at)

        case Repo.update_all(query, set: values, inc: [revision: 1]) do
          {1, _} -> get(design.id)
          {0, _} -> revision_conflict(design.id)
        end
      else
        {:error, :invalid_revision}
      end
    else
      Repo.update(changeset)
    end
  end

  defp revision_conflict(design_id) do
    case get(design_id) do
      {:ok, %Design{trashed_at: trashed_at}} when not is_nil(trashed_at) ->
        {:error, :trashed}

      {:ok, design} ->
        {:error, {:revision_conflict, design.revision}}

      error ->
        error
    end
  end

  defp editable(%Design{is_template: true}), do: {:error, :template_read_only}
  defp editable(%Design{trashed_at: nil}), do: :ok
  defp editable(%Design{}), do: {:error, :trashed}

  defp apply_filters(query, filters) do
    trashed = filter_value(filters, :trashed) in [true, "true", "1", 1]
    live = not trashed
    query = where(query, [design], is_nil(design.trashed_at) == ^live)

    query
    |> maybe_filter(:category, filter_value(filters, :category))
    |> maybe_filter(:preset_id, filter_value(filters, :preset_id))
    |> maybe_filter(:starred, parse_boolean(filter_value(filters, :starred)))
    |> maybe_folder_filter(filter_value(filters, :folder_id) || filter_value(filters, :folder))
    |> maybe_search(filter_value(filters, :search) || filter_value(filters, :q))
  end

  defp maybe_filter(query, _field, nil), do: query

  defp maybe_filter(query, field_name, value),
    do: where(query, [design], field(design, ^field_name) == ^value)

  defp maybe_folder_filter(query, nil), do: query

  defp maybe_folder_filter(query, value) when value in ["root", "null"],
    do: where(query, [design], is_nil(design.folder_id))

  defp maybe_folder_filter(query, value) when is_binary(value) do
    case Ecto.UUID.cast(value) do
      {:ok, id} -> where(query, [design], design.folder_id == ^id)
      :error -> where(query, [design], false)
    end
  end

  defp maybe_folder_filter(query, _), do: query

  defp maybe_search(query, search) when is_binary(search) and search != "" do
    pattern = "%#{String.downcase(String.trim(search))}%"
    where(query, [design], fragment("lower(?) LIKE ?", design.title, ^pattern))
  end

  defp maybe_search(query, _search), do: query

  defp parse_boolean(value) when value in [true, "true", "1", 1], do: true
  defp parse_boolean(value) when value in [false, "false", "0", 0], do: false
  defp parse_boolean(_), do: nil

  defp resolve_parent_id(nil), do: {:ok, nil}

  defp resolve_parent_id(parent_id) when is_binary(parent_id) do
    case get_folder(parent_id) do
      {:ok, folder} -> {:ok, folder.id}
      error -> error
    end
  end

  defp resolve_parent_id(_), do: {:error, :not_found}

  defp get_folder(folder_id) do
    case Ecto.UUID.cast(folder_id) do
      {:ok, id} ->
        case Repo.get(Folder, id) do
          %Folder{} = folder -> {:ok, folder}
          nil -> {:error, :not_found}
        end

      :error ->
        {:error, :not_found}
    end
  end

  defp requested_parent_id(folder, attrs) do
    if has_attr?(attrs, :parent_id),
      do: resolve_parent_id(attr(attrs, :parent_id)),
      else: {:ok, folder.parent_id}
  end

  defp requested_folder_name(folder, attrs) do
    if has_attr?(attrs, :name), do: clean_name(attr(attrs, :name)), else: folder.name
  end

  defp clean_name(name) when is_binary(name) do
    value = String.trim(name)
    if String.length(value) in 1..120, do: value
  end

  defp clean_name(_), do: nil

  defp unique_folder_name(parent_id, name, exclude_id) do
    query =
      from folder in Folder,
        where: fragment("lower(?) = ?", folder.name, ^String.downcase(name))

    query =
      if is_nil(parent_id),
        do: where(query, [folder], is_nil(folder.parent_id)),
        else: where(query, [folder], folder.parent_id == ^parent_id)

    query = if exclude_id, do: where(query, [folder], folder.id != ^exclude_id), else: query

    if Repo.exists?(query), do: {:error, :folder_name_taken}, else: :ok
  end

  defp free_folder_name(name, taken), do: free_folder_name(name, taken, 1)

  defp free_folder_name(name, taken, counter) do
    suffix = if counter == 1, do: "", else: " (#{counter})"
    base = String.slice(name, 0, 120 - String.length(suffix))
    candidate = base <> suffix

    if MapSet.member?(taken, String.downcase(candidate)),
      do: free_folder_name(name, taken, counter + 1),
      else: candidate
  end

  defp valid_placement(folder, parent_id) do
    parents = Repo.all(from item in Folder, select: {item.id, item.parent_id}) |> Map.new()
    ancestors = ancestor_ids(parents, parent_id)
    descendant_height = if folder, do: subtree_height(parents, folder.id), else: 1

    cond do
      folder && folder.id in ancestors ->
        {:error, :folder_cycle}

      length(ancestors) + descendant_height > @max_folder_depth ->
        {:error, :folder_depth_exceeded}

      true ->
        :ok
    end
  end

  defp ancestor_ids(_parents, nil), do: []

  defp ancestor_ids(parents, id), do: ancestor_ids(parents, id, MapSet.new(), [])

  defp ancestor_ids(parents, id, seen, acc) do
    if is_nil(id) or MapSet.member?(seen, id) do
      acc
    else
      ancestor_ids(parents, Map.get(parents, id), MapSet.put(seen, id), [id | acc])
    end
  end

  defp subtree_height(parents, root) do
    children = Enum.group_by(parents, fn {_id, parent_id} -> parent_id end, fn {id, _} -> id end)
    subtree_height(children, [root], 0, MapSet.new())
  end

  defp subtree_height(_children, [], height, _seen), do: height

  defp subtree_height(children, frontier, height, seen) do
    next =
      frontier
      |> Enum.flat_map(&Map.get(children, &1, []))
      |> Enum.reject(&MapSet.member?(seen, &1))

    subtree_height(children, next, height + 1, Enum.reduce(frontier, seen, &MapSet.put(&2, &1)))
  end

  defp delete_folder_and_reparent(folder) do
    Repo.transaction(fn ->
      children =
        Repo.all(
          from child in Folder,
            where: child.parent_id == ^folder.id,
            order_by: [asc: fragment("lower(?)", child.name), asc: child.id]
        )

      taken_query =
        from sibling in Folder,
          where: sibling.id != ^folder.id,
          select: fragment("lower(?)", sibling.name)

      taken_query =
        if is_nil(folder.parent_id),
          do: where(taken_query, [sibling], is_nil(sibling.parent_id)),
          else: where(taken_query, [sibling], sibling.parent_id == ^folder.parent_id)

      taken_names = taken_query |> Repo.all() |> MapSet.new()

      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Enum.reduce(children, taken_names, fn child, names ->
        name = free_folder_name(child.name, names)

        Repo.update_all(
          from(item in Folder, where: item.id == ^child.id),
          set: [name: name, parent_id: folder.parent_id, updated_at: now]
        )

        MapSet.put(names, String.downcase(name))
      end)

      Repo.update_all(
        from(design in Design, where: design.folder_id == ^folder.id),
        set: [folder_id: folder.parent_id]
      )

      case Repo.delete(folder) do
        {:ok, deleted} -> deleted
        {:error, reason} -> Repo.rollback(reason)
      end
    end)
    |> case do
      {:ok, deleted} -> {:ok, deleted}
      {:error, reason} -> {:error, reason}
    end
  end

  defp insert_version(design, label, created_by_id) do
    %DesignVersion{}
    |> DesignVersion.changeset(%{
      design_id: design.id,
      created_by_id: created_by_id,
      label: label,
      document: design.document,
      page_count: design.page_count,
      is_auto: false
    })
    |> Repo.insert()
  end

  defp clean_label(label) when is_binary(label) do
    label = String.trim(label)
    if String.length(label) in 1..120, do: label, else: "Versão salva"
  end

  defp clean_label(_), do: "Versão salva"

  defp copy_thumbnail(%Design{} = design, nil), do: design

  defp copy_thumbnail(%Design{} = design, source_token) do
    copy_stored_thumbnail(source_token, fn token ->
      design
      |> Design.changeset(%{thumbnail_path: token})
      |> Repo.update()
    end)
    |> case do
      {:ok, updated} -> updated
      _ -> design
    end
  end

  defp copy_version_thumbnail(%DesignVersion{} = version, nil), do: version

  defp copy_version_thumbnail(%DesignVersion{} = version, source_token) do
    copy_stored_thumbnail(source_token, fn token ->
      version
      |> DesignVersion.changeset(%{thumbnail_path: token})
      |> Repo.update()
    end)
    |> case do
      {:ok, updated} -> updated
      _ -> version
    end
  end

  defp copy_stored_thumbnail(source_token, persist_fun) do
    with {:ok, source_path} <- thumbnail_path(source_token),
         {:ok, _stat} <- File.stat(source_path),
         extension when is_binary(extension) <- Path.extname(source_token),
         token = Ecto.UUID.generate() <> extension,
         {:ok, destination_path} <- thumbnail_path(token),
         :ok <- File.mkdir_p(Path.dirname(destination_path)),
         :ok <- File.cp(source_path, destination_path) do
      case persist_fun.(token) do
        {:ok, saved} ->
          {:ok, saved}

        error ->
          File.rm(destination_path)
          error
      end
    else
      _ -> {:error, :thumbnail_copy_failed}
    end
  end

  defp read_thumbnail_upload(upload) do
    path = Map.get(upload, :path) || Map.get(upload, "path")

    case path do
      path when is_binary(path) ->
        case File.stat(path) do
          {:ok, %{type: :regular, size: size}} when size > @max_thumbnail_bytes ->
            {:error, :thumbnail_too_large}

          {:ok, %{type: :regular, size: size}} when size > 0 ->
            with {:ok, data} <- File.read(path),
                 true <- byte_size(data) <= @max_thumbnail_bytes,
                 {:ok, _extension, _content_type} <- thumbnail_format(data) do
              {:ok, data}
            else
              false -> {:error, :thumbnail_too_large}
              _ -> {:error, :invalid_thumbnail}
            end

          _ ->
            {:error, :invalid_thumbnail}
        end

      _ ->
        {:error, :invalid_thumbnail}
    end
  end

  defp store_thumbnail(data) do
    with {:ok, extension, _content_type} <- thumbnail_format(data),
         token = Ecto.UUID.generate() <> extension,
         {:ok, path} <- thumbnail_path(token),
         :ok <- File.mkdir_p(Path.dirname(path)),
         :ok <- File.write(path, data, [:binary, :exclusive]) do
      {:ok, token}
    else
      _ -> {:error, :thumbnail_storage_failed}
    end
  end

  defp persist_thumbnail(design, token) do
    case design |> Design.changeset(%{thumbnail_path: token}) |> Repo.update() do
      {:ok, updated} ->
        {:ok, updated}

      error ->
        remove_thumbnail(token)
        error
    end
  end

  defp thumbnail_format(<<137, 80, 78, 71, 13, 10, 26, 10, _::binary>>),
    do: {:ok, ".png", "image/png"}

  defp thumbnail_format(<<255, 216, 255, _::binary>>), do: {:ok, ".jpg", "image/jpeg"}

  defp thumbnail_format(<<"RIFF", _size::binary-size(4), "WEBP", _::binary>>),
    do: {:ok, ".webp", "image/webp"}

  defp thumbnail_format(_), do: {:error, :invalid_thumbnail}

  defp thumbnail_content_type(token) do
    case Path.extname(token) do
      ".png" -> "image/png"
      ".jpg" -> "image/jpeg"
      ".webp" -> "image/webp"
    end
  end

  defp thumbnail_path(token) do
    if is_binary(token) and Regex.match?(@thumbnail_id, token) do
      root =
        Application.get_env(:tela, :uploads_dir, "uploads")
        |> Path.expand()
        |> Path.join("design-thumbnails")

      {:ok, Path.join(root, token)}
    else
      {:error, :invalid_thumbnail}
    end
  end

  defp thumbnail_record_exists?(token) do
    Repo.exists?(from design in Design, where: design.thumbnail_path == ^token) or
      Repo.exists?(from version in DesignVersion, where: version.thumbnail_path == ^token)
  end

  defp remove_thumbnail(nil), do: :ok

  defp remove_thumbnail(token) do
    with {:ok, path} <- thumbnail_path(token) do
      case File.rm(path) do
        :ok -> :ok
        {:error, :enoent} -> :ok
        error -> error
      end
    else
      _ -> :ok
    end
  end

  defp filter_value(filters, key),
    do: Map.get(filters, key, Map.get(filters, Atom.to_string(key)))

  defp has_attr?(attrs, key),
    do: Map.has_key?(attrs, key) or Map.has_key?(attrs, Atom.to_string(key))

  defp attr(attrs, key), do: Map.get(attrs, key, Map.get(attrs, Atom.to_string(key)))
end
