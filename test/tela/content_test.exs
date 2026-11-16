defmodule Tela.ContentTest do
  use Tela.DataCase, async: false

  alias Tela.Content
  alias Tela.Content.Seed
  alias Tela.Designs
  alias Tela.Designs.{Design, Document}
  alias Tela.Repo

  setup do
    assert Seed.seed!() == 10
    :ok
  end

  test "seeds ten valid templates with stable metadata and public thumbnails" do
    assert {:ok, templates} = Content.list_templates()
    assert length(templates) == 10

    Enum.each(templates, fn summary ->
      assert is_binary(summary.slug)
      assert summary.is_template
      assert summary.use_count == 0
      assert summary.thumbnail_path == "/template-assets/thumbs/#{summary.slug}.webp"

      thumbnail_path =
        Path.join(:code.priv_dir(:tela), "static/content/templates/thumbs/#{summary.slug}.webp")

      assert File.exists?(thumbnail_path)

      assert {:ok, template} = Content.get_template(summary.slug)
      assert {:ok, _document} = Document.validate(template.document)
      assert is_list(Content.tags(template))
      assert is_map(Content.category(template))
    end)

    assert length(Content.list_categories()) == 8
  end

  test "seed is idempotent by slug without resetting use counts" do
    assert {:ok, template} = Content.get_template("serif-quote-card")

    template
    |> Design.changeset(%{use_count: 7})
    |> Repo.update!()

    assert Seed.seed!() == 10
    assert {:ok, seeded_again} = Content.get_template("serif-quote-card")
    assert seeded_again.id == template.id
    assert seeded_again.use_count == 7
    assert Repo.aggregate(Design, :count) == 10
  end

  test "using a template creates a design and increments the counter atomically" do
    assert {:ok, template} = Content.get_template("serif-quote-card")

    assert {:ok, design} = Content.use_template(template.slug)
    assert design.id != template.id
    refute design.is_template
    assert design.document == template.document

    assert {:ok, used_template} = Content.get_template(template.slug)
    assert used_template.use_count == 1
  end

  test "missing template use returns not found without creating a design" do
    assert {:error, :not_found} = Content.use_template("missing-template")
    assert {:ok, designs} = Designs.list()
    assert designs == []
  end
end
