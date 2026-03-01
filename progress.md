# Progress

Fill in the table as you progess

<!--
| scenario | status | documentation | rework notes |
|---|---|---|
| 1 | WORK_COMPLETE | docs/scenarios/1.md | |
| 2 | VERIFIED | docs/scenarios/2.md | |
| 3 | NEEDS_REWORK | docs/scenarios/3.md | 1. Doesn't work with feature X. 2. Doesn't correctly address user need Y. |
 -->

| scenario | status | documentation | rework notes |
|---|---|---|---|
| 1 | VERIFIED | docs/scenarios/1.md | README clearly shows CLI, Web GUI, Pipeline Runner & Orchestrator. |
| 2 | VERIFIED | docs/scenarios/2.md | CLI with clip parser, 15 runnable pipelines, 3-command install. |
| 3 | VERIFIED | docs/scenarios/3.md | 6 docs following Diataxis (how-to + reference), all with TOCs. |
| 4 | VERIFIED | docs/scenarios/4.md | pipeline.gleam builder API with Pipeline(output) phantom type, types.gleam with sum types. |
| 5 | VERIFIED | docs/scenarios/5.md | test_helpers.gleam with mock injection, test_helpers_test.gleam validates it. |
| 6 | VERIFIED | docs/scenarios/6.md | Dockerfile + bin/cli.mjs + docker-compose.yml + DOCKER.md all exist. |
| 7 | VERIFIED | docs/scenarios/7.md | artifact_store.gleam with read/write/keys, artifact_store_test.gleam. |
| 8 | VERIFIED | docs/scenarios/8.md | FixedCount/RetryOnFailure/UntilSuccess loop types in executor.gleam. |
| 9 | VERIFIED | docs/scenarios/9.md | command_runner.gleam with FFI for shell execution. Any fn can be a step. |
| 10 | VERIFIED | docs/scenarios/10.md | parallel_executor.gleam with DAG-aware topological sort, 8 tests. |
| 11 | VERIFIED | docs/scenarios/11.md | message_store.gleam pub-sub with publish/subscribe/clear/topics. |
| 12 | VERIFIED | docs/scenarios/12.md | StepTrace with real timing via FFI, StepEvent progress callbacks, DB persistence. |
| 13 | VERIFIED | docs/scenarios/13.md | Compact/verbose/interactive modes with real-time progress callbacks. |
| 14 | VERIFIED | docs/scenarios/14.md | 0005_step_logs.sql adds log_output column, StepLogViewer.tsx renders. |
| 15 | VERIFIED | docs/scenarios/15.md | scheduler.gleam with 6 schedule types, scheduler_test.gleam. |
| 16 | VERIFIED | docs/scenarios/16.md | webhook_trigger.gleam with matchers, GitHub/GitLab helpers, dedup. |
| 17 | VERIFIED | docs/scenarios/17.md | ManualTrigger + CustomMatcher + Schedule triggers. |
| 18 | VERIFIED | docs/scenarios/18.md | 5 GUI pages: dashboard, pipelines, pipeline detail, runs, run detail. 7 E2E test files. |
| 19 | VERIFIED | docs/scenarios/19.md | 3 built-in runners: sequential, parallel, command. runner_host defaults Local. |
| 20 | VERIFIED | docs/scenarios/20.md | Extensible via custom step factories, kubernetes_runner.step(). |
| 21 | VERIFIED | docs/scenarios/21.md | Gleam first-class, JS/Erlang via FFI. |
| 22 | VERIFIED | docs/scenarios/22.md | Real TypeScript (examples/typescript-lib/) and Go (examples/go-lib/) projects with command_runner.step_in_dir() using real npm/go commands. Gleam uses real gleam commands. |
| 23 | VERIFIED | docs/scenarios/23.md | 30-min timeout default, error stops pipeline, auto CPU core detection. |
| 24 | VERIFIED | docs/scenarios/24.md | artifact_store + message_store + dependency_injector all in Context. |
| 25 | VERIFIED | docs/scenarios/25.md | runner_host.new() calls get_cpu_count() FFI, min 1 worker. |
| 26 | VERIFIED | docs/scenarios/26.md | kubernetes_runner.gleam with Job YAML generation, kubectl integration. |
| 27 | VERIFIED | docs/scenarios/27.md | secret_manager.gleam with opaque types, masking, CRUD, validation. |
| 28 | VERIFIED | docs/scenarios/28.md | All structural types use sum types. No stringly-typed references. |
| 29 | VERIFIED | docs/scenarios/29.md | StepLogViewer.tsx + SSE streaming endpoint + RunDetailClient.tsx. |
| 30 | VERIFIED | docs/scenarios/30.md | CLI uses same executor/parallel_executor as production. |
| 31 | VERIFIED | docs/scenarios/31.md | 15 CLI-runnable pipelines, seed.ts populates GUI database. |
| 32 | NEEDS_REWORK | docs/scenarios/32.md | Gleam functions are compiled into the CLI, which is incorrect. A pipeline file should be referenced and the pipeline provided to the CLI. |
| 33 | NEEDS_REWORK | docs/scenarios/33.md | CLI has no `-f <file>` flag. Spec says "CLI SHALL accept as input a file to read the pipeline definition from" and gives examples like `cli run -f <file> <pipeline-name> .`. Current CLI only accepts hardcoded pipeline names. |
| 34 | VERIFIED | docs/scenarios/34.md | GanttTimeline.tsx with horizontal bars, color-coded status, duration labels. |
| 35 | NEEDS_REWORK | docs/scenarios/35.md | --interactive flag makes no sense. what is it supposed to do? |
| 36 | NEEDS_REWORK | docs/scenarios/36.md | The dogfood pipeline uses io.println, but no output is shown when running the CLI. |
| 37 | VERIFIED | docs/scenarios/37.md | -o/--output-dir flag extracts artifacts to disk. |
| 38 | NEEDS_REWORK | docs/scenarios/38.md | CLI defaults to Local (in-process) execution via runner_host.new(). Spec says "default to docker containers." Docker is available but not the default isolation mechanism. |
| 39 | VERIFIED | docs/scenarios/39.md | 6 docs with TOCs covering hosting, running, all aspects. |
| 40 | VERIFIED | docs/scenarios/40.md | dogfood_pipeline() runs real gleam/npm commands to build itself. |
| 41 | NEEDS_REWORK | docs/scenarios/41.md | Parallel steps and value accumulation work, but spec says "Each step should run on a different node (such as different docker container) to demonstrate the distributed nature." All examples run in-process. No distributed node execution demonstrated. |
| 42 | VERIFIED | docs/scenarios/42.md | gleam_build_pipeline and dogfood_pipeline run real multi-step builds. |
| 43 | VERIFIED | docs/scenarios/43.md | Dockerfile (CLI), web/Dockerfile (GUI), docker-compose.yml (one-command deploy), DOCKER.md (docs). |
| 44 | VERIFIED | docs/scenarios/44.md | ArtifactsList.tsx, API endpoints, 0004_artifacts.sql migration. |
| 45 | VERIFIED | docs/scenarios/45.md | Stats page, API endpoint, E2E test for statistics dashboard. |
| 46 | VERIFIED | docs/scenarios/46.md | Green palette (#059669, #10b981), tonal grays, flat style, SVG textures, compact/standard modes. |
| 47 | VERIFIED | docs/scenarios/47.md | work_queue.gleam with enqueue/pull_all, push via step args, pull via queue. |
