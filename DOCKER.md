# Docker Guide

Thingfactory ships with Docker support for both the CLI pipeline runner and the
web GUI.

## Table of Contents

- [Quick Start](#quick-start)
- [CLI Container](#cli-container)
- [Web GUI Container](#web-gui-container)
- [Docker Compose](#docker-compose)
- [Configuration](#configuration)
- [Self-Hosting](#self-hosting)

## Quick Start

### CLI Only

```bash
# Build the CLI image
docker build -t thingfactory .

# List available pipelines
docker run --rm thingfactory list

# Run a pipeline (local isolation — no Docker socket required)
docker run --rm thingfactory run thingfactory@examples:basic_pipeline --isolator local

# Run with compact output
docker run --rm thingfactory run thingfactory@examples:basic_pipeline --isolator local -c
```

### Full Stack (CLI + Web GUI)

```bash
# Start the web GUI (persistent)
docker-compose up web

# Open http://localhost:3000

# Run a pipeline with the CLI (socket mounted — docker isolation works)
docker-compose run --rm cli run thingfactory@examples:basic_pipeline --isolator local
```

## CLI Container

The CLI container is built from the root `Dockerfile`:

```
Stage 1 (builder): node:22-alpine + Gleam 1.13.0
  - Downloads dependencies
  - Compiles Gleam source to JavaScript

Stage 2 (runtime): node:22-alpine
  - Copies compiled JavaScript
  - Sets ENTRYPOINT ["node", "bin/cli.mjs"]
```

### Running with Example Projects

To run TypeScript or Go build pipelines, mount the examples directory:

```bash
docker run --rm \
  -v $(pwd)/examples:/app/examples \
  thingfactory run thingfactory@examples:typescript_build_pipeline --isolator local
```

## Web GUI Container

The web container is built from `web/Dockerfile`:

```bash
cd web
docker build -t thingfactory-web .
docker run -p 3000:3000 thingfactory-web
```

## Docker Compose

The `docker-compose.yml` defines two services:

| Service | Description         | Port |
| ------- | ------------------- | ---- |
| `web`   | Next.js web GUI     | 3000 |
| `cli`   | Pipeline CLI runner | —    |

```bash
# Start web GUI
docker-compose up web

# Run a CLI pipeline (one-off)
docker-compose run --rm cli run thingfactory@examples:basic_pipeline --isolator local

# Run with examples mounted
docker-compose run --rm cli run thingfactory@examples:typescript_build_pipeline --isolator local
```

## Configuration

| Environment Variable         | Default                | Description                          |
| ---------------------------- | ---------------------- | ------------------------------------ |
| `THINGFACTORY_DATABASE_PATH` | `./db/thingfactory.db` | SQLite database path                 |
| `THINGFACTORY_PORT`          | `3000`                 | Web GUI port (also read from `PORT`) |
| `NODE_ENV`                   | `production`           | Node environment                     |

### Persistent Database

```bash
docker run -p 3000:3000 \
  -v $(pwd)/data:/app/data \
  thingfactory-web
```

## Self-Hosting

### Web GUI + Pipeline Execution (Hobbyist Setup)

Start the full stack with one command:

```bash
docker-compose up -d web
```

This starts the web GUI with a persistent SQLite database on port 3000.

To run pipelines with Docker isolation from inside the container (Docker-socket
approach), the CLI service mounts the host Docker socket. No privileged DinD
daemon is required — pipeline containers are spawned via the host daemon:

```bash
# Run a pipeline inside a Gleam Docker container (uses host Docker daemon)
docker-compose run --rm cli run --isolator docker thingfactory@examples:basic_pipeline

# Run with local isolation (no Docker spawn)
docker-compose run --rm cli run --isolator local thingfactory@examples:basic_pipeline
```

The `docker-compose.yml` CLI service mounts `/var/run/docker.sock`
automatically. Ensure the host Docker daemon is running and the socket is
accessible.

### Requirements for Docker Isolation Inside Container

- Host must have Docker daemon running
- `/var/run/docker.sock` must be accessible (default on Linux/macOS)
- Docker socket is mounted read-write by default in `docker-compose.yml`

See [docs/HOSTING_SERVICE.md](docs/HOSTING_SERVICE.md) for production
deployment.
