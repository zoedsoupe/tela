import type { PresetTree } from "./catalogue"

/**
 * The built-in size presets, offered until (or if) `/size-presets/` cannot be loaded. The part of
 * `backend/data/size_presets.json` the app needs before then: the sizes it used to hard-code, which links,
 * designs and templates name. The server's catalogue adds the rest; a test keeps the rows equal.
 */
export const BUILTIN_PRESET_TREE: PresetTree = {
  version: 1,
  groups: [
    {
      slug: 'presentation',
      label: "Apresentações",
      icon: 'presentation',
      children: [
        {
          slug: 'presentation-screen-slides',
          label: "Slides de tela",
          presets: [
            {
              slug: 'presentation',
              label: "Apresentação (16:9)",
              width: 1920,
              height: 1080,
              unit: 'px',
              icon: 'presentation',
              tags: ['16:9'],
              is_quick: true,
            },
            {
              slug: 'presentation-4-3',
              label: "Apresentação (4:3)",
              width: 1024,
              height: 768,
              unit: 'px',
              icon: 'presentation',
              tags: ['4:3'],
            },
          ],
        },
      ],
    },
    {
      slug: 'print',
      label: "Imprimir",
      icon: 'printer',
      children: [
        {
          slug: 'paper',
          label: "Papel",
          children: [
            {
              slug: 'paper-iso-paper-a-b',
              label: "Papel ISO (A e B)",
              presets: [
                {
                  slug: 'a4',
                  label: "Documento A4",
                  width: 210,
                  height: 297,
                  unit: 'mm',
                  icon: 'file-text',
                  is_quick: true,
                  tags: ['1:1.414'],
                  meta: {
                    bleed: "3mm",
                  },
                },
                {
                  slug: 'a5',
                  label: 'A5',
                  width: 148,
                  height: 210,
                  unit: 'mm',
                  icon: 'file-text',
                  tags: ['1:1.414'],
                  meta: {
                    bleed: "3mm",
                  },
                },
                {
                  slug: 'a3',
                  label: 'A3',
                  width: 297,
                  height: 420,
                  unit: 'mm',
                  icon: 'file-text',
                  tags: ['1:1.414'],
                  meta: {
                    bleed: "3mm",
                  },
                },
              ],
            },
            {
              slug: 'paper-north-american-paper',
              label: "jornal norte-americano",
              presets: [
                {
                  slug: 'letter',
                  label: "Carta dos EUA",
                  width: 8.5,
                  height: 11,
                  unit: 'in',
                  icon: 'file-text',
                  tags: ['1:1.294'],
                  meta: {
                    bleed: "0,125 pol.",
                  },
                },
              ],
            },
          ],
        },
        {
          slug: 'cards',
          label: "Cartões e papelaria",
          children: [
            {
              slug: 'cards-business-cards',
              label: "Cartões de visita",
              presets: [
                {
                  slug: 'business-card',
                  label: "Cartão de visita (3,5 × 2 pol.)",
                  width: 3.5,
                  height: 2,
                  unit: 'in',
                  icon: 'credit-card',
                  tags: ['1.75:1'],
                  meta: {
                    bleed: "0,125 pol.",
                  },
                },
              ],
            },
            {
              slug: 'cards-postcards-and-flat-cards',
              label: "Cartões postais e cartões planos",
              presets: [
                {
                  slug: 'postcard',
                  label: "Cartão postal (6 × 4 pol.)",
                  width: 6,
                  height: 4,
                  unit: 'in',
                  icon: 'mail',
                  tags: ['3:2'],
                  meta: {
                    bleed: "0,125 pol.",
                  },
                },
              ],
            },
            {
              slug: 'cards-greeting-cards-invitations-and-thank-you',
              label: "Cartões de felicitações, convites e cartões de agradecimento",
              presets: [
                {
                  slug: 'greeting-card',
                  label: "Cartão de felicitações (4,25 × 5,5 pol.)",
                  width: 4.25,
                  height: 5.5,
                  unit: 'in',
                  icon: 'mail',
                  tags: ['1:1.294'],
                  meta: {
                    bleed: "0,125 pol.",
                  },
                },
                {
                  slug: 'invitation',
                  label: "Convite (5 × 7 pol.)",
                  width: 5,
                  height: 7,
                  unit: 'in',
                  icon: 'party-popper',
                  tags: ['1:1.4'],
                  meta: {
                    bleed: "0,125 pol.",
                  },
                },
              ],
            },
          ],
        },
        {
          slug: 'posters-flyers',
          label: "Folhetos, cartazes e banners",
          children: [
            {
              slug: 'posters-flyers-and-leaflets',
              label: "Folhetos e folhetos",
              presets: [
                {
                  slug: 'flyer',
                  label: "Folheto (5,5 × 8,5 pol.)",
                  width: 5.5,
                  height: 8.5,
                  unit: 'in',
                  icon: 'newspaper',
                  tags: ['1:1.545'],
                  meta: {
                    bleed: "0,125 pol.",
                  },
                },
              ],
            },
            {
              slug: 'posters-brochures-and-menus',
              label: "Folhetos e menus",
              presets: [
                {
                  slug: 'brochure',
                  label: "Folheto (11 × 8,5 pol.)",
                  width: 11,
                  height: 8.5,
                  unit: 'in',
                  icon: 'newspaper',
                  tags: ['1.294:1'],
                  meta: {
                    bleed: "0,125 pol.",
                  },
                },
              ],
            },
            {
              slug: 'posters-posters',
              label: "Cartazes",
              presets: [
                {
                  slug: 'poster',
                  label: "Pôster (18 × 24 pol.)",
                  width: 18,
                  height: 24,
                  unit: 'in',
                  icon: 'printer',
                  tags: ['3:4'],
                  is_quick: true,
                  meta: {
                    bleed: "0,125 pol.",
                  },
                },
              ],
            },
          ],
        },
      ],
    },
    {
      slug: 'documents',
      label: "Documentos",
      icon: 'file-text',
      children: [
        {
          slug: 'documents-letters-resumes-business-docs',
          label: "Cartas, currículos e documentos comerciais",
          presets: [
            {
              slug: 'letterhead',
              label: "Papel timbrado",
              width: 8.5,
              height: 11,
              unit: 'in',
              icon: 'file-text',
            },
            {
              slug: 'resume',
              label: "Currículo",
              width: 210,
              height: 297,
              unit: 'mm',
              icon: 'briefcase',
              tags: ['1:1.414'],
            },
          ],
        },
      ],
    },
    {
      slug: 'video',
      label: "Vídeo e telas",
      icon: 'monitor',
      children: [
        {
          slug: 'screens-video',
          label: "Vídeo",
          presets: [
            {
              slug: 'video-1080p',
              label: "Vídeo (1080p)",
              width: 1920,
              height: 1080,
              unit: 'px',
              icon: 'monitor',
              tags: ['16:9'],
            },
            {
              slug: 'video-4k',
              label: "Vídeo (4K)",
              width: 3840,
              height: 2160,
              unit: 'px',
              icon: 'monitor',
              tags: ['16:9'],
            },
          ],
        },
      ],
    },
    {
      slug: 'web',
      label: "Web e e-mail",
      icon: 'globe',
      presets: [
        {
          slug: 'web-banner',
          label: "Banner da Web (728 × 90)",
          width: 728,
          height: 90,
          unit: 'px',
          icon: 'rectangle-horizontal',
        },
      ],
    },
    {
      slug: 'etc',
      label: "Logotipos e ícones",
      icon: 'badge',
      children: [
        {
          slug: 'logos-logo-canvases',
          label: "Telas de logotipo",
          presets: [
            {
              slug: 'logo',
              label: "Logotipo (512 × 512)",
              width: 512,
              height: 512,
              unit: 'px',
              icon: 'square',
              tags: ['1:1'],
              is_quick: true,
            },
          ],
        },
      ],
    },
    {
      slug: 'social',
      label: "Redes sociais",
      icon: 'share-2',
      children: [
        {
          slug: 'facebook',
          label: "Facebook",
          presets: [
            {
              slug: 'facebook-post',
              label: "Postagem no Facebook",
              width: 1200,
              height: 630,
              unit: 'px',
              icon: 'rectangle-horizontal',
              tags: ['1.91:1'],
            },
            {
              slug: 'facebook-cover',
              label: "Capa do Facebook",
              width: 1640,
              height: 924,
              unit: 'px',
              icon: 'image',
              tags: ['16:9'],
            },
          ],
        },
        {
          slug: 'instagram',
          label: "Instagram",
          presets: [
            {
              slug: 'instagram-portrait',
              label: "Postagem de retrato no Instagram",
              width: 1080,
              height: 1350,
              unit: 'px',
              icon: 'rectangle-vertical',
              tags: ['4:5'],
            },
            {
              slug: 'instagram-post',
              label: "Postagem no Instagram",
              width: 1080,
              height: 1080,
              unit: 'px',
              icon: 'square',
              tags: ['1:1'],
              is_quick: true,
            },
            {
              slug: 'instagram-story',
              label: "História do Instagram",
              width: 1080,
              height: 1920,
              unit: 'px',
              icon: 'clapperboard',
              tags: ['9:16'],
              is_quick: true,
              meta: {
                safe_zone: {
                  top: 0.14,
                  bottom: 0.35,
                  left: 0.06,
                  right: 0.06,
                },
              },
            },
            {
              slug: 'instagram-reel',
              label: "Carretel do Instagram",
              width: 1080,
              height: 1920,
              unit: 'px',
              icon: 'clapperboard',
              tags: ['9:16'],
            },
          ],
        },
        {
          slug: 'linkedin',
          label: "LinkedIn",
          presets: [
            {
              slug: 'linkedin-post',
              label: "Postagem no LinkedIn",
              width: 1200,
              height: 627,
              unit: 'px',
              icon: 'rectangle-horizontal',
              tags: ['1.91:1'],
            },
            {
              slug: 'linkedin-banner',
              label: "Banner do LinkedIn",
              width: 1584,
              height: 396,
              unit: 'px',
              icon: 'image',
              tags: ['4:1'],
            },
          ],
        },
        {
          slug: 'pinterest',
          label: "Pinterest",
          presets: [
            {
              slug: 'pinterest-pin',
              label: "Pin do Pinterest",
              width: 1000,
              height: 1500,
              unit: 'px',
              icon: 'rectangle-vertical',
              tags: ['2:3'],
            },
          ],
        },
        {
          slug: 'tiktok',
          label: "TikTok",
          presets: [
            {
              slug: 'tiktok-video',
              label: "Vídeo TikTok",
              width: 1080,
              height: 1920,
              unit: 'px',
              icon: 'clapperboard',
              tags: ['9:16'],
              meta: {
                safe_zone: {
                  top: 0.13,
                  bottom: 0.34,
                  left: 0.11,
                  right: 0.28,
                },
              },
            },
          ],
        },
        {
          slug: 'x',
          label: 'X',
          presets: [
            {
              slug: 'x-post',
              label: "Postagem X (Twitter)",
              width: 1200,
              height: 675,
              unit: 'px',
              icon: 'rectangle-horizontal',
              tags: ['16:9'],
              aliases: ['twitter-post'],
            },
            {
              slug: 'x-header',
              label: "Cabeçalho X (Twitter)",
              width: 1500,
              height: 500,
              unit: 'px',
              icon: 'image',
              tags: ['3:1'],
            },
          ],
        },
        {
          slug: 'youtube',
          label: "YouTube",
          presets: [
            {
              slug: 'youtube-thumbnail',
              label: "Miniatura do YouTube",
              width: 1280,
              height: 720,
              unit: 'px',
              icon: 'clapperboard',
              tags: ['16:9'],
              is_quick: true,
            },
            {
              slug: 'youtube-banner',
              label: "Banner do YouTube",
              width: 2560,
              height: 1440,
              unit: 'px',
              icon: 'image',
              tags: ['16:9'],
              meta: {
                safe_zone: {
                  top: 0.353,
                  bottom: 0.353,
                  left: 0.198,
                  right: 0.198,
                },
              },
            },
          ],
        },
      ],
    },
  ],
}
