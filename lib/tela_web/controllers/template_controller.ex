defmodule TelaWeb.TemplateController do
  use TelaWeb, :controller

  alias Tela.Content
  alias Tela.Content.SizePresets
  alias Tela.Designs.Design
  alias TelaWeb.DesignController

  @asset_filename ~r/\A[a-z0-9-]+\.webp\z/

  def index(conn, _params) do
    {:ok, templates} = Content.list_templates(conn.query_params)
    json(conn, %{templates: Enum.map(templates, &template_summary/1)})
  end

  def categories(conn, _params), do: json(conn, Content.list_categories())

  def show(conn, %{"slug" => slug}) do
    case Content.get_template(slug) do
      {:ok, template} -> json(conn, %{template: template_detail(template)})
      {:error, :not_found} -> error(conn, :not_found, "not_found", "Template não encontrado.")
    end
  end

  def use_template(conn, %{"slug" => slug}) do
    case Content.use_template(slug, %{created_by_id: profile_id(conn)}) do
      {:ok, design} ->
        conn
        |> put_status(:created)
        |> json(%{design: DesignController.detail(design)})

      {:error, :not_found} ->
        error(conn, :not_found, "not_found", "Template não encontrado.")

      {:error, reason} ->
        error(conn, :unprocessable_entity, "template_use_failed", inspect(reason))
    end
  end

  def size_presets(conn, _params), do: json(conn, SizePresets.all())

  def asset(conn, %{"kind" => kind, "filename" => filename}) do
    if kind in ["photos", "thumbs"] and Regex.match?(@asset_filename, filename) do
      path =
        :tela
        |> :code.priv_dir()
        |> List.to_string()
        |> Path.join("static/content/templates/#{kind}/#{filename}")

      case File.stat(path) do
        {:ok, %{type: :regular}} ->
          conn
          |> put_resp_header("content-type", "image/webp")
          |> put_resp_header("x-content-type-options", "nosniff")
          |> send_file(:ok, path)

        _ ->
          error(conn, :not_found, "not_found", "Imagem não encontrada.")
      end
    else
      error(conn, :not_found, "not_found", "Imagem não encontrada.")
    end
  end

  defp template_summary(%Design{} = template) do
    template
    |> DesignController.summary()
    |> Map.merge(Content.metadata(template))
    |> Map.put(:thumbnail_url, Content.thumbnail_url(template))
  end

  defp template_detail(%Design{} = template) do
    template
    |> DesignController.detail()
    |> Map.merge(Content.metadata(template))
    |> Map.put(:thumbnail_url, Content.thumbnail_url(template))
  end

  defp profile_id(%{assigns: %{current_profile: %{id: id}}}), do: id
  defp profile_id(_conn), do: nil

  defp error(conn, status, code, message) do
    conn
    |> put_status(status)
    |> json(%{error: %{code: code, message: message}})
  end
end
