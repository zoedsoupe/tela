defmodule Tela.Content.Seed do
  @moduledoc "Seeds the bundled Doory templates into the shared designs table."

  alias Tela.Designs.{Design, Document}
  alias Tela.Repo

  @managed_fields [
    :title,
    :document,
    :width,
    :height,
    :page_count,
    :preset_id,
    :category,
    :slug,
    :description,
    :tags,
    :is_featured,
    :is_template,
    :revision,
    :thumbnail_path,
    :updated_at
  ]

  @doc "Upserts the ten bundled templates by their stable slug, preserving usage counts."
  @spec seed!() :: non_neg_integer()
  def seed! do
    root = content_root()
    manifest = root |> Path.join("manifest.json") |> read_json!()

    Enum.each(manifest["templates"], fn metadata ->
      seed_template!(root, metadata)
    end)

    length(manifest["templates"])
  end

  defp seed_template!(root, metadata) do
    slug = metadata["slug"]
    document = root |> Path.join("#{slug}.json") |> read_json!()

    case Document.validate(document) do
      {:ok, document} ->
        attrs = %{
          title: metadata["title"],
          document: document,
          width: document["width"],
          height: document["height"],
          page_count: length(document["pages"]),
          preset_id: blank_to_nil(metadata["preset"]),
          category: metadata["category"],
          slug: slug,
          description: metadata["description"],
          tags: JSON.encode!(metadata["tags"] || []),
          use_count: 0,
          is_featured: metadata["is_featured"] == true,
          is_template: true,
          revision: 1,
          thumbnail_path: "/template-assets/thumbs/#{slug}.webp"
        }

        %Design{}
        |> Design.changeset(attrs)
        |> Repo.insert!(
          on_conflict: {:replace, @managed_fields},
          conflict_target: :slug
        )

      {:error, reason} ->
        raise "Invalid bundled template #{slug}: #{inspect(reason)}"
    end
  end

  defp content_root do
    :tela
    |> :code.priv_dir()
    |> List.to_string()
    |> Path.join("content/templates")
  end

  defp read_json!(path) do
    path
    |> File.read!()
    |> JSON.decode!()
  end

  defp blank_to_nil(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(_value), do: nil
end
