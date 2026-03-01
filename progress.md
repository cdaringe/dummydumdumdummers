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
| 1 | VERIFIED | docs/scenarios/1.md | |
| 2 | VERIFIED | docs/scenarios/2.md | |
| 3 | VERIFIED | docs/scenarios/3.md | |
| 4 | VERIFIED | docs/scenarios/4.md | |
| 5 | VERIFIED | docs/scenarios/5.md | |
| 6 | VERIFIED | docs/scenarios/6.md | |
| 7 | VERIFIED | docs/scenarios/7.md | |
| 8 | VERIFIED | docs/scenarios/8.md | |
| 9 | VERIFIED | docs/scenarios/9.md | |
| 10 | VERIFIED | docs/scenarios/10.md | |
| 11 | VERIFIED | docs/scenarios/11.md | |
| 12 | VERIFIED | docs/scenarios/12.md | |
| 13 | VERIFIED | docs/scenarios/13.md | |
| 14 | VERIFIED | docs/scenarios/14.md | |
| 15 | VERIFIED | docs/scenarios/15.md | |
| 16 | VERIFIED | docs/scenarios/16.md | |
| 17 | VERIFIED | docs/scenarios/17.md | |
| 18 | VERIFIED | docs/scenarios/18.md | |
| 19 | VERIFIED | docs/scenarios/19.md | |
| 20 | VERIFIED | docs/scenarios/20.md | |
| 21 | VERIFIED | docs/scenarios/21.md | |
| 22 | NEEDS_REWORK | docs/scenarios/22.md | TypeScript and Go build pipelines are mocked (return hardcoded strings with `// In production:` comments). Spec explicitly says "REAL, not mocked." Only the Gleam pipeline uses real commands. Need real TypeScript, Go, and Rust example projects with actual build commands. |
| 23 | VERIFIED | docs/scenarios/23.md | |
| 24 | VERIFIED | docs/scenarios/24.md | |
| 25 | VERIFIED | docs/scenarios/25.md | |
| 26 | VERIFIED | docs/scenarios/26.md | |
| 27 | VERIFIED | docs/scenarios/27.md | |
| 28 | VERIFIED | docs/scenarios/28.md | |
| 29 | VERIFIED | docs/scenarios/29.md | |
| 30 | VERIFIED | docs/scenarios/30.md | |
| 31 | VERIFIED | docs/scenarios/31.md | |
| 32 | VERIFIED | docs/scenarios/32.md | |
| 33 | NEEDS_REWORK | docs/scenarios/33.md | CLI has no `-f <file>` flag. Spec says "CLI SHALL accept as input a file to read the pipeline definition from" and spec examples show `cli run -f <file> <pipeline-name> .`. Current CLI only accepts pipeline names resolving to compiled functions. |
| 34 | VERIFIED | docs/scenarios/34.md | |
| 35 | VERIFIED | docs/scenarios/35.md | |
| 36 | VERIFIED | docs/scenarios/36.md | |
| 37 | VERIFIED | docs/scenarios/37.md | |
| 38 | NEEDS_REWORK | docs/scenarios/38.md | CLI defaults to Local (in-process) execution. Spec says "default to docker containers." Docker is available but not the default - users must explicitly run via `docker run`. |
| 39 | VERIFIED | docs/scenarios/39.md | |
| 40 | VERIFIED | docs/scenarios/40.md | |
| 41 | NEEDS_REWORK | docs/scenarios/41.md | Spec says "Each step should run on a different node (such as different docker container) to demonstrate the distributed nature." All steps run in-process. No distributed node execution demonstrated. |
| 42 | VERIFIED | docs/scenarios/42.md | |
| 43 | VERIFIED | docs/scenarios/43.md | |
| 44 | VERIFIED | docs/scenarios/44.md | |
| 45 | VERIFIED | docs/scenarios/45.md | |
| 46 | VERIFIED | docs/scenarios/46.md | |
| 47 | VERIFIED | docs/scenarios/47.md | |
