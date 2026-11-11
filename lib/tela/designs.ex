defmodule Tela.Designs do
  @moduledoc "Shared workspace design persistence and document operations."

  import Ecto.Query
  alias Tela.Designs.{Design, Document, Preset}
  alias Tela.Repo

  @type result(value) :: {:ok, value} | {:error, term()}

  @spec create(map()) :: result(Design.t())
  def create(attrs) when is_map(attrs) do
    case attr(attrs, :template_id) do
      template_id when is_binary(template_id) ->
        create_from_template(attrs, template_id)

      _ ->
        case attr(attrs, :preset_id) do
          preset_id when is_binary(preset_id) -> create_from_preset(attrs, preset_id)
          _ -> {:error, :unknown_preset}
        end
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
    case Repo.get_by(Design, id: template_id, is_template: true) do
      %Design{} = template -> {:ok, template}
      nil -> {:error, :not_found}
    end
  end

  @spec list(map()) :: result([Design.t()])
  def list(filters \\ %{}) when is_map(filters) do
    designs =
      Design
      |> where([design], design.is_template == false)
      |> apply_filters(filters)
      |> order_by([design], desc: design.updated_at, desc: design.id)
      |> Repo.all()

    {:ok, designs}
  end

  @spec list_templates(map()) :: result([Design.t()])
  def list_templates(filters \\ %{}) when is_map(filters) do
    templates =
      Design
      |> where([design], design.is_template == true)
      |> apply_filters(filters)
      |> order_by([design], asc: design.title)
      |> Repo.all()

    {:ok, templates}
  end

  @spec save_document(map()) :: result(Design.t())
  def save_document(input) when is_map(input) do
    with {:ok, document} <- Document.validate(attr(input, :document)),
         {:ok, design} <- get(attr(input, :design_id)) do
      save_expected_revision(design, document, attr(input, :expected_revision))
    end
  end

  @spec rename(binary(), String.t()) :: result(Design.t())
  def rename(design_id, title) when is_binary(title) do
    with {:ok, design} <- get(design_id) do
      design
      |> Design.changeset(%{title: String.trim(title)})
      |> Repo.update()
    end
  end

  @spec duplicate(binary(), binary() | nil) :: result(Design.t())
  def duplicate(design_id, created_by_id \\ nil) do
    with {:ok, design} <- get(design_id) do
      attrs = %{
        created_by_id: created_by_id,
        title: "Cópia de #{design.title}",
        document: design.document,
        width: design.width,
        height: design.height,
        page_count: design.page_count,
        preset_id: design.preset_id,
        category: design.category,
        is_template: false,
        revision: 1,
        thumbnail_path: nil
      }

      %Design{}
      |> Design.changeset(attrs)
      |> Repo.insert()
    end
  end

  @spec delete(binary()) :: result(Design.t())
  def delete(design_id) do
    with {:ok, design} <- get(design_id) do
      Repo.delete(design)
    end
  end

  defp create_from_preset(attrs, preset_id) do
    with {:ok, preset} <- Preset.fetch(preset_id) do
      document = Document.blank(preset.width, preset.height, preset.id)

      design_attrs = %{
        created_by_id: attr(attrs, :created_by_id),
        title: attr(attrs, :title),
        document: document,
        width: preset.width,
        height: preset.height,
        page_count: 1,
        preset_id: preset.id,
        category: preset.category,
        is_template: false,
        revision: 1,
        thumbnail_path: nil
      }

      %Design{}
      |> Design.changeset(design_attrs)
      |> Repo.insert()
    end
  end

  defp create_from_template(attrs, template_id) do
    with {:ok, template} <- get_template(template_id) do
      design_attrs = %{
        created_by_id: attr(attrs, :created_by_id),
        title: attr(attrs, :title) || template.title,
        document: template.document,
        width: template.width,
        height: template.height,
        page_count: template.page_count,
        preset_id: template.preset_id,
        category: template.category,
        is_template: false,
        revision: 1,
        thumbnail_path: nil
      }

      %Design{}
      |> Design.changeset(design_attrs)
      |> Repo.insert()
    end
  end

  defp save_expected_revision(%Design{} = design, document, expected_revision)
       when is_integer(expected_revision) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    query =
      from current in Design,
        where: current.id == ^design.id and current.revision == ^expected_revision

    values = [
      document: document,
      width: document["width"],
      height: document["height"],
      page_count: length(document["pages"]),
      updated_at: now
    ]

    case Repo.update_all(query, set: values, inc: [revision: 1]) do
      {1, _} ->
        get(design.id)

      {0, _} ->
        case get(design.id) do
          {:ok, _current} -> {:error, :revision_conflict}
          {:error, :not_found} -> {:error, :not_found}
        end
    end
  end

  defp save_expected_revision(_design, _document, _expected_revision),
    do: {:error, :revision_conflict}

  defp apply_filters(query, filters) do
    query
    |> maybe_filter(:category, filter_value(filters, :category))
    |> maybe_filter(:preset_id, filter_value(filters, :preset_id))
    |> maybe_search(filter_value(filters, :search) || filter_value(filters, :q))
  end

  defp maybe_filter(query, _field, nil), do: query

  defp maybe_filter(query, field_name, value),
    do: where(query, [design], field(design, ^field_name) == ^value)

  defp maybe_search(query, search) when is_binary(search) and search != "" do
    pattern = "%#{String.downcase(String.trim(search))}%"
    where(query, [design], fragment("lower(?) LIKE ?", design.title, ^pattern))
  end

  defp maybe_search(query, _search), do: query

  defp filter_value(filters, key),
    do: Map.get(filters, key, Map.get(filters, Atom.to_string(key)))

  defp attr(attrs, key), do: Map.get(attrs, key, Map.get(attrs, Atom.to_string(key)))
end
