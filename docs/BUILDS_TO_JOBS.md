# Getting Builds Into Jobs

This guide covers the complete workflow for deploying Thingfactory with Docker
and connecting your VCS repositories so that pushes automatically create
pipeline runs.

## Table of Contents

- [Overview](#overview)
- [Step 1: Deploy with Docker](#step-1-deploy-with-docker)
  - [Quick Start (Single Container)](#quick-start-single-container)
  - [Docker Compose (Recommended)](#docker-compose-recommended)
  - [Expose the Service Publicly](#expose-the-service-publicly)
- [Step 2: Define Pipelines with Triggers](#step-2-define-pipelines-with-triggers)
- [Step 3: Register Repository Connections](#step-3-register-repository-connections)
  - [GitHub](#github)
  - [Gitea](#gitea)
- [Step 4: Configure Webhooks in Your VCS](#step-4-configure-webhooks-in-your-vcs)
  - [GitHub Webhook](#github-webhook)
  - [Gitea Webhook](#gitea-webhook)
- [Step 5: Verify the Flow](#step-5-verify-the-flow)
- [Troubleshooting](#troubleshooting)

## Overview

The pipeline from VCS push to a Thingfactory job involves four components:

```
GitHub / Gitea
      │  push event (HTTP POST)
      ▼
Thingfactory Web Service
  POST /api/webhooks/github   or   POST /api/webhooks/gitea
      │  looks up matching connection (repo + branch + pipeline_id)
      ▼
Pipeline Run Created
      │  steps execute in Docker containers
      ▼
Results visible in Web GUI  (/runs)
```

## Step 1: Deploy with Docker

### Quick Start (Single Container)

Build and start the web GUI:

```bash
# Build the web image
cd web
docker build -t thingfactory-web .

# Run with persistent storage
docker run -d \
  --name thingfactory \
  -p 3000:3000 \
  -v $(pwd)/data:/app/data \
  thingfactory-web
```

Open [http://localhost:3000](http://localhost:3000) to verify the GUI is
running.

### Docker Compose (Recommended)

The project ships a `docker-compose.yml` that includes both the web GUI and the
CLI runner:

```bash
# Clone the project
git clone <repo-url>
cd thingfactory

# Start the web GUI
docker-compose up -d web

# Verify
docker-compose ps
```

The `web` service starts on port 3000 with a persistent SQLite volume. To also
run pipeline steps in Docker containers (the default isolation mode), mount the
Docker socket:

```yaml
# docker-compose.yml (web service excerpt)
services:
  web:
    build:
      context: web
      dockerfile: Dockerfile
    ports:
      - "3000:3000"
    volumes:
      - ./data:/app/data
      - /var/run/docker.sock:/var/run/docker.sock
```

### Expose the Service Publicly

Webhooks from GitHub or Gitea must be able to reach the service. Options:

- **Production server**: deploy behind nginx (see
  [HOSTING_SERVICE.md](HOSTING_SERVICE.md#reverse-proxy)) with a public DNS
  record.
- **Local development**: use a tunnel tool such as [ngrok](https://ngrok.com):
  ```bash
  ngrok http 3000
  # Exposes: https://abc123.ngrok.io → localhost:3000
  ```

Record your public URL — you will need it when configuring webhooks.

## Step 2: Define Pipelines with Triggers

Pipeline files must declare a `BranchUpdate` trigger so the webhook receiver
knows which pipeline to fire for a given branch:

```gleam
// src/my_ci_pipeline.gleam
import thingfactory/pipeline
import thingfactory/trigger
import thingfactory/command_runner

pub fn build() {
  pipeline.new("my_app_build", "1.0.0")
  |> pipeline.with_trigger(trigger.BranchUpdate("main"))
  |> pipeline.add_step("install", command_runner.sh("npm ci"))
  |> pipeline.add_step_with_deps("test", command_runner.sh("npm test"), ["install"])
  |> pipeline.add_step_with_deps("build", command_runner.sh("npm run build"), ["test"])
}
```

Register the pipeline with the web service by loading it (or referencing one of
the built-in example pipelines already seeded in the database). The GUI lists
all known pipelines at `/pipelines`.

## Step 3: Register Repository Connections

Open the **Integrations** page at `http://<your-host>:3000/integrations`.

### GitHub

1. Enter a **Personal Access Token** with `repo` scope and click **Load
   Organizations**.
2. Select the **Organization** (or your personal account).
3. Select the **Repository** — branches auto-populate.
4. Select the **Branch** to watch (e.g. `main`).
5. Choose the **Pipeline** to trigger from the selector.
6. Click **Register Connection**.

The connection is saved. The matching pipeline's trigger config is updated to
`{ GitHub: { repo: "org/repo", events: ["push"] } }`.

### Gitea

1. Enter your **Gitea Instance URL** (e.g. `https://gitea.example.com`).
2. Enter a **Gitea Access Token** and click **Load Repositories**.
3. Select the **Repository** — branches auto-populate.
4. Select the **Branch**.
5. Choose the **Pipeline**.
6. Click **Register Connection**.

## Step 4: Configure Webhooks in Your VCS

Tell GitHub or Gitea to POST push events to Thingfactory.

### GitHub Webhook

1. Go to your repository → **Settings** → **Webhooks** → **Add webhook**.
2. Set:
   - **Payload URL**: `https://<your-host>/api/webhooks/github`
   - **Content type**: `application/json`
   - **Events**: `Just the push event`
3. Click **Add webhook**.

GitHub will send a ping to verify the endpoint; the service returns `200`.

### Gitea Webhook

1. Go to your repository → **Settings** → **Webhooks** → **Add webhook** →
   **Gitea**.
2. Set:
   - **Target URL**: `https://<your-host>/api/webhooks/gitea`
   - **HTTP Method**: `POST`
   - **Content type**: `application/json`
   - **Trigger on**: `Push Events`
3. Click **Add webhook**.

## Step 5: Verify the Flow

1. Push a commit to the watched branch.
2. Open `http://<your-host>:3000/runs` — a new run should appear within seconds.
3. Click the run to see live step progress, logs, and artifacts.

To test without a real push, send a synthetic payload:

```bash
# GitHub
curl -X POST http://localhost:3000/api/webhooks/github \
  -H "Content-Type: application/json" \
  -d '{
    "ref": "refs/heads/main",
    "repository": { "name": "my-repo", "owner": { "login": "my-org" } }
  }'

# Gitea
curl -X POST http://localhost:3000/api/webhooks/gitea \
  -H "Content-Type: application/json" \
  -d '{
    "ref": "refs/heads/main",
    "repository": { "full_name": "my-org/my-repo" }
  }'
```

A successful response includes the triggered run IDs:

```json
{ "ok": true, "triggered": 1, "run_ids": ["run-abc123"] }
```

## Troubleshooting

| Symptom                        | Cause                              | Fix                                                   |
| ------------------------------ | ---------------------------------- | ----------------------------------------------------- |
| `triggered: 0` on webhook POST | No matching connection in database | Register the repo/branch connection on /integrations  |
| `400 Bad Request`              | Missing required JSON fields       | Verify webhook payload format matches expected schema |
| Webhook not reaching service   | Firewall / tunnel not running      | Check `ngrok` or public DNS; test with `curl` locally |
| Pipeline not in selector       | Pipeline not registered in DB      | Run `factory run -f <file> <fn>` or seed the database |
| Steps fail with Docker error   | Docker socket not mounted          | Add `-v /var/run/docker.sock:/var/run/docker.sock`    |

For more deployment options see [HOSTING_SERVICE.md](HOSTING_SERVICE.md). For
Docker-specific details see [../DOCKER.md](../DOCKER.md).
