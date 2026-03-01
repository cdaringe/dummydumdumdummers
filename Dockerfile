# Build stage: use Gleam's official Erlang/OTP image
FROM ghcr.io/gleam-lang/gleam:v1.13.0-erlang-alpine AS builder

WORKDIR /app

# Download dependencies
COPY manifest.toml gleam.toml ./
RUN gleam deps download

# Build Erlang release shipment
COPY src src
RUN gleam export erlang-shipment

# Runtime stage: minimal Erlang/OTP image
FROM erlang:27-alpine

# Install Docker CLI so --isolator docker can spawn containers via host socket
RUN apk add --no-cache docker-cli

WORKDIR /app

# Copy the self-contained Erlang release
COPY --from=builder /app/erlang-shipment .

ENTRYPOINT ["./entrypoint.sh", "run", "thingfactory", "main"]
