# Tela

Tela é um editor gráfico auto-hospedado para um espaço de trabalho pessoal e confiável. Usa React e Fabric.js no frontend, uma API JSON em Phoenix, SQLite e arquivos locais. Os perfis locais identificam autoria; não funcionam como autenticação nem definem propriedade dos projetos.

## Executar localmente

Requisitos: Elixir/OTP, Node.js 22 ou mais recente e SQLite.

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

## Provedores externos opcionais de imagens

Os catálogos incluídos e o Wikimedia Commons não precisam de chave de API. Pexels e Pixabay podem ser configurados independentemente:

```sh
export PEXELS_API_KEY="..."
export PIXABAY_API_KEY="..."
```

As URLs importadas passam por allowlists de hosts dos provedores, têm a assinatura da imagem validada e ficam em cache na biblioteca compartilhada de uploads.

## Atribuição

O editor incorpora componentes e assets do Doory. Consulte `NOTICE` e `licenses/` para os textos obrigatórios de atribuição e licença. Os templates incluídos e a biblioteca de áudio CC0 mantêm seus próprios avisos em `priv/content/`.
