# Web GUI Guide

The Thingfactory web interface for visualizing, monitoring, and managing
pipelines.

## Table of Contents

- [Overview](#overview)
- [Starting the GUI](#starting-the-gui)
- [Dashboard](#dashboard)
- [Pipelines Page](#pipelines-page)
- [Pipeline Detail](#pipeline-detail)
- [Runs Page](#runs-page)
- [Run Detail](#run-detail)
- [Statistics Page](#statistics-page)
- [API Endpoints](#api-endpoints)

## Overview

The web GUI is built with Next.js 15, React 19, and React Flow. It provides:

- Pipeline DAG visualization
- Run monitoring with log streaming
- Gantt/timeline view for execution timing
- Artifact download
- Statistics dashboard with performance trends

Navigation uses a sidebar with four sections: Dashboard, Pipelines, Runs, and
Statistics.

## Starting the GUI

```bash
cd web
npm install
npm run dev
```

The GUI runs at `http://localhost:3000` by default.

For production:

```bash
npm run build
npm start
```

## Dashboard

The home page (`/`) shows an overview of recent pipeline activity, including
latest runs and their status.

## Pipelines Page

The pipelines list (`/pipelines`) shows all registered pipeline definitions
with:

- Pipeline name and version
- Schedule configuration (if any)
- Trigger type
- Number of steps

Click a pipeline to view its detail page.

## Pipeline Detail

The pipeline detail page (`/pipelines/[name]/[version]`) shows:

- **DAG Visualization** -- interactive React Flow graph of the pipeline's step
  dependencies
- Step names and connections rendered as nodes and edges
- Pipeline metadata (version, timeout, schedule, trigger)
- A button to trigger a new run

## Runs Page

The runs list (`/runs`) shows all pipeline executions with:

- Run ID, pipeline name, and version
- Status (running, succeeded, failed)
- Start time and duration
- Trigger type (manual, schedule, webhook)
- Search and filtering capabilities

## Run Detail

The run detail page (`/runs/[runId]`) provides:

### Step Log Viewer

Stream and view logs for each step in the pipeline execution. Logs update in
real-time for running pipelines via the `/api/runs/[runId]/stream` endpoint.

### Gantt/Timeline View

A timeline visualization showing:

- When each step started and finished
- Step duration bars, color-coded by status
- Parallel step execution visualized as overlapping bars
- Easy identification of bottlenecks (longest bars)

### Artifacts Section

List of artifacts produced by the run with download buttons. Each artifact can
be downloaded individually.

## Statistics Page

The statistics dashboard (`/stats`) shows:

- Total runs, success rate, average duration
- Performance trends over time
- Pipeline-specific metrics
- Failure analysis

## API Endpoints

The web GUI exposes a REST API:

| Method | Endpoint                                  | Description                   |
| ------ | ----------------------------------------- | ----------------------------- |
| GET    | `/api/health`                             | Health check                  |
| GET    | `/api/pipelines`                          | List all pipeline definitions |
| GET    | `/api/pipelines/[name]/[version]`         | Get pipeline definition       |
| POST   | `/api/pipelines/[name]/[version]/trigger` | Trigger a pipeline run        |
| GET    | `/api/runs`                               | List all runs                 |
| GET    | `/api/runs/[runId]`                       | Get run details               |
| GET    | `/api/runs/[runId]/stream`                | Stream run output (SSE)       |
| GET    | `/api/runs/[runId]/artifacts`             | List run artifacts            |
| GET    | `/api/artifacts/[id]`                     | Download artifact             |
| GET    | `/api/stats`                              | Pipeline statistics           |
| POST   | `/api/test/reset`                         | Reset test database           |

## Database

The GUI uses SQLite with [Kysely](https://kysely.dev/) for type-safe queries.
Schema includes:

- `pipeline_definitions` -- pipeline metadata and step definitions
- `pipeline_runs` -- execution records with status and timing
- `step_traces` -- per-step execution traces
- `step_logs` -- step output logs
- `artifacts` -- produced artifacts with content

Migrations are in `web/db/migrations/` and run automatically on startup.
