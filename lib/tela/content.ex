defmodule Tela.Content do
  @moduledoc "Template content and metadata for the shared workspace."

  import Ecto.Query

  alias Tela.Designs
  alias Tela.Designs.Design
  alias Tela.Repo

  @template_fields [
    :id,
    :title,
    :width,
    :height,
    :page_count,
    :preset_id,
    :category,
    :slug,
    :description,
    :tags,
    :use_count,
    :is_featured,
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

  @category_names %{
    "social-media" => "Redes sociais",
    "presentations" => "Apresentações",
    "posters" => "Cartazes",
    "flyers" => "Folhetos",
    "invitations" => "Convites",
    "resumes" => "Currículos",
    "youtube" => "YouTube",
    "business" => "Negócios"
  }

  @type result(value) :: {:ok, value} | {:error, term()}

  @spec list_templates(map()) :: result([Design.t()])
  def list_templates(filters \\ %{}) when is_map(filters) do
    templates =
      Design
      |> where([design], design.is_template == true)
      |> maybe_filter_category(filter_value(filters, :category))
      |> maybe_search(filter_value(filters, :search) || filter_value(filters, :q))
      |> order_by([design], asc: design.title, asc: design.id)
      |> select([design], struct(design, ^@template_fields))
      |> Repo.all()

    {:ok, templates}
  end

  @spec list_categories() :: [%{slug: String.t(), name: String.t()}]
  def list_categories do
    categories =
      Repo.all(
        from design in Design,
          where: design.is_template == true,
          select: design.category,
          distinct: true,
          order_by: design.category
      )

    Enum.map(categories, &%{slug: &1, name: Map.get(@category_names, &1, &1)})
  end

  @spec get_template(String.t()) :: result(Design.t())
  def get_template(slug) when is_binary(slug) do
    case Repo.get_by(Design, slug: slug, is_template: true) do
      %Design{} = template -> {:ok, template}
      nil -> {:error, :not_found}
    end
  end

  def get_template(_slug), do: {:error, :not_found}

  @spec use_template(String.t(), map()) :: result(Design.t())
  def use_template(slug, attrs \\ %{}) when is_map(attrs) do
    Repo.transaction(fn ->
      with {:ok, template} <- get_template(slug),
           {:ok, design} <-
             Designs.create(%{
               template_id: template.id,
               created_by_id: Map.get(attrs, :created_by_id, Map.get(attrs, "created_by_id"))
             }),
           {1, _} <- increment_use_count(template.id) do
        design
      else
        {:error, reason} -> Repo.rollback(reason)
        _ -> Repo.rollback(:not_found)
      end
    end)
    |> case do
      {:ok, design} -> {:ok, design}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec metadata(Design.t()) :: map()
  def metadata(%Design{} = template) do
    %{
      slug: template.slug,
      description: template.description,
      tags: tags(template),
      use_count: template.use_count || 0,
      is_featured: template.is_featured || false,
      category: category(template)
    }
  end

  @spec tags(Design.t()) :: [String.t()]
  def tags(%Design{tags: encoded}) when is_binary(encoded) do
    case JSON.decode(encoded) do
      {:ok, tags} when is_list(tags) -> Enum.filter(tags, &is_binary/1)
      _ -> []
    end
  end

  def tags(_template), do: []

  @spec category(Design.t()) :: %{slug: String.t(), name: String.t()}
  def category(%Design{category: slug}),
    do: %{slug: slug, name: Map.get(@category_names, slug, slug)}

  @spec thumbnail_url(Design.t()) :: String.t() | nil
  def thumbnail_url(%Design{is_template: true, thumbnail_path: path}) when is_binary(path),
    do: path

  def thumbnail_url(_template), do: nil

  defp increment_use_count(template_id) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.update_all(
      from(design in Design,
        where: design.id == ^template_id and design.is_template == true
      ),
      inc: [use_count: 1],
      set: [updated_at: now]
    )
  end

  defp maybe_filter_category(query, nil), do: query

  defp maybe_filter_category(query, category) when is_binary(category),
    do: where(query, [design], design.category == ^category)

  defp maybe_filter_category(query, _category), do: query

  defp maybe_search(query, search) when is_binary(search) and search != "" do
    pattern = "%#{String.downcase(String.trim(search))}%"

    where(
      query,
      [design],
      fragment(
        "lower(?) LIKE ? OR lower(coalesce(?, '')) LIKE ? OR lower(?) LIKE ?",
        design.title,
        ^pattern,
        design.description,
        ^pattern,
        design.tags,
        ^pattern
      )
    )
  end

  defp maybe_search(query, _search), do: query

  defp filter_value(filters, key),
    do: Map.get(filters, key, Map.get(filters, Atom.to_string(key)))
end
