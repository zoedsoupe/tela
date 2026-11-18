defmodule Tela.Catalog.PackSync do
  @moduledoc "Idempotent, resumable synchronization of reviewed catalog element packs."

  alias Tela.Catalog.{Asset, PackManifest, PackNormalizer, PackSource}
  alias Tela.Repo

  @default_concurrency 4
  @batch_size 250
  @max_archive_bytes 120 * 1024 * 1024
  @max_member_bytes 64 * 1024 * 1024
  @max_selected_bytes 400 * 1024 * 1024
  @max_archive_members 100_000
  @max_url_bytes 5 * 1024 * 1024
  @upsert_fields [
    :title_pt,
    :tags_pt,
    :type,
    :file_path,
    :pack_slug,
    :pack_name,
    :style,
    :svg,
    :width,
    :height,
    :colors,
    :is_recolorable,
    :license,
    :license_url,
    :attribution,
    :source_url,
    :sort_order
  ]

  @spec sync([String.t()], keyword()) :: {:ok, map()} | {:error, term()}
  def sync(pack_ids \\ [], options \\ []) do
    concurrency =
      options
      |> Keyword.get(:max_concurrency, @default_concurrency)
      |> max(1)
      |> min(@default_concurrency)

    force? = Keyword.get(options, :force, false)
    source = source_option(options)

    with {:ok, all_packs} <- manifest_option(options),
         {:ok, selected} <- PackManifest.select(all_packs, pack_ids),
         {:ok, current} <- sync_rows() do
      {todo, skipped} =
        Enum.split_with(selected, fn pack ->
          force? or not up_to_date?(pack, current)
        end)

      case process(todo, source, concurrency) do
        {:ok, results} ->
          {:ok, %{synced: results, skipped: Enum.map(skipped, & &1.id)}}

        {:error, results} ->
          {:error, %{synced: results, skipped: Enum.map(skipped, & &1.id)}}
      end
    end
  end

  @spec manifest() :: {:ok, [PackManifest.pack()]} | {:error, term()}
  def manifest, do: PackManifest.load()

  defp process([], _source, _concurrency), do: {:ok, %{}}

  defp process(packs, source, concurrency) do
    {npm_groups, _url_packs} = Enum.split_with(packs, &(&1.source.type == :npm))
    {archives, archive_failures} = fetch_archives(npm_groups, source, concurrency)
    {jobs, pack_states} = build_jobs(packs, archives, archive_failures)

    stream_results =
      jobs
      |> Task.async_stream(
        fn {pack, job} -> {pack.id, safe_perform_job(pack, job, source)} end,
        max_concurrency: concurrency,
        ordered: false,
        timeout: :infinity,
        on_timeout: :kill_task
      )
      |> Enum.reduce(pack_states, &collect_job/2)

    finalize(stream_results, packs)
  end

  defp fetch_archives([], _source, _concurrency), do: {%{}, %{}}

  defp fetch_archives(packs, source, concurrency) do
    groups =
      packs
      |> Enum.group_by(&source_key(&1.source))
      |> Enum.map(fn {key, group} -> {key, group} end)

    results =
      Task.async_stream(
        groups,
        fn {key, group} -> {key, fetch_archive(group, source)} end,
        max_concurrency: concurrency,
        ordered: false,
        timeout: :infinity,
        on_timeout: :kill_task
      )
      |> Enum.map(fn
        {:ok, {key, {:ok, files}}} -> {key, {:ok, files}}
        {:ok, {key, {:error, reason}}} -> {key, {:error, reason}}
        {:exit, reason} -> {{:unknown, reason}, {:error, reason}}
      end)

    Enum.reduce(results, {%{}, %{}}, fn
      {key, {:ok, files}}, {archives, failures} ->
        {Map.put(archives, key, files), failures}

      {key, {:error, reason}}, {archives, failures} ->
        affected = Enum.filter(packs, &(source_key(&1.source) == key))
        failures = Enum.reduce(affected, failures, &Map.put(&2, &1.id, reason))
        {archives, failures}
    end)
  end

  defp fetch_archive([pack | _] = packs, source) do
    with {:ok, archive} <- fetch(source, PackManifest.npm_url(pack)),
         :ok <- verify_npm_integrity(archive, pack.source.integrity, pack.source_ref),
         {:ok, files} <- archive_files(archive, Enum.flat_map(packs, &archive_patterns/1)) do
      {:ok, files}
    end
  end

  defp archive_patterns(pack) do
    pack.files.include ++
      Enum.reject([pack.tags.file, pack.license.file], &(&1 == ""))
  end

  defp archive_files(archive, patterns)
       when is_binary(archive) and byte_size(archive) <= @max_archive_bytes do
    with {:ok, entries} <- :erl_tar.extract({:binary, archive}, [:compressed, :memory]) do
      wanted = Enum.map(patterns, &compile_glob/1)

      selected =
        entries
        |> Enum.reduce_while({:ok, %{}, 0, 0}, fn {raw_path, bytes}, {:ok, found, total, count} ->
          path = raw_path |> to_string() |> String.replace("\\", "/")
          relative = archive_relative_path(path)

          cond do
            count >= @max_archive_members ->
              {:halt, {:error, :too_many_archive_entries}}

            is_nil(relative) or not is_binary(bytes) ->
              {:cont, {:ok, found, total, count + 1}}

            byte_size(bytes) > @max_member_bytes ->
              {:halt, {:error, {:archive_member_too_large, relative}}}

            matches_any?(relative, wanted) ->
              next_total = total + byte_size(bytes)

              if next_total > @max_selected_bytes do
                {:halt, {:error, :archive_selection_too_large}}
              else
                {:cont, {:ok, Map.put(found, relative, bytes), next_total, count + 1}}
              end

            true ->
              {:cont, {:ok, found, total, count + 1}}
          end
        end)

      case selected do
        {:ok, files, _total, _count} -> {:ok, files}
        {:error, _reason} = error -> error
      end
    else
      {:error, reason} -> {:error, {:invalid_tarball, reason}}
    end
  rescue
    _ -> {:error, :invalid_tarball}
  end

  defp archive_files(_archive, _patterns), do: {:error, :archive_too_large}

  defp archive_relative_path(path) do
    parts = String.split(path, "/")

    case parts do
      [root | rest] when root != "" and rest != [] ->
        if Enum.any?(parts, &(&1 in ["", ".", ".."])) or String.starts_with?(path, "/"),
          do: nil,
          else: Enum.join(rest, "/")

      _ ->
        nil
    end
  end

  defp verify_npm_integrity(archive, "sha512-" <> expected, source_ref) do
    actual = :crypto.hash(:sha512, archive) |> Base.encode64()
    if actual == expected, do: :ok, else: {:error, {:integrity_mismatch, source_ref}}
  end

  defp verify_npm_integrity(_archive, _integrity, _source_ref),
    do: {:error, :unsupported_integrity}

  defp build_jobs(packs, archives, archive_failures) do
    {jobs, states} =
      Enum.reduce(packs, {[], %{}}, fn pack, {jobs, states} ->
        case Map.fetch(archive_failures, pack.id) do
          {:ok, reason} ->
            {jobs, Map.put(states, pack.id, initial_state(pack, 0, reason))}

          :error when pack.source.type == :urls ->
            include = Enum.map(pack.files.include, &compile_glob/1)
            exclude = Enum.map(pack.files.exclude, &compile_glob/1)

            items =
              Enum.filter(pack.source.items, fn item ->
                matches_any?(item.name, include) and not matches_any?(item.name, exclude)
              end)

            pack_jobs = Enum.map(items, &{pack, {:url, &1}})
            error = if pack_jobs == [], do: {:no_selected_url_files, pack.id}, else: nil

            {Enum.reverse(pack_jobs, jobs),
             Map.put(states, pack.id, initial_state(pack, length(pack_jobs), error))}

          :error ->
            files = Map.get(archives, source_key(pack.source), %{})

            case pack_jobs(pack, files) do
              {:ok, pack_jobs} ->
                {Enum.reverse(Enum.map(pack_jobs, &{pack, &1}), jobs),
                 Map.put(states, pack.id, initial_state(pack, length(pack_jobs), nil))}

              {:error, reason} ->
                {jobs, Map.put(states, pack.id, initial_state(pack, 0, reason))}
            end
        end
      end)

    {Enum.reverse(jobs), states}
  end

  defp pack_jobs(pack, files) do
    with :ok <- check_license(pack, files),
         {:ok, tag_table} <- tag_table(pack, files) do
      if pack.files.reader == "iconify-json" do
        selected = selected_paths(pack, files)

        case Enum.find(selected, &String.ends_with?(&1, ".json")) do
          nil -> {:error, {:missing_iconify_file, pack.id}}
          path -> {:ok, [{:iconify, path, Map.fetch!(files, path), tag_table}]}
        end
      else
        svg_jobs =
          selected_paths(pack, files)
          |> Enum.filter(&String.ends_with?(&1, ".svg"))
          |> Enum.map(fn path ->
            stem = Path.basename(path, ".svg")

            tag_name =
              stem
              |> strip_prefix(pack.naming.strip_prefix)
              |> strip_suffix(pack.naming.strip_suffix)

            tags = Map.get(tag_table, tag_name, Map.get(tag_table, stem, []))
            {:svg, path, Map.fetch!(files, path), tags}
          end)

        if svg_jobs == [], do: {:error, {:no_selected_svgs, pack.id}}, else: {:ok, svg_jobs}
      end
    end
  end

  defp check_license(pack, files) do
    case pack.license do
      %{file: "", match: ""} ->
        :ok

      %{file: file, match: matcher} ->
        with {:ok, content} <- Map.fetch(files, file),
             {:ok, regex} <- Regex.compile(matcher),
             true <- Regex.match?(regex, content) do
          :ok
        else
          _ -> {:error, {:license_mismatch, pack.id}}
        end
    end
  end

  defp tag_table(%{tags: %{format: "none"}}, _files), do: {:ok, %{}}

  defp tag_table(pack, files) do
    case Map.fetch(files, pack.tags.file) do
      {:ok, content} -> PackNormalizer.parse_tag_table(pack.tags.format, content)
      :error -> {:ok, %{}}
    end
  end

  defp selected_paths(pack, files) do
    include = Enum.map(pack.files.include, &compile_glob/1)
    exclude = Enum.map(pack.files.exclude, &compile_glob/1)

    files
    |> Map.keys()
    |> Enum.filter(fn path -> matches_any?(path, include) and not matches_any?(path, exclude) end)
    |> Enum.sort()
  end

  defp perform_job(pack, {:url, item}, source) do
    with {:ok, content} <- fetch(source, item.url),
         true <- byte_size(content) <= @max_url_bytes,
         actual <- :crypto.hash(:sha256, content) |> Base.encode16(case: :lower),
         true <- actual == item.sha256 do
      PackNormalizer.normalize_asset(pack, item.name, content, item.tags, item.url)
      |> wrap_record()
    else
      false -> {:error, {:url_integrity_or_size, item.name}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp perform_job(pack, {:svg, path, content, tags}, _source) do
    PackNormalizer.normalize_asset(pack, Path.basename(path, ".svg"), content, tags, nil)
    |> wrap_record()
  end

  defp perform_job(pack, {:iconify, _path, content, tag_table}, _source) do
    case PackNormalizer.normalize_iconify(content, pack, tag_table) do
      {:ok, records} -> {:ok, records}
      {:error, reason} -> {:error, reason}
    end
  end

  defp perform_job(_pack, _job, _source), do: {:error, :invalid_pack_job}

  defp safe_perform_job(pack, job, source) do
    perform_job(pack, job, source)
  rescue
    error -> {:error, {:worker_exception, Exception.message(error)}}
  catch
    kind, reason -> {:error, {:worker_exit, kind, reason}}
  end

  defp wrap_record({:ok, record}), do: {:ok, [record]}
  defp wrap_record({:skip, _reason}), do: {:ok, []}

  defp collect_job({:ok, {pack_id, {:ok, records}}}, states) do
    update_state(states, pack_id, fn state ->
      state = %{state | completed: state.completed + 1, buffer: state.buffer ++ records}
      flush_ready_batch(pack_id, state)
    end)
  end

  defp collect_job({:ok, {pack_id, {:error, reason}}}, states) do
    update_state(states, pack_id, fn state ->
      %{state | completed: state.completed + 1, error: state.error || reason}
    end)
  end

  defp collect_job({:exit, reason}, states) do
    case Enum.find(states, fn {_id, state} -> state.completed < state.expected end) do
      {pack_id, _state} ->
        update_state(states, pack_id, fn state ->
          %{state | completed: state.completed + 1, error: state.error || {:worker_exit, reason}}
        end)

      nil ->
        states
    end
  end

  defp flush_ready_batch(pack_id, state) when length(state.buffer) >= @batch_size do
    {batch, rest} = Enum.split(state.buffer, @batch_size)
    write_batch!(batch)
    flush_ready_batch(pack_id, %{state | buffer: rest, written: state.written + length(batch)})
  end

  defp flush_ready_batch(_pack_id, state), do: state

  defp finalize(states, packs) do
    results =
      Enum.reduce(packs, %{}, fn pack, results ->
        state = Map.fetch!(states, pack.id)

        cond do
          state.error != nil ->
            Map.put(results, pack.id, {:error, state.error})

          state.expected == 0 ->
            Map.put(results, pack.id, {:error, :no_pack_jobs})

          state.completed != state.expected ->
            Map.put(results, pack.id, {:error, :incomplete_pack_run})

          state.buffer == [] and state.written == 0 ->
            Map.put(results, pack.id, {:error, :no_usable_assets})

          true ->
            write_batch!(state.buffer)
            record_sync!(pack)
            Map.put(results, pack.id, {:ok, state.written + length(state.buffer)})
        end
      end)

    if Enum.any?(results, fn {_id, result} -> match?({:error, _}, result) end) do
      {:error, results}
    else
      {:ok, results}
    end
  end

  defp write_batch!([]), do: :ok

  defp write_batch!(records) do
    Repo.insert_all(
      Asset,
      records,
      on_conflict: {:replace, @upsert_fields},
      conflict_target: [:slug]
    )

    :ok
  end

  defp record_sync!(pack) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.insert_all(
      "catalog_pack_syncs",
      [
        %{
          pack_slug: pack.id,
          fingerprint: pack.fingerprint,
          source_ref: pack.source_ref,
          inserted_at: now,
          updated_at: now
        }
      ],
      on_conflict: {:replace, [:fingerprint, :source_ref, :updated_at]},
      conflict_target: [:pack_slug]
    )

    :ok
  end

  defp initial_state(pack, expected, error) do
    %{pack: pack, expected: expected, completed: 0, error: error, buffer: [], written: 0}
  end

  defp update_state(states, pack_id, fun) do
    case Map.fetch(states, pack_id) do
      {:ok, state} -> Map.put(states, pack_id, fun.(state))
      :error -> states
    end
  end

  defp sync_rows do
    case Repo.query("SELECT pack_slug, fingerprint FROM catalog_pack_syncs") do
      {:ok, %{rows: rows}} ->
        {:ok, Map.new(rows, fn [slug, fingerprint] -> {slug, fingerprint} end)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp up_to_date?(pack, current) do
    Map.get(current, pack.id) == pack.fingerprint and
      case Repo.query("SELECT count(*) FROM catalog_assets WHERE pack_slug = ?", [pack.id]) do
        {:ok, %{rows: [[count]]}} -> count > 0
        _ -> false
      end
  end

  defp manifest_option(options) do
    case Keyword.get(options, :manifest) do
      packs when is_list(packs) -> {:ok, packs}
      nil -> PackManifest.load()
      _ -> {:error, :invalid_manifest_option}
    end
  end

  defp source_option(options) do
    case Keyword.get(options, :source, {PackSource.HTTP, nil}) do
      {module, state} when is_atom(module) -> {module, state}
      module when is_atom(module) -> {module, nil}
      other -> other
    end
  end

  defp fetch({module, state}, url) when is_atom(module), do: module.fetch(state, url)

  defp fetch(source, url) when is_function(source, 1), do: source.(url)

  defp fetch(_source, _url), do: {:error, :invalid_pack_source}

  defp source_key(%{type: :npm, package: package, version: version, integrity: integrity}),
    do: {:npm, package, version, integrity}

  defp strip_prefix(name, ""), do: name
  defp strip_prefix(name, prefix), do: String.trim_leading(name, prefix)
  defp strip_suffix(name, ""), do: name
  defp strip_suffix(name, suffix), do: String.trim_trailing(name, suffix)

  defp compile_glob(pattern) do
    {regex, index} = compile_glob(pattern, 0, [])
    _ = index
    Regex.compile!("^" <> Enum.join(Enum.reverse(regex)) <> "$")
  end

  defp compile_glob(<<>>, index, acc), do: {acc, index}

  defp compile_glob(<<"**/", rest::binary>>, index, acc),
    do: compile_glob(rest, index + 3, ["(?:.*/)?" | acc])

  defp compile_glob(<<"**", rest::binary>>, index, acc),
    do: compile_glob(rest, index + 2, [".*" | acc])

  defp compile_glob(<<"*", rest::binary>>, index, acc),
    do: compile_glob(rest, index + 1, ["[^/]*" | acc])

  defp compile_glob(<<"?", rest::binary>>, index, acc),
    do: compile_glob(rest, index + 1, ["[^/]" | acc])

  defp compile_glob(<<char::utf8, rest::binary>>, index, acc),
    do:
      compile_glob(rest, index + byte_size(<<char::utf8>>), [Regex.escape(<<char::utf8>>) | acc])

  defp matches_any?(_path, []), do: false
  defp matches_any?(path, regexes), do: Enum.any?(regexes, &Regex.match?(&1, path))
end
