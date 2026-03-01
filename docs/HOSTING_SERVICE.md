# Hosting the Service

Deploy and run the Thingfactory web service in production.

## Table of Contents

- [Hosting the Service](#hosting-the-service)
  - [Table of Contents](#table-of-contents)
  - [Deployment Options](#deployment-options)
  - [Docker Deployment](#docker-deployment)
    - [Build the Image](#build-the-image)
    - [Run the Container](#run-the-container)
    - [Persistent Storage](#persistent-storage)
    - [Docker-in-Docker](#docker-in-docker)
  - [Manual Deployment](#manual-deployment)
    - [Build](#build)
    - [Run](#run)
  - [Configuration](#configuration)
  - [Database](#database)
    - [Backup](#backup)
  - [Reverse Proxy](#reverse-proxy)
  - [Kubernetes](#kubernetes)
  - [Self-Hosting Tips](#self-hosting-tips)

## Deployment Options

Thingfactory can be deployed as:

1. **Docker container** (recommended) -- single container with the web GUI
2. **Manual Node.js deployment** -- build and run the Next.js app directly
3. **Kubernetes** -- for scaled deployments with multiple runner workers

## Docker Deployment

### Build the Image

```bash
docker build -t thingfactory .
```

The Dockerfile uses a multi-stage build:
- **Build stage**: `node:22-alpine` with Gleam 1.13.0, compiles Gleam to JavaScript
- **Runtime stage**: `node:22-alpine` with only compiled output

### Run the Container

CLI mode:

```bash
docker run --rm thingfactory run basic
docker run --rm thingfactory list
```

Web GUI:

```bash
cd web
docker build -t thingfactory-web .
docker run -p 3000:3000 -v ./data:/app/data thingfactory-web
```

### Persistent Storage

Mount a volume for the SQLite database:

```bash
docker run -p 3000:3000 \
  -v /path/to/data:/app/data \
  thingfactory-web
```

### Docker-in-Docker

For running pipeline steps in isolated containers (the default isolation mode), mount the Docker socket:

```bash
docker run -p 3000:3000 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /path/to/data:/app/data \
  thingfactory-web
```

## Manual Deployment

### Build

```bash
# Build Gleam core
gleam build --warnings-as-errors --target javascript

# Build web GUI
cd web
npm install --production
npm run build
```

### Run

```bash
cd web
NODE_ENV=production npm start
```

## Configuration

Environment variables:

| Variable | Default | Description |
|---|---|---|
| `PORT` | `3000` | Web server port |
| `NODE_ENV` | `development` | Node environment (`production` for deployed) |
| `DATABASE_PATH` | `./db/thingfactory.db` | SQLite database file path |

## Database

Thingfactory uses SQLite by default. The database is created automatically on first run. Migrations in `web/db/migrations/` are applied at startup.

For production, ensure the database file is on persistent storage (not ephemeral container filesystem).

### Backup

```bash
sqlite3 /path/to/thingfactory.db ".backup /path/to/backup.db"
```

## Reverse Proxy

Example nginx configuration:

```nginx
server {
    listen 80;
    server_name ci.example.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

The `Upgrade` and `Connection` headers are needed for SSE log streaming.

## Kubernetes

Thingfactory supports Kubernetes as a runner backend. Pipeline steps can execute as Kubernetes Jobs:

```gleam
let k8s_config =
  kubernetes_runner.default_config("node:20-alpine")
  |> kubernetes_runner.with_namespace("ci")
  |> kubernetes_runner.with_limits("1", "512Mi")
  |> kubernetes_runner.with_requests("250m", "128Mi")

pipeline.new("k8s_build", "1.0.0")
|> pipeline.add_step_with_deps(
  "test",
  kubernetes_runner.step(k8s_config, "tf-test", ["npm", "test"]),
  [],
)
```

Requirements:
- `kubectl` configured with cluster access
- RBAC permissions to create/read/delete Jobs in the target namespace

## Self-Hosting Tips

- **Single machine**: Run a single container with Docker-in-Docker. This is the simplest setup and suitable for small teams and hobbyists.
- **Workers**: The runner host initializes one worker per available CPU core by default.
- **Isolation**: Pipeline steps run in Docker containers by default. The isolation mechanism is pluggable.
- **Secrets**: Use `pipeline.add_secret()` to inject secrets. Secrets are stored in the pipeline's secret store and injected into the execution context.
- **Monitoring**: Use the Statistics page (`/stats`) to track pipeline health and performance trends.
