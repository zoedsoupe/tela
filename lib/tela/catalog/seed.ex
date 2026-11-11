defmodule Tela.Catalog.Seed do
  @moduledoc "Seeds the workspace-wide catalog with locally authored SVG assets."

  alias Tela.Catalog.Asset
  alias Tela.Repo

  @assets [
    %{
      slug: "shape-circle",
      title_pt: "Círculo",
      tags_pt: "forma círculo redondo geometria",
      type: "shape",
      svg:
        ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128"><circle cx="64" cy="64" r="54" fill="#F2765B"/></svg>|
    },
    %{
      slug: "shape-square",
      title_pt: "Quadrado arredondado",
      tags_pt: "forma quadrado retângulo geometria",
      type: "shape",
      svg:
        ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128"><rect x="12" y="12" width="104" height="104" rx="18" fill="#3859A8"/></svg>|
    },
    %{
      slug: "shape-triangle",
      title_pt: "Triângulo",
      tags_pt: "forma triângulo geometria seta",
      type: "shape",
      svg:
        ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128"><path d="M64 9 121 112H7z" fill="#B4C77A"/></svg>|
    },
    %{
      slug: "shape-star",
      title_pt: "Estrela",
      tags_pt: "forma estrela brilho destaque",
      type: "shape",
      svg:
        ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128"><path d="m64 7 14 39 42 1-33 25 12 41-35-24-35 24 12-41L8 47l42-1z" fill="#F2C14E"/></svg>|
    },
    %{
      slug: "shape-line",
      title_pt: "Linha ondulada",
      tags_pt: "forma linha curva traço decoração",
      type: "shape",
      svg:
        ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 160 64"><path d="M5 42c20-34 38 27 58-7s37 27 58-6 28 2 34 5" fill="none" stroke="#242424" stroke-linecap="round" stroke-width="9"/></svg>|
    },
    %{
      slug: "icon-heart",
      title_pt: "Coração vermelho",
      tags_pt: "ícone coração amor carinho curtida",
      type: "icon",
      svg:
        ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128"><path d="M64 112 18 68C-7 42 31 4 64 35 97 4 135 42 110 68z" fill="#E85D5D"/></svg>|
    },
    %{
      slug: "icon-check",
      title_pt: "Marca de confirmação",
      tags_pt: "ícone confirmar concluído certo sucesso",
      type: "icon",
      svg:
        ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128"><circle cx="64" cy="64" r="56" fill="#B4C77A"/><path d="m35 65 19 19 40-42" fill="none" stroke="#242424" stroke-linecap="round" stroke-linejoin="round" stroke-width="12"/></svg>|
    },
    %{
      slug: "icon-sparkle",
      title_pt: "Brilho de quatro pontas",
      tags_pt: "ícone brilho estrela magia luz",
      type: "icon",
      svg:
        ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128"><path d="M64 5c7 35 24 52 59 59-35 7-52 24-59 59C57 88 40 71 5 64 40 57 57 40 64 5z" fill="#F2C14E"/></svg>|
    },
    %{
      slug: "icon-arrow-right",
      title_pt: "Seta para a direita",
      tags_pt: "ícone seta direção avançar próximo",
      type: "icon",
      svg:
        ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128"><path d="M14 64h96M69 23l41 41-41 41" fill="none" stroke="#3859A8" stroke-linecap="round" stroke-linejoin="round" stroke-width="13"/></svg>|
    },
    %{
      slug: "icon-sun",
      title_pt: "Sol",
      tags_pt: "ícone sol verão luz clima calor",
      type: "icon",
      svg:
        ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128"><circle cx="64" cy="64" r="25" fill="#F2C14E"/><g stroke="#F2765B" stroke-linecap="round" stroke-width="9"><path d="M64 8v18M64 102v18M8 64h18M102 64h18M24 24l13 13M91 91l13 13M104 24 91 37M37 91l-13 13"/></g></svg>|
    },
    %{
      slug: "illustration-flower",
      title_pt: "Flor coral",
      tags_pt: "ilustração flor jardim natureza botânica",
      type: "illustration",
      svg:
        ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 180 180"><g fill="#F2765B"><ellipse cx="90" cy="43" rx="20" ry="34"/><ellipse cx="90" cy="137" rx="20" ry="34"/><ellipse cx="43" cy="90" rx="34" ry="20"/><ellipse cx="137" cy="90" rx="34" ry="20"/><ellipse cx="57" cy="57" rx="20" ry="34" transform="rotate(-45 57 57)"/><ellipse cx="123" cy="57" rx="20" ry="34" transform="rotate(45 123 57)"/><ellipse cx="57" cy="123" rx="20" ry="34" transform="rotate(45 57 123)"/><ellipse cx="123" cy="123" rx="20" ry="34" transform="rotate(-45 123 123)"/></g><circle cx="90" cy="90" r="23" fill="#F2C14E"/></svg>|
    },
    %{
      slug: "illustration-leaf",
      title_pt: "Ramo de folhas",
      tags_pt: "ilustração folha ramo planta natureza botânica",
      type: "illustration",
      svg:
        ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 180 180"><path d="M88 162c2-52 11-91 52-136" fill="none" stroke="#3859A8" stroke-linecap="round" stroke-width="7"/><g fill="#B4C77A" stroke="#3859A8" stroke-width="4"><path d="M83 125C40 126 27 99 31 72c28-1 55 14 52 53z"/><path d="M96 99c-2-34 18-53 50-55 3 28-14 51-50 55z"/><path d="M76 149c-31 5-49-7-59-32 25-10 48 0 59 32z"/><path d="M111 74c3-27 21-40 47-39-1 25-18 42-47 39z"/></g></svg>|
    },
    %{
      slug: "illustration-mug",
      title_pt: "Caneca de café",
      tags_pt: "ilustração caneca café bebida pausa aconchego",
      type: "illustration",
      svg:
        ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 180 160"><path d="M35 45h92v78a17 17 0 0 1-17 17H52a17 17 0 0 1-17-17z" fill="#F2765B"/><path d="M127 62h14a23 23 0 0 1 0 46h-14" fill="none" stroke="#242424" stroke-width="10"/><path d="M53 25c-8-11 7-14 0-25M82 25c-8-11 7-14 0-25M111 25c-8-11 7-14 0-25" fill="none" stroke="#3859A8" stroke-linecap="round" stroke-width="5"/></svg>|
    },
    %{
      slug: "background-dots",
      title_pt: "Fundo de pontos",
      tags_pt: "fundo padrão pontos bolinhas textura repetição",
      type: "background",
      svg:
        ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 320 200"><rect width="320" height="200" fill="#F7F0E6"/><g fill="#F2765B"><circle cx="24" cy="24" r="5"/><circle cx="64" cy="24" r="5"/><circle cx="104" cy="24" r="5"/><circle cx="144" cy="24" r="5"/><circle cx="184" cy="24" r="5"/><circle cx="224" cy="24" r="5"/><circle cx="264" cy="24" r="5"/><circle cx="304" cy="24" r="5"/><circle cx="24" cy="64" r="5"/><circle cx="64" cy="64" r="5"/><circle cx="104" cy="64" r="5"/><circle cx="144" cy="64" r="5"/><circle cx="184" cy="64" r="5"/><circle cx="224" cy="64" r="5"/><circle cx="264" cy="64" r="5"/><circle cx="304" cy="64" r="5"/><circle cx="24" cy="104" r="5"/><circle cx="64" cy="104" r="5"/><circle cx="104" cy="104" r="5"/><circle cx="144" cy="104" r="5"/><circle cx="184" cy="104" r="5"/><circle cx="224" cy="104" r="5"/><circle cx="264" cy="104" r="5"/><circle cx="304" cy="104" r="5"/><circle cx="24" cy="144" r="5"/><circle cx="64" cy="144" r="5"/><circle cx="104" cy="144" r="5"/><circle cx="144" cy="144" r="5"/><circle cx="184" cy="144" r="5"/><circle cx="224" cy="144" r="5"/><circle cx="264" cy="144" r="5"/><circle cx="304" cy="144" r="5"/><circle cx="24" cy="184" r="5"/><circle cx="64" cy="184" r="5"/><circle cx="104" cy="184" r="5"/><circle cx="144" cy="184" r="5"/><circle cx="184" cy="184" r="5"/><circle cx="224" cy="184" r="5"/><circle cx="264" cy="184" r="5"/><circle cx="304" cy="184" r="5"/></g></svg>|
    },
    %{
      slug: "background-waves",
      title_pt: "Fundo de ondas",
      tags_pt: "fundo ondas curvas azul textura mar água",
      type: "background",
      svg:
        ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 320 200"><rect width="320" height="200" fill="#E8EDF7"/><path d="M0 54c42-29 78 29 120 0s78 29 120 0 62 0 80 0M0 102c42-29 78 29 120 0s78 29 120 0 62 0 80 0M0 150c42-29 78 29 120 0s78 29 120 0 62 0 80 0" fill="none" stroke="#3859A8" stroke-linecap="round" stroke-width="8"/></svg>|
    },
    %{
      slug: "background-color-blocks",
      title_pt: "Fundo de blocos de cor",
      tags_pt: "fundo geométrico blocos formas colorido composição",
      type: "background",
      svg:
        ~s|<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 320 200"><rect width="320" height="200" fill="#F7F0E6"/><path d="M0 0h111v86H0z" fill="#3859A8"/><path d="M111 0h209v42H111z" fill="#F2C14E"/><path d="M208 42h112v112H208z" fill="#F2765B"/><path d="M0 128h118v72H0z" fill="#B4C77A"/><circle cx="160" cy="122" r="36" fill="#E4A8B4"/></svg>|
    }
  ]

  @doc "Writes the SVG files and upserts all built-in records into the shared catalog."
  @spec seed!() :: %{String.t() => non_neg_integer()}
  def seed! do
    assets_dir = Application.app_dir(:tela, "priv/static/assets/catalog")
    File.mkdir_p!(assets_dir)

    Enum.each(@assets, fn asset ->
      File.write!(Path.join(assets_dir, asset.slug <> ".svg"), asset.svg)

      Repo.insert!(
        %Asset{
          slug: asset.slug,
          title_pt: asset.title_pt,
          tags_pt: asset.tags_pt,
          type: asset.type,
          file_path: "/assets/catalog/#{asset.slug}.svg"
        },
        on_conflict: {:replace, [:title_pt, :tags_pt, :type, :file_path]},
        conflict_target: :slug
      )
    end)

    @assets
    |> Enum.group_by(& &1.type)
    |> Map.new(fn {type, assets} -> {type, length(assets)} end)
  end
end
