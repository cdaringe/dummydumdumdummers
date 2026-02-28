# Build stage
FROM node:22-alpine AS builder

# Install Gleam
RUN npm install -g gleam@1.13.0

WORKDIR /app

# Copy manifest and build dependencies
COPY manifest.toml gleam.toml ./
RUN gleam deps download

# Copy source code
COPY src src
COPY test test

# Build JavaScript target
RUN gleam build --target javascript

# Runtime stage
FROM node:22-alpine

WORKDIR /app

# Copy only the compiled JavaScript from builder
COPY --from=builder /app/build/dev /app/build/dev

# Copy CLI entry point
COPY bin bin

ENTRYPOINT ["node", "bin/cli.mjs"]
