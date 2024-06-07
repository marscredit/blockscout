FROM hexpm/elixir:1.14.5-erlang-24.2.2-alpine-3.18.2 AS builder

WORKDIR /app
ENV MIX_ENV="prod"

# Install necessary packages
RUN apk --no-cache --update add alpine-sdk gmp-dev automake libtool inotify-tools autoconf python3 file gcompat

RUN set -ex && \
    apk --update add libstdc++ curl ca-certificates gcompat

# Cache elixir deps
ADD mix.exs mix.lock ./
ADD apps/block_scout_web/mix.exs ./apps/block_scout_web/
ADD apps/explorer/mix.exs ./apps/explorer/
ADD apps/ethereum_jsonrpc/mix.exs ./apps/ethereum_jsonrpc/
ADD apps/indexer/mix.exs ./apps/indexer/

ENV MIX_HOME=/opt/mix
RUN mix local.hex --force
RUN mix do deps.get, local.rebar --force, deps.compile

# Add the remaining files
ADD apps ./apps
ADD config ./config
ADD rel ./rel
ADD *.exs ./

RUN apk add --update nodejs npm

# Run frontend build and phoenix digest
RUN mix compile && npm install npm@latest

# Add blockscout npm deps
RUN cd apps/block_scout_web/assets/ && \
    npm install && \
    npm run deploy && \
    cd /app/apps/explorer/ && \
    npm install && \
    apk update && \
    apk del --force-broken-world alpine-sdk gmp-dev automake libtool inotify-tools autoconf python3

RUN apk add --update git make

RUN mix phx.digest

RUN mkdir -p /opt/release \
    && mix release blockscout \
    && mv _build/${MIX_ENV}/rel/blockscout /opt/release

##############################################################
FROM hexpm/elixir:1.14.5-erlang-24.2.2-alpine-3.18.2

WORKDIR /app

# Copy the built release from the builder stage
COPY --from=builder /opt/release/blockscout .

# Ensure config_helper.exs is copied to the correct location
COPY --from=builder /app/config/config_helper.exs ./config/config_helper.exs
COPY --from=builder /app/config/config_helper.exs /app/releases/${RELEASE_VERSION}/config_helper.exs

# Ensure node_modules are copied
COPY --from=builder /app/apps/explorer/node_modules ./node_modules

CMD ["bin/blockscout", "start"]