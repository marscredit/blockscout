FROM hexpm/elixir:1.17.3-erlang-27.1-alpine-3.20.3

# Install dependencies
RUN apk add --no-cache \
    bash \
    git \
    # Essential for C compilation (includes gcc and related tools)
    build-base \  
    postgresql-client \
    nodejs \
    npm \
    openssl \
    curl \
    # Add libc development tools for C-based libraries
    libc-dev 

# Set environment variables
ENV MIX_ENV=prod \
    SECRET_KEY_BASE=${SECRET_KEY_BASE} \
    DATABASE_URL=${DATABASE_URL} \
    REDIS_URL=${REDIS_URL}

# Copy the app source code
WORKDIR /app
COPY . .

# Install Hex and Rebar
RUN mix local.hex --force && mix local.rebar --force

# Install dependencies and build
RUN mix deps.get && mix compile && mix phx.digest

# Install Node.js dependencies and build frontend assets
RUN npm install --prefix apps/block_scout_web/assets
RUN npm run deploy --prefix apps/block_scout_web/assets
RUN mix phx.digest

# Add database initialization script
COPY ./docker_entrypoint.sh /app/docker_entrypoint.sh
RUN chmod +x /app/docker_entrypoint.sh

# Expose Phoenix port
EXPOSE 443

# Start with the database setup script
ENTRYPOINT ["/app/docker_entrypoint.sh"]