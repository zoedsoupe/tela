defmodule Mix.Tasks.Tela.SyncElements do
  use Mix.Task

  @shortdoc "Synchronizes reviewed SVG element packs into the local catalog"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {options, rest, invalid} =
      OptionParser.parse(args, strict: [pack: :keep, list: :boolean, force: :boolean])

    if rest != [] or invalid != [] do
      Mix.raise("Usage: mix tela.sync_elements [--pack ID] [--force] [--list]")
    end

    if Keyword.get(options, :list, false) do
      list_packs()
    else
      pack_ids = options |> Keyword.get_values(:pack) |> List.flatten()

      case Tela.Catalog.PackSync.sync(pack_ids, force: Keyword.get(options, :force, false)) do
        {:ok, report} ->
          Enum.each(report.synced, fn {pack, {:ok, count}} ->
            Mix.shell().info("#{pack}: synchronized #{count} assets")
          end)

          Enum.each(report.skipped, &Mix.shell().info("#{&1}: up to date"))

        {:error, %{synced: synced, skipped: skipped}} ->
          Enum.each(synced, fn
            {pack, {:ok, count}} -> Mix.shell().info("#{pack}: synchronized #{count} assets")
            {pack, {:error, reason}} -> Mix.shell().error("#{pack}: failed: #{inspect(reason)}")
          end)

          Enum.each(skipped, &Mix.shell().info("#{&1}: up to date"))
          Mix.raise("One or more element packs failed. Run the command again to resume.")

        {:error, reason} ->
          Mix.raise("Could not synchronize element packs: #{inspect(reason)}")
      end
    end
  end

  defp list_packs do
    case Tela.Catalog.PackSync.manifest() do
      {:ok, packs} ->
        Enum.each(packs, fn pack ->
          Mix.shell().info(
            "#{pack.id}\t#{pack.kind}\t#{pack.style}\t#{pack.license.spdx}\t#{pack.source_ref}"
          )
        end)

      {:error, reason} ->
        Mix.raise("Could not load element-pack manifest: #{inspect(reason)}")
    end
  end
end
