# Tela

Tela é um editor gráfico auto-hospedado para um espaço de trabalho pessoal e confiável. Usa React e Fabric.js no frontend, uma API JSON em Phoenix, SQLite e arquivos locais. Os perfis locais identificam autoria; não funcionam como autenticação nem definem propriedade dos projetos.

## Executar localmente

Requisitos: Elixir/OTP, Node.js 22 (a partir da 22.22.2), 24 (a partir da 24.15.0) ou 26+, e SQLite.

```sh
mix setup
mix phx.server
```

Abra [localhost:4000](http://localhost:4000). O `mix setup` instala as dependências dos dois bundles, executa as migrações e popula os catálogos de elementos, fontes e templates. O Node.js é necessário para compilar o frontend, não como um segundo serviço em execução.

## Dados e armazenamento

Designs, pastas, versões, comentários, links de compartilhamento, perfis, Brand Kits e registros de mídia ficam no SQLite. Os uploads ficam fora de `priv/static`, no diretório `./uploads` por padrão. Em produção, configure `UPLOADS_DIR` com um caminho absoluto persistente. Inclua o banco SQLite e esse diretório nos backups.

Links de compartilhamento permitem visualizar, comentar ou editar, com expiração de 1, 7 ou 30 dias, ou sem expiração. Novos links expiram em 7 dias por padrão. Links de edição também podem listar, criar e restaurar versões pelo próprio token. Visitantes que comentam informam apenas um nome de exibição, guardado localmente no navegador e por link; nenhum perfil do espaço de trabalho é usado. Resolver, mover e excluir comentários continua restrito ao espaço de trabalho. O espaço de trabalho não tem contas, autenticação ou verificação de propriedade: exponha o servidor somente em uma rede confiável.

## Recursos do navegador

O processamento de imagens, áudio e vídeo acontece no navegador e em arquivos locais. A biblioteca de áudio incluída usa Ogg Opus e aparece somente em navegadores compatíveis. Tela não faz transcodificação, não executa workers de exportação e não exige FFmpeg ou Chromium.

## CI e publicação da imagem

Pull requests e pushes na `main` executam os testes do Phoenix e do frontend e constroem a imagem para `linux/amd64` e `linux/arm64`, sem publicá-la.

Para publicar uma versão, crie e envie uma tag Git:

```sh
git tag v0.1.0
git push origin v0.1.0
```

A CI publica no GHCR `ghcr.io/zoedsoupe/tela` as tags imutáveis `0.1.0`, `v0.1.0` e `sha-<commit>`, sem `latest`. Use uma dessas referências em `services.beam.containers.tela.image` no yby. O Phoenix usa `PORT=4013` no host e o Cloudflare já encaminha `tela.zeetech.io` para essa porta.

## Verificações

```sh
mix precommit
npm --prefix frontend run typecheck
npm --prefix frontend run lint
npm --prefix frontend test
npm --prefix frontend run build
mix assets.deploy
```

O `mix assets.deploy` compila a aplicação React, copia `frontend/dist` para `priv/static` e executa o `phx.digest`.

## Catálogo ampliado de elementos

Tela inclui 16 elementos locais no setup inicial. Para baixar os 17 pacotes adicionais de ícones, emoji e ilustrações (aproximadamente 27,5 mil elementos no total), execute uma vez:

```sh
mix tela.sync_elements
```

O comando é idempotente, não precisa de chave de API e não faz parte do `mix setup`. Pacotes já sincronizados são ignorados; uma execução interrompida pode ser repetida para continuar. Use `mix tela.sync_elements --list` para listar os pacotes e `--pack ID` uma ou mais vezes para sincronizar apenas alguns:

```sh
mix tela.sync_elements --pack lucide --pack noto-emoji
```

Em uma release, após as migrações, use:

```sh
bin/tela eval 'Tela.Release.sync_elements()'
```

Os SVGs, metadados de atribuição e licenças ficam no SQLite. As versões e hashes das fontes estão fixados em `priv/content/element_packs.json`; logos de marcas ficam excluídos.

## Provedores externos opcionais de imagens

Os catálogos incluídos e o Wikimedia Commons não precisam de chave de API. Pexels, Pixabay e Unsplash podem ser configurados independentemente:

```sh
export PEXELS_API_KEY="..."
export PIXABAY_API_KEY="..."
export UNSPLASH_ACCESS_KEY="..."
```

A opção `Todas` pesquisa o Wikimedia Commons e cada provedor configurado, sem exigir todas as chaves. As respostas de pesquisa e resolução do Pixabay ficam no SQLite por 24 horas, conforme exigido pela API. As URLs importadas do Pexels, Pixabay e Wikimedia passam por allowlists de hosts, têm a assinatura da imagem validada e ficam em cache na biblioteca compartilhada de uploads.

Imagens do Unsplash permanecem nos URLs hotlinkados exigidos pela API. Ao escolher uma foto, Tela registra o download na API e preserva os links de atribuição da pessoa fotógrafa e do Unsplash; nenhuma cópia local é criada.

## Atribuição

O editor incorpora componentes e assets do Doory. Consulte `NOTICE` e `licenses/` para os textos obrigatórios de atribuição e licença. Os templates incluídos e a biblioteca de áudio CC0 mantêm seus próprios avisos em `priv/content/`.
