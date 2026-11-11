defmodule TelaWeb.StyleguideLive do
  @moduledoc "Development reference for Tela's semantic tokens and shared components."
  use TelaWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, current_scope: nil, page_title: "Sistema visual")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-12">
        <.header>
          Sistema visual
          <:subtitle>Fundamentos e componentes do espaço de criação Tela.</:subtitle>
          <:actions>
            <.badge variant={:accent}>Base da interface</.badge>
          </:actions>
        </.header>

        <section aria-labelledby="tokens-heading" class="space-y-5">
          <div>
            <h2 id="tokens-heading" class="font-display text-2xl">Fundamentos semânticos</h2>
            <p class="mt-1 text-sm text-muted">
              A interface usa papéis de cor, não valores da paleta diretamente.
            </p>
          </div>
          <div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
            <div
              :for={{label, class} <- token_samples()}
              class="flex items-center gap-3 rounded-lg border border-line bg-surface p-3"
            >
              <span
                class={["size-10 shrink-0 rounded-md border border-line", class]}
                aria-hidden="true"
              />
              <span class="text-sm font-medium">{label}</span>
            </div>
          </div>
          <div class="grid gap-4 rounded-lg border border-line bg-surface p-5 sm:grid-cols-3">
            <div>
              <p class="text-xs uppercase tracking-wider text-muted">Interface</p>
              <p class="mt-2 font-sans text-lg">DM Sans · leitura clara</p>
            </div>
            <div>
              <p class="text-xs uppercase tracking-wider text-muted">Editorial</p>
              <p class="mt-2 font-display text-2xl">Instrument Serif</p>
            </div>
            <div>
              <p class="text-xs uppercase tracking-wider text-muted">Ritmo</p>
              <p class="mt-2 text-sm text-muted">
                Bordas visíveis, raios moderados e transições curtas.
              </p>
            </div>
          </div>
        </section>

        <section aria-labelledby="actions-heading" class="space-y-5">
          <h2 id="actions-heading" class="font-display text-2xl">Ações</h2>
          <div class="flex flex-wrap items-center gap-3">
            <.button variant={:primary}>Criar projeto</.button>
            <.button variant={:secondary}>Duplicar</.button>
            <.button variant={:outline}>Pré-visualizar</.button>
            <.button variant={:ghost}>Cancelar</.button>
            <.button variant={:danger}>Excluir</.button>
            <.button loading>Salvando</.button>
            <.icon_button label="Adicionar página">
              <:icon><Lucideicons.plus class="size-4" /></:icon>
            </.icon_button>
            <.button_group label="Histórico">
              <.button variant={:outline} size={:sm}><Lucideicons.undo_2 class="size-4" />Desfazer</.button>
              <.button variant={:outline} size={:sm}><Lucideicons.redo_2 class="size-4" />Refazer</.button>
            </.button_group>
          </div>
        </section>

        <section aria-labelledby="forms-heading" class="space-y-5">
          <h2 id="forms-heading" class="font-display text-2xl">Formulários</h2>
          <div class="grid gap-6 rounded-lg border border-line bg-surface p-5 md:grid-cols-2">
            <.input
              id="styleguide-title"
              name="title"
              label="Nome do projeto"
              value="Convite de lançamento"
              hint="Um nome curto ajuda a encontrar seu projeto."
            />
            <.input
              id="styleguide-format"
              name="format"
              type="select"
              label="Formato"
              prompt="Escolha um formato"
              options={[{"Post quadrado", "square"}, {"Story vertical", "story"}]}
            />
            <.input
              id="styleguide-notes"
              name="notes"
              type="textarea"
              label="Observações"
              placeholder="Anote uma ideia para este projeto"
            />
            <div class="space-y-5">
              <.input
                id="styleguide-checkbox"
                name="template"
                type="checkbox"
                label="Salvar como modelo"
                checked
              />
              <.input
                id="styleguide-radio"
                name="quality"
                type="radio"
                label="Qualidade padrão"
                value="standard"
                checked
              />
              <.input
                id="styleguide-switch"
                name="brand"
                type="switch"
                label="Usar identidade visual"
                checked
              />
              <.input
                id="styleguide-invalid"
                name="invalid"
                label="Campo com erro"
                errors={["Informe um título para continuar."]}
              />
            </div>
          </div>
        </section>

        <section aria-labelledby="feedback-heading" class="space-y-5">
          <h2 id="feedback-heading" class="font-display text-2xl">Feedback e estados</h2>
          <div class="grid gap-4 md:grid-cols-2">
            <.alert variant={:info} title="Dica">
              Use os formatos para começar com as dimensões certas.
            </.alert>
            <.alert variant={:success} title="Tudo em ordem">
              Suas alterações foram salvas neste navegador.
            </.alert>
            <.alert variant={:warning} title="Atenção">
              Este arquivo está ficando maior que o esperado.
            </.alert>
            <.alert variant={:danger} title="Não foi possível salvar">
              Verifique sua conexão e tente novamente.
            </.alert>
          </div>
          <div class="flex flex-wrap items-center gap-3">
            <.badge>Rascunho</.badge>
            <.badge variant={:accent}>Novo</.badge>
            <.badge variant={:success}>Salvo</.badge>
            <.badge variant={:warning}>Pendente</.badge>
            <.badge variant={:danger}>Falhou</.badge>
            <.spinner label="Carregando biblioteca" />
            <.save_status status={:saved} />
            <.save_status status={:saving} />
            <.save_status status={:dirty} />
            <.save_status status={:error} />
          </div>
          <div class="max-w-lg space-y-4 rounded-lg border border-line bg-surface p-5">
            <.progress value={68} label="Envio de imagens" />
            <div class="space-y-2" aria-hidden="true">
              <.skeleton class="h-4 w-2/3" />
              <.skeleton class="h-28 w-full" />
            </div>
          </div>
          <.empty_state title="Nenhum projeto por aqui">
            Crie seu primeiro projeto para começar a organizar suas peças.
            <:action><.button>Começar um projeto</.button></:action>
          </.empty_state>
        </section>

        <section aria-labelledby="navigation-heading" class="space-y-5">
          <h2 id="navigation-heading" class="font-display text-2xl">Navegação</h2>
          <.tabs label="Seções do sistema">
            <:tab label="Projetos" href="/" selected />
            <:tab label="Modelos" href="/" />
            <:tab label="Identidade visual" href="/" />
          </.tabs>
          <.breadcrumbs>
            <:item href="/">Projetos</:item>
            <:item href="/">Campanha de verão</:item>
            <:item current>Capa para redes</:item>
          </.breadcrumbs>
          <div class="flex flex-wrap items-center gap-4">
            <.nav_item href="/" current><Lucideicons.folder_open class="size-4" />Projetos</.nav_item>
            <.segmented_control label="Prévia" selected="grid" on_select="select-view">
              <:option value="grid">Grade</:option>
              <:option value="list">Lista</:option>
            </.segmented_control>
          </div>
        </section>

        <section aria-labelledby="data-heading" class="space-y-5">
          <h2 id="data-heading" class="font-display text-2xl">Dados e mídia</h2>
          <div class="grid gap-8 lg:grid-cols-[1.5fr_1fr]">
            <.table
              id="styleguide-designs"
              rows={[
                %{title: "Capa da campanha", status: "Editado hoje"},
                %{title: "Convite de abertura", status: "Editado ontem"}
              ]}
            >
              <:col :let={design} label="Projeto">{design.title}</:col>
              <:col :let={design} label="Atualização">{design.status}</:col>
              <:action :let={_design}>
                <button
                  type="button"
                  class="rounded px-2 py-1 text-sm text-muted hover:bg-surface-secondary"
                >Abrir</button>
              </:action>
            </.table>
            <.description_list>
              <:item title="Formato">Publicação quadrada · 1080 × 1080</:item>
              <:item title="Páginas">3 páginas</:item>
              <:item title="Identidade">Atelier Verão</:item>
            </.description_list>
          </div>
          <.asset_grid columns={:three}>
            <div
              :for={
                {label, class} <- [
                  {"Papel", "bg-page"},
                  {"Seleção", "bg-selection"},
                  {"Acento", "bg-accent-soft"}
                ]
              }
              class="overflow-hidden rounded-lg border border-line bg-surface"
            >
              <.aspect_ratio ratio="4 / 3" class="grid place-items-center">
                <span class={["size-16 rounded-full border border-line", class]} />
              </.aspect_ratio>
              <p class="border-t border-line px-3 py-2 text-sm">{label}</p>
            </div>
          </.asset_grid>
          <.thumbnail
            src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 320 240'%3E%3Crect width='320' height='240' fill='currentColor' fill-opacity='.08'/%3E%3Ccircle cx='160' cy='120' r='56' fill='currentColor' fill-opacity='.24'/%3E%3C/svg%3E"
            alt="Prévia abstrata de uma composição"
            class="max-w-48"
          />
        </section>

        <section aria-labelledby="overlays-heading" class="space-y-5">
          <h2 id="overlays-heading" class="font-display text-2xl">Sobreposições</h2>
          <div class="flex flex-wrap items-center gap-4">
            <.dropdown id="styleguide-dropdown" label="Ações do projeto">
              <:trigger>
                <span class="inline-flex min-h-10 items-center gap-2 rounded-md border border-line bg-surface px-4 text-sm font-semibold">Ações
                <Lucideicons.chevron_down class="size-4" /></span>
              </:trigger>
              <a href="/" class="block rounded px-3 py-2 text-sm hover:bg-surface-secondary">Duplicar projeto</a>
              <a href="/" class="block rounded px-3 py-2 text-sm hover:bg-surface-secondary">Mover para pasta</a>
            </.dropdown>
            <.menu id="styleguide-menu" label="Mais opções">
              <:trigger>
                <span class="inline-flex size-10 items-center justify-center rounded-md border border-line"><Lucideicons.ellipsis class="size-4" /></span>
              </:trigger>
              <a
                href="/"
                class="block rounded px-3 py-2 text-sm hover:bg-surface-secondary"
              >Renomear</a>
              <a
                href="/"
                class="block rounded px-3 py-2 text-sm hover:bg-surface-secondary"
              >Duplicar</a>
            </.menu>
            <.popover id="styleguide-popover" label="Informações do formato">
              <:trigger>
                <span class="inline-flex min-h-10 items-center rounded-md px-4 text-sm font-semibold">Sobre formatos</span>
              </:trigger>
              <p class="text-sm text-muted">Você pode alterar o formato antes de começar a editar.</p>
            </.popover>
            <.tooltip label="Desfazer a última alteração">
              <.icon_button label="Desfazer"><:icon><Lucideicons.undo_2 class="size-4" /></:icon></.icon_button>
            </.tooltip>
            <.pagination current={2} total={6} page_path={&"/?page=#{&1}"} />
          </div>
          <.dialog id="styleguide-dialog" labelledby="styleguide-dialog-title">
            <:title>Remover projeto</:title>
            <:description>Esta ação não pode ser desfeita.</:description>
            <:actions>
              <.button variant={:outline} formmethod="dialog">Cancelar</.button>
              <.button variant={:danger} formmethod="dialog">Remover</.button>
            </:actions>
            Confirme antes de remover este projeto.
          </.dialog>
          <.drawer id="styleguide-drawer" labelledby="styleguide-drawer-title">
            <:title>Detalhes do projeto</:title>
            <:actions><.button variant={:outline} formmethod="dialog">Fechar</.button></:actions>
            Informações adicionais aparecem neste painel lateral.
          </.drawer>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp token_samples do
    [
      {"Página", "bg-page"},
      {"Superfície", "bg-surface"},
      {"Superfície secundária", "bg-surface-secondary"},
      {"Área de trabalho", "bg-workspace"},
      {"Tinta", "bg-ink"},
      {"Ação", "bg-accent"},
      {"Foco e seleção", "bg-focus"},
      {"Sucesso", "bg-success"},
      {"Atenção", "bg-warning"},
      {"Perigo", "bg-danger"}
    ]
  end
end
