# Docker Guide

Thingfactory ships with Docker support for both the CLI pipeline runner and the web GUI.

## Table of Contents

- [Quick Start](#quick-start)
- [CLI Container](#cli-container)
- [Web GUI Container](#web-gui-container)
- [Docker Compose](#docker-compose)
- [Configuration](#configuration)

## Quick Start

### CLI Only

```bash
# Build the CLI image
docker build -t thingfactory .

# Run a pipeline
docker run --rm thingfactory run basic

# Run with compact output
docker run --rm thingfactory run parallel -c

# List available pipelines
docker run --rm thingfactory list
```

### Full Stack (CLI + Web GUI)

```bash
# Start the web GUI (persistent)
docker-compose up web

# Open http://localhost:3000

# Run a pipeline with the CLI
docker-compose run --rm cli run basic
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
  thingfactory run typescript
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

| Service | Description | Port |
|---|---|---|
| `web` | Next.js web GUI | 3000 |
| `cli` | Pipeline CLI runner | — |

```bash
# Start web GUI
docker-compose up web

# Run a CLI pipeline (one-off)
docker-compose run --rm cli run basic

# Run with examples mounted
docker-compose run --rm cli run typescript
```

## Configuration

| Environment Variable | Default | Description |
|---|---|---|
| `DATABASE_URL` | `/app/data/thingfactory.db` | SQLite database path |
| `NODE_ENV` | `production` | Node environment |
| `PORT` | `3000` | Web GUI port |

### Persistent Database

```bash
docker run -p 3000:3000 \
  -v $(pwd)/data:/app/data \
  thingfactory-web
```

## Self-Hosting

For hobbyist self-hosting with a single container:

```bash
docker-compose up -d web
```

This starts the web GUI with a persistent SQLite database. Use the CLI to run pipelines against the same machine:

```bash
docker-compose run --rm cli run dogfood
```

See [docs/HOSTING_SERVICE.md](docs/HOSTING_SERVICE.md) for production deployment.
