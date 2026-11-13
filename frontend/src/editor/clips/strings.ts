/** Portuguese strings for local video clips and browser exports. */

const plural = (n: number, one: string, many: string): string => (n === 1 ? one : many)

/** `0:07`, `1:30`, `12:04`: a clip's length on its badge. */
export function formatClipTime(ms: number): string {
  const total = Math.max(0, Math.round(ms / 1000))
  const minutes = Math.floor(total / 60)
  return `${minutes}:${String(total % 60).padStart(2, '0')}`
}

export const clipStrings = {
  tool: "Vídeos",
  uploads: {
    zone: "Adicionar vídeo",
    browserOnly: "O navegador verifica a reprodução antes de salvar o arquivo original.",
    yours: "Seus vídeos",
    none: "Nenhum vídeo adicionado.",
    loading: "Carregando vídeos…",
    uploading: (name: string, percent: number) => `Salvando ${name}… ${percent}%`,
    notVideo: (name: string) => `${name} não é um vídeo.`,
    uploadFailed: (name: string) => `Não foi possível salvar ${name}.`,
    remove: (name: string) => `Excluir ${name}`,
    removeFailed: "Não foi possível excluir o vídeo.",
    listFailed: "Não foi possível carregar os vídeos locais.",
    loadMore: "Carregar mais",
    add: (name: string) => `Adicionar ${name}`,
  },
  toolbar: {
    play: "Reproduzir",
    pause: "Pausar",
    mute: "Silenciar",
    unmute: "Ativar som",
    silent: "Este vídeo está sem som",
    loop: "Repetir",
    volume: "Volume",
    speed: "Velocidade",
    speedValue: (speed: number) => `${speed}×`,
    speedMutes: "Nesta velocidade, o vídeo é reproduzido sem som.",
    trim: "Gravar",
    trimTitle: "Gravar vídeo",
    trimStart: "Início do recorte",
    trimEnd: "Fim do recorte",
    trimRange: (from: string, to: string, length: string) => `${from} a ${to} (${length})`,
    startAt: "Começa em",
    fadeIn: "Aparecimento gradual",
    fadeOut: "Desaparecimento gradual",
    seconds: (s: number) => `${s} s`,
    section: "Vídeo",
    blurredBackground: "Fundo desfocado",
    blurredBackgroundHint: "Preencher a página com uma cópia desfocada do vídeo",
    hasBackdrop: "Este vídeo já tem um fundo desfocado.",
    backdropName: (name: string) => `${name} (fundo desfocado)`,
    replace: "Substituir vídeo",
    split: "Dividir no indicador de reprodução",
    splitHint: "Mova o indicador para o ponto em que deseja dividir o vídeo.",
  },
  replacing: {
    title: "Escolha um vídeo para substituir o selecionado",
    cancel: "Cancelar",
  },
  menu: {
    detachAudio: "Separar áudio",
    setAsBackground: "Usar vídeo como fundo",
    blurredBackground: "Adicionar fundo desfocado",
    replace: "Substituir vídeo",
    split: "Dividir vídeo",
  },
  timeline: {
    section: "Vídeos",
    row: (name: string) => `Vídeo ${name}`,
    bar: (name: string, from: string, to: string) => `${name}, reprodução de ${from} para ${to}`,
    moveHint: "Arraste para mover ou pelas bordas para recortar. As setas se movem em intervalos de 0,1 s.",
  },
  history: {
    add: "Adicionar vídeo",
    update: "Alterar vídeo",
    trim: "Gravar vídeo",
    move: "Mover vídeo",
    background: "Usar vídeo como fundo",
    detachAudio: "Separar áudio",
    fill: "Adicionar vídeo à moldura",
    backdrop: "Adicionar fundo desfocado",
    replace: "Substituir vídeo",
    split: "Dividir vídeo",
  },
  announce: {
    added: "Vídeo adicionado",
    detached: "O áudio do vídeo foi separado em uma faixa própria",
    count: (n: number) => `${n} ${plural(n, 'video', 'videos')}`,
  },
  kind: "Vídeo",
  time: formatClipTime,
} as const
