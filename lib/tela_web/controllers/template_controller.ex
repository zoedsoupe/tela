defmodule TelaWeb.TemplateController do
  use TelaWeb, :controller

  alias Tela.Designs
  alias Tela.Designs.Preset
  alias TelaWeb.DesignController

  def index(conn, _params) do
    {:ok, templates} = Designs.list_templates(conn.query_params)
    json(conn, %{templates: Enum.map(templates, &DesignController.summary/1)})
  end

  def show(conn, %{"id" => id}) do
    case Designs.get_template(id) do
      {:ok, template} -> json(conn, %{template: DesignController.detail(template)})
      {:error, :not_found} -> error(conn, :not_found, "not_found", "Template não encontrado.")
    end
  end

  def presets(conn, _params), do: json(conn, %{presets: Enum.map(Preset.all(), &preset_json/1)})

  defp preset_json(preset) do
    %{
      id: preset.id,
      name: preset.name,
      width: preset.width,
      height: preset.height,
      category: preset.category
    }
  end

  defp error(conn, status, code, message) do
    conn
    |> put_status(status)
    |> json(%{error: %{code: code, message: message}})
  end
end
