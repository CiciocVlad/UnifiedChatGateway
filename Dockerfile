# syntax=docker/dockerfile:experimental
FROM registry.premiercontactpoint.dev/pcp_build as build

WORKDIR /opt/unified-chat-gateway/

COPY . .
RUN mix local.hex 1.0.1 --force
RUN mix local.rebar --force
RUN apk update && apk upgrade && \
    apk add nodejs \
    npm
RUN npm install

RUN --mount=type=ssh mix deps.get
RUN mix assets.deploy
RUN --mount=type=ssh  MIX_ENV=prod mix distillery.release

FROM registry.premiercontactpoint.dev/pcp_release
WORKDIR /opt/unified-chat-gateway/
COPY --from=build /opt/unified-chat-gateway/_build/prod/rel/unified-chat-gateway/ .
RUN \
  mkdir -p /opt/unified-chat-gateway/lib/live-0.1.0/priv/static/uploads
ENTRYPOINT ["/opt/unified-chat-gateway/bin/unified-chat-gateway", "console"]
