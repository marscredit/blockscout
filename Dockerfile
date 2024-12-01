FROM elixir:1.13-alpine

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

# Expose Phoenix port
EXPOSE 4000

# Command to start the backend
CMD ["mix", "phx.server"]