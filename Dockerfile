ARG TARGETPLATFORM

FROM --platform=$TARGETPLATFORM hexpm/elixir:1.20.5-erlang-29.1.2-alpine-3.24.4 AS build

RUN apk add --no-cache build-base cairo-dev git giflib-dev jpeg-dev nodejs npm pango-dev pkgconf python3 sqlite-dev

WORKDIR /app

ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
COPY config config

RUN mix deps.get --only prod && mix deps.compile

COPY frontend/package.json frontend/package-lock.json ./frontend/

RUN npm ci --prefix frontend

COPY frontend frontend
COPY lib lib
COPY priv priv

RUN mix compile
RUN mix assets.deploy
RUN mix release

FROM --platform=$TARGETPLATFORM alpine:3.24.4 AS runtime

RUN apk add --no-cache ca-certificates gcompat libstdc++ lksctp-tools ncurses-libs openssl sqlite-libs \
    && adduser -D -H -s /sbin/nologin tela \
    && mkdir -p /data/uploads \
    && chown -R tela:tela /data

WORKDIR /app

COPY --from=build --chown=tela:tela /app/_build/prod/rel/tela/ /app/
COPY --chown=tela:tela docker/entrypoint.sh /app/docker/entrypoint.sh
COPY --chown=tela:tela docker/healthcheck.sh /app/docker/healthcheck.sh

RUN chmod 755 /app/docker/entrypoint.sh /app/docker/healthcheck.sh

ENV PHX_SERVER=true \
    PHX_HOST=tela.zeetech.io \
    DATABASE_PATH=/data/tela.db \
    UPLOADS_DIR=/data/uploads \
    PORT=4000

VOLUME /data
EXPOSE 4000

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD ["/app/docker/healthcheck.sh"]

USER tela:tela

ENTRYPOINT ["/app/docker/entrypoint.sh"]
