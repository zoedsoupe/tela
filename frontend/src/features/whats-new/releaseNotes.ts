export interface ReleaseSection {
  title: string
  items: string[]
}

/** Update the version and content together when a release has user-facing changes worth announcing. */
export const RELEASE_NOTES = {
  version: '2026.11',
  title: 'Mais controle para criar',
  description: 'Esta versão traz ajustes para editar com mais precisão e exportar com menos etapas.',
  sections: [
    {
      title: 'Edição',
      items: [
        'Guias inteligentes mostram distâncias e tamanhos iguais enquanto você move e redimensiona objetos.',
        'Objetos e pontas de linha continuam acompanhando o cursor mesmo fora da página.',
        'Segure Shift para restringir linhas a 45° e transformar retângulos e elipses em formas perfeitas.',
        'Personalize o espaçamento da grade e inverta a orientação da página com um clique.',
      ],
    },
    {
      title: 'Cores e exportação',
      items: [
        'Salve a cor atual diretamente no Brand Kit e reencontre suas cores recentes no seletor.',
        'Escolha as páginas do download com uma prévia sincronizada e valide o intervalo antes de exportar.',
        'Exporte PDFs multipágina com o tipo de arquivo correto.',
        'Exclua objetos dentro de grupos e use o menu de contexto sem interromper a edição.',
      ],
    },
  ] satisfies ReleaseSection[],
} as const

export const RELEASE_NOTES_STORAGE_KEY = 'tela.whatsNew.version'
