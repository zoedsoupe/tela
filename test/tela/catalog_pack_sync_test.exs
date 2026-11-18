defmodule Tela.Catalog.PackSyncFakeSource do
  @behaviour Tela.Catalog.PackSource

  defstruct responses: %{}, owner: nil

  @impl true
  def fetch(%__MODULE__{responses: responses, owner: owner}, url) do
    if owner, do: send(owner, {:pack_fetch, url})
    Map.get(responses, url, {:error, {:not_found, url}})
  end
end

defmodule Tela.Catalog.PackSyncTest do
  use Tela.DataCase, async: false

  alias Tela.Catalog
  alias Tela.Catalog.{PackManifest, PackNormalizer, PackSync}
  alias Tela.Catalog.PackSyncFakeSource

  @svg ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path fill="#3355aa" d="M0 0h24v24H0z"/></svg>|

  test "loads the reviewed non-generated manifest and rejects invalid licenses and hosts" do
    assert {:ok, packs} = PackManifest.load()
    assert length(packs) == 17
    refute Enum.any?(packs, &(&1.source.type == :generated))
    assert Enum.any?(packs, &(&1.id == "lucide"))
    assert Enum.any?(packs, &(&1.id == "open-peeps"))
    assert length(Enum.find(packs, &(&1.id == "open-doodles")).source.items) == 32
    assert length(Enum.find(packs, &(&1.id == "open-peeps")).source.items) == 93

    valid = manifest_with_npm_pack(fake_archive())
    assert {:ok, [_pack]} = PackManifest.parse(JSON.encode!(valid))

    invalid_license =
      put_in(valid, ["packs", Access.at(0), "license", "spdx"], "GPL-3.0-only")

    assert {:error, message} = PackManifest.parse(JSON.encode!(invalid_license))
    assert message =~ "unreviewed license"

    invalid_host =
      put_in(valid, ["packs", Access.at(0), "source"], %{
        "type" => "urls",
        "index" => "assets.json"
      })

    index =
      JSON.encode!([
        %{
          "name" => "icon.svg",
          "url" => "http://example.com/icon.svg",
          "sha256" => String.duplicate("a", 64)
        }
      ])

    assert {:error, message} =
             PackManifest.parse(JSON.encode!(invalid_host), %{"assets.json" => index})

    assert message =~ "invalid URL index entry"
  end

  test "normalizes safe SVG and Iconify data while rejecting unsafe SVG constructs" do
    pack = parsed_pack!(manifest_with_npm_pack(fake_archive()))

    assert {:ok, normalized} =
             PackNormalizer.normalize_svg(
               @svg,
               %{mode: "mono", size: 48, frame: true, color: "#7a64e0"}
             )

    assert normalized.width == 48
    assert normalized.height == 48
    assert normalized.svg =~ ~s(fill="#7a64e0")
    assert normalized.svg =~ ~s(<rect x="0" y="0" width="24" height="24" fill="none"/>)

    nested_svg =
      ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><g><path fill="#3355aa" d="M0 0h24v24H0z"/></g></svg>|

    assert {:ok, _nested} =
             PackNormalizer.normalize_svg(nested_svg, %{
               mode: "mono",
               size: 24,
               frame: false,
               color: "#7a64e0"
             })

    iconify =
      JSON.encode!(%{
        "prefix" => "noto",
        "width" => 32,
        "height" => 32,
        "icons" => %{
          "smiling-face" => %{
            "body" => ~s|<path fill="#ffcc00" d="M0 0h32v32H0z"/>|
          }
        },
        "aliases" => %{"happy" => %{"parent" => "smiling-face"}}
      })

    assert {:ok, [icon]} =
             PackNormalizer.normalize_iconify(iconify, %{
               pack
               | id: "noto-emoji",
                 name: "Noto Emoji",
                 kind: "sticker",
                 style: "colour",
                 normalize: %{mode: "colour", size: 128, frame: false, color: "#7a64e0"}
             })

    assert icon.slug == "noto-emoji-smiling-face"
    assert icon.title_pt == "Smiling Face"
    assert icon.svg =~ ~s(fill="#ffcc00")
    assert icon.is_recolorable == false
    assert icon.tags_pt =~ "happy"

    phosphor_tags = """
    Icons = /* @__PURE__ */ ((e) => (e.Arrows = "Arrows", e))(Icons || {});
    { name: "airplane", pascal_name: "Airplane", categories: [Icons.Arrows], tags: ["plane", "flight"] }
    """

    assert {:ok, %{"airplane" => tags}} =
             PackNormalizer.parse_tag_table("phosphor-js", phosphor_tags)

    assert "arrows" in tags
    assert "flight" in tags

    assert {:error, :unsafe_svg} =
             PackNormalizer.normalize_svg(
               ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"><script>alert(1)</script></svg>|,
               %{mode: "mono", size: 24, frame: false, color: "#7a64e0"}
             )

    assert {:error, :unsafe_svg} =
             PackNormalizer.normalize_svg(
               ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1" onload="alert(1)"><path d="M0 0"/></svg>|,
               %{mode: "mono", size: 24, frame: false, color: "#7a64e0"}
             )

    assert {:error, :external_reference} =
             PackNormalizer.normalize_svg(
               ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"><image href="https://example.com/a.png"/></svg>|,
               %{mode: "mono", size: 24, frame: false, color: "#7a64e0"}
             )

    assert {:error, :unsafe_svg} =
             PackNormalizer.normalize_svg(
               ~s|<!DOCTYPE svg><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"><path d="M0 0"/></svg>|,
               %{mode: "mono", size: 24, frame: false, color: "#7a64e0"}
             )

    assert {:error, :unsafe_svg} =
             PackNormalizer.normalize_svg(
               ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1 1"><foreignObject><div/></foreignObject></svg>|,
               %{mode: "mono", size: 24, frame: false, color: "#7a64e0"}
             )

    oversized = "<svg>" <> String.duplicate(" ", 2 * 1024 * 1024) <> "</svg>"
    assert {:error, :svg_too_large} = PackNormalizer.normalize_svg(oversized, %{mode: "mono"})
  end

  test "selects packs, deduplicates a shared npm release, and stays idempotent" do
    archive = fake_archive()
    manifest = manifest_with_npm_pack(archive, second_pack: true)
    assert {:ok, packs} = PackManifest.parse(JSON.encode!(manifest))
    [first, second] = packs

    source = fake_source(%{PackManifest.npm_url(first) => {:ok, archive}})
    assert {:ok, report} = PackSync.sync([first.id, second.id], manifest: packs, source: source)
    assert report.synced[first.id] == {:ok, 1}
    assert report.synced[second.id] == {:ok, 1}
    assert_receive {:pack_fetch, _url}
    refute_receive {:pack_fetch, _url}

    assert {:ok, skipped} = PackSync.sync([first.id, second.id], manifest: packs, source: source)
    assert skipped.synced == %{}
    assert skipped.skipped == [first.id, second.id]
    refute_receive {:pack_fetch, _url}

    assert {:error, {:unknown_packs, ["missing-pack"]}} =
             PackSync.sync(["missing-pack"], manifest: packs, source: source)

    assert {:ok, %{count: 1, results: [asset]}} = Catalog.list_elements(%{pack: first.id})
    assert asset.slug == "#{first.id}-alpha"
    assert asset.file_path == "inline:#{asset.slug}"
    assert asset.title_pt == "Alpha"
    assert asset.pack_slug == first.id

    api_asset = Catalog.to_api(asset)
    assert api_asset.id == asset.slug
    assert api_asset.pack == %{id: first.id, slug: first.id, name: first.name}
    assert api_asset.svg_url == "data:image/svg+xml;base64," <> Base.encode64(asset.svg)

    assert {:ok, packs_api} = Catalog.list_packs()
    assert Enum.count(packs_api, &(&1.id == first.id)) == 1
  end

  test "excludes brand assets according to the pack naming rule" do
    archive = fake_archive(brand: true)
    manifest = manifest_with_npm_pack(archive, brand_rule: "^brand-")
    assert {:ok, [pack]} = PackManifest.parse(JSON.encode!(manifest))
    source = fake_source(%{PackManifest.npm_url(pack) => {:ok, archive}})

    assert {:ok, report} = PackSync.sync([pack.id], manifest: [pack], source: source)
    assert report.synced[pack.id] == {:ok, 1}

    assert Repo.query!("SELECT count(*) FROM catalog_assets WHERE pack_slug = ?", [pack.id]).rows ==
             [[1]]

    assert Repo.query!("SELECT count(*) FROM catalog_assets WHERE slug LIKE ?", [
             "#{pack.id}-brand-%"
           ]).rows ==
             [[0]]
  end

  test "leaves no fingerprint after a license mismatch" do
    archive = fake_archive(license: "not MIT")
    manifest = manifest_with_npm_pack(archive)
    assert {:ok, [pack]} = PackManifest.parse(JSON.encode!(manifest))
    source = fake_source(%{PackManifest.npm_url(pack) => {:ok, archive}})

    assert {:error, report} = PackSync.sync([pack.id], manifest: [pack], source: source)
    assert {:error, {:license_mismatch, "test-icons"}} = report.synced[pack.id]
    assert Repo.query!("SELECT count(*) FROM catalog_pack_syncs").rows == [[0]]

    assert Repo.query!("SELECT count(*) FROM catalog_assets WHERE pack_slug = ?", [pack.id]).rows ==
             [[0]]
  end

  test "rejects a bad npm integrity digest without recording a fingerprint" do
    archive = fake_archive()
    manifest = manifest_with_npm_pack(archive)
    assert {:ok, [pack]} = PackManifest.parse(JSON.encode!(manifest))
    source = fake_source(%{PackManifest.npm_url(pack) => {:ok, archive <> "changed"}})

    assert {:error, report} = PackSync.sync([pack.id], manifest: [pack], source: source)
    assert {:error, {:integrity_mismatch, _}} = report.synced[pack.id]
    assert Repo.query!("SELECT count(*) FROM catalog_pack_syncs").rows == [[0]]
  end

  test "resumes a URL pack after a failed file and verifies each SHA-256" do
    svg = @svg
    digest = :crypto.hash(:sha256, svg) |> Base.encode16(case: :lower)
    second_svg = String.replace(svg, "#3355aa", "#cc3355")
    second_digest = :crypto.hash(:sha256, second_svg) |> Base.encode16(case: :lower)
    manifest = manifest_with_url_pack()

    indexes = %{
      "assets.json" =>
        JSON.encode!([
          %{
            "name" => "first.svg",
            "url" => "https://opendoodles.s3-us-west-1.amazonaws.com/first.svg",
            "sha256" => digest,
            "tags" => ["people"]
          },
          %{
            "name" => "second.svg",
            "url" => "https://opendoodles.s3-us-west-1.amazonaws.com/second.svg",
            "sha256" => second_digest,
            "tags" => ["sketch"]
          }
        ])
    }

    assert {:ok, [pack]} = PackManifest.parse(JSON.encode!(manifest), indexes)

    source =
      fake_source(%{
        "https://opendoodles.s3-us-west-1.amazonaws.com/first.svg" => {:ok, svg},
        "https://opendoodles.s3-us-west-1.amazonaws.com/second.svg" => {:ok, "tampered"}
      })

    assert {:error, report} = PackSync.sync([pack.id], manifest: [pack], source: source)
    assert {:error, {:url_integrity_or_size, "second.svg"}} = report.synced[pack.id]
    assert Repo.query!("SELECT count(*) FROM catalog_pack_syncs").rows == [[0]]

    responses =
      source
      |> elem(1)
      |> Map.fetch!(:responses)
      |> Map.put(
        "https://opendoodles.s3-us-west-1.amazonaws.com/second.svg",
        {:ok, second_svg}
      )

    source = fake_source(responses)

    assert {:ok, %{synced: %{"url-test" => {:ok, 2}}}} =
             PackSync.sync([pack.id], manifest: [pack], source: source)

    assert Repo.query!("SELECT count(*) FROM catalog_pack_syncs").rows == [[1]]

    assert Repo.query!("SELECT count(*) FROM catalog_assets WHERE pack_slug = ?", [pack.id]).rows ==
             [[2]]
  end

  test "resumes after completed batches using stable upsert slugs" do
    digest = :crypto.hash(:sha256, @svg) |> Base.encode16(case: :lower)
    total = 252

    items =
      for index <- 1..total do
        name = "asset-#{String.pad_leading(Integer.to_string(index), 3, "0")}.svg"

        %{
          "name" => name,
          "url" => "https://opendoodles.s3-us-west-1.amazonaws.com/#{name}",
          "sha256" => digest,
          "tags" => ["illustration"]
        }
      end

    manifest = manifest_with_url_pack()
    indexes = %{"assets.json" => JSON.encode!(items)}
    assert {:ok, [pack]} = PackManifest.parse(JSON.encode!(manifest), indexes)

    responses =
      Map.new(items, fn item -> {item["url"], {:ok, @svg}} end)
      |> Map.put(List.last(items)["url"], {:ok, "tampered"})

    assert {:error, report} =
             PackSync.sync([pack.id], manifest: [pack], source: fake_source(responses, nil))

    assert {:error, {:url_integrity_or_size, _name}} = report.synced[pack.id]
    assert Repo.query!("SELECT count(*) FROM catalog_pack_syncs").rows == [[0]]

    assert Repo.query!("SELECT count(*) FROM catalog_assets WHERE pack_slug = ?", [pack.id]).rows ==
             [[250]]

    responses = Map.put(responses, List.last(items)["url"], {:ok, @svg})

    assert {:ok, %{synced: %{"url-test" => {:ok, ^total}}}} =
             PackSync.sync([pack.id], manifest: [pack], source: fake_source(responses, nil))

    assert Repo.query!("SELECT count(*) FROM catalog_pack_syncs").rows == [[1]]

    assert Repo.query!("SELECT count(*) FROM catalog_assets WHERE pack_slug = ?", [pack.id]).rows ==
             [[total]]
  end

  defp fake_source(responses, owner \\ self()),
    do: {PackSyncFakeSource, %PackSyncFakeSource{responses: responses, owner: owner}}

  defp parsed_pack!(manifest) do
    {:ok, [pack]} = PackManifest.parse(JSON.encode!(manifest))
    pack
  end

  defp manifest_with_npm_pack(archive, options \\ []) do
    integrity =
      "sha512-" <>
        (:crypto.hash(:sha512, archive) |> Base.encode64())

    first =
      npm_pack("test-icons", integrity,
        include: ["icons/*.svg"],
        brand_rule: options[:brand_rule]
      )

    packs =
      if Keyword.get(options, :second_pack, false) do
        [first, npm_pack("test-icons-alt", integrity, include: ["icons/alpha.svg"])]
      else
        [first]
      end

    %{"schema" => 1, "packs" => packs}
  end

  defp npm_pack(id, integrity, options) do
    %{
      "id" => id,
      "name" => String.capitalize(String.replace(id, "-", " ")),
      "kind" => "icon",
      "style" => "outline",
      "description" => "Fixture pack",
      "homepage" => "https://example.com/#{id}",
      "sort_order" => 1,
      "source" => %{
        "type" => "npm",
        "package" => "fixture-icons",
        "version" => "1.0.0",
        "integrity" => integrity
      },
      "files" => %{"include" => options[:include], "reader" => "svg"},
      "naming" => %{"brand" => options[:brand_rule] || ""},
      "tags" => %{"format" => "none"},
      "normalize" => %{"mode" => "mono", "size" => 24, "frame" => true},
      "license" => %{
        "spdx" => "MIT",
        "url" => "https://example.com/LICENSE",
        "file" => "LICENSE",
        "match" => "MIT License"
      },
      "attribution" => "Fixture Icons contributors"
    }
  end

  defp manifest_with_url_pack do
    %{
      "schema" => 1,
      "packs" => [
        %{
          "id" => "url-test",
          "name" => "URL Fixture",
          "kind" => "illustration",
          "style" => "colour",
          "sort_order" => 2,
          "source" => %{"type" => "urls", "index" => "assets.json"},
          "files" => %{"include" => ["*.svg"]},
          "license" => %{
            "spdx" => "CC0-1.0",
            "url" => "https://creativecommons.org/publicdomain/zero/1.0/"
          },
          "attribution" => "Fixture artwork",
          "normalize" => %{"mode" => "colour"}
        }
      ]
    }
  end

  defp fake_archive(options \\ []) do
    directory = Path.join(System.tmp_dir!(), "tela-pack-#{System.unique_integer([:positive])}")
    svg_dir = Path.join(directory, "package/icons")
    File.mkdir_p!(svg_dir)

    File.write!(
      Path.join(directory, "package/LICENSE"),
      Keyword.get(options, :license, "MIT License")
    )

    File.write!(Path.join(svg_dir, "alpha.svg"), @svg)

    if Keyword.get(options, :brand, false) do
      File.write!(Path.join(svg_dir, "brand-mark.svg"), @svg)
    end

    paths =
      ["package/LICENSE", "package/icons/alpha.svg"] ++
        if(Keyword.get(options, :brand, false), do: ["package/icons/brand-mark.svg"], else: [])

    archive =
      File.cd!(directory, fn ->
        :ok = :erl_tar.create(~c"pack.tgz", Enum.map(paths, &String.to_charlist/1), [:compressed])
        File.read!("pack.tgz")
      end)

    File.rm_rf!(directory)
    archive
  end
end
