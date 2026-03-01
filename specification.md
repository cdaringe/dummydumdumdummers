# Objective

Build a best-in-class task runner, commonly used for CI/CD. It should have the
spirit of concourseci, buildkite, or argo, with improvements on the DevUX of each.

## Scenarios

0. The project SHALL always have passing tests & working examples.
1. A user SHALL be able to visit the README and understand what the project offers: a CLI, a web GUI, a pipeline runner & orchestrator.
2. A user SHALL be able to rapidly install the CLI and run it against an example pipeline hosted in a file in this project's examples.
3. The project shall offer documentation adherent to Diátaxis, mainly "how to" and "reference". We value conciseness and linking to other resources over long-form documentation.
4. Pipelines SHALL be buildable via typesafe gleam code
5. Pipelines SHALL be testable
6. Pipelines SHALL be runnable in any docker enabled environment
7. Pipelines SHALL have the ability to share artifacts
8. Pipelines SHALL be able to loop, or be re-entrant
9. Pipelines SHALL support running arbitrary compute tasks
10. Pipeline tasks SHALL be able to run in parallel
11. Pipeline tasks SHALL be able to broadcast messages to one another or coordinate if the user desires
12. Pipeline tasks SHALL be monitor-able and observable
13. Pipeline tasks SHALL steam stdio to the user when executed locally using the CLI.
14. Pipeline tasks SHALL have stdio persisted and viewable after execution.
15. Pipelines SHALL be able to run on a schedule
16. Pipelines SHALL be able to be triggered by external events
17. Pipelines SHOULD be able to run given other triggers
18. Pipelines states SHALL be visible through a GUI
19. Pipeline task runners SHALL come with defaults for common use cases.
20. Pipeline task runners SHALL be extensible to support custom use cases.
21. Pipelines SHOULD be able to be authored in a variety of languages, but Gleam SHOULD be the first-class reference.
22. The source code should have a large set of sample pipelines, demonstrating:
    1. compilation of libraries for typescript, go, & gleam. They should be REAL, not mocked.
    2. demonstration of defining a custom Docker image to run a pipeline in
23. The GUI & system parameters SHOULD, when otherwise undefined, use behaviors and capabilities that are common in the CI/CD ecosystem, to minimize the learning curve for users coming from other systems.
24. Pipelines SHOULD be able to consume resources (such as artifacts, APIs, databases, files) from other nodes in the pipeline with high ease.
25. The default runner host should optimistically SHALL try to initialize default allow one worker per available core for ease of use.
26. The runner host SHALL allow kubernetes as a runner backend, but SHOULD be able to run on a single machine for ease of use.
27. The pipeline system SHALL provide secrets management for Pipelines.
28. The pipeline tasks SHALL NOT be stringly typed or referenced. Stringly typing in general is to be minimized across the system.
29. The Pipeline GUI SHALL allow for the viewing of logs efficiently, streaming from the providing agents.
30. The system SHALL offer a CLI to run pipelines locally, exactly as they would run in production, for ease of development and testing. This includes running in docker containers, as should be the default case.
31. The project shall host examples that are runable with the CLI (e.g. `cli run -f <file> <pipeline-name> .`) and demonstrate the same pipelines running in the GUI, showing logs, results, and artifacts.
32. The CLI SHALL NOT embed examples pipelines in the binary or compiled artifact.
33. The CLI SHALL accept as input a file to read the pipeline definition from. Pipeslines SHALL NOT need pre-compilation.
34. The Pipeline GUI SHALL provide a gantt/timeline view of Pipeline runs such that users can easily see which steps are taking the most time, and identify bottlenecks.
35. The CLI SHALL be designed to be published and used by customers. A real, proper CLI parser should be used to run pipelines, list pipelines, view pipeline results, extract artifacts, and more.
36. The CLI SHALL show compact and verbose modes of progress along a pipeline. Compact mode would show step-n / of-m and a spinner, while verbose mode would show all logs and outputs in real time.
37. The CLI SHALL offer a way to extract produced artifacts from a run.
38. The CLI SHALL by default run pipelines in isolation. The isolation mechanism should be plugable, but default to docker containers.
39. The site SHALL host user documentation on how to host the service, how to run Pipelines, and ALL other aspects of using the system and tools. Every page SHALL have a TOC.
40. The system SHALL be built & tested, dogfooding itself. The project should define a various Pipelines that the runner shall be able to pickup and run, build the project (the cli, the web service, runners, etc), run tests, and deploy.
41. The project SHALL host examples that have asynchronous steps, parallel steps, and steps the accumulate values and pass them to later steps. Each step should run on a different node (such as different docker container) to demonstrate the distributed nature of sharing results and artifacts.
42. The project SHALL have runnable demos that run a multi-step pipeline that compiles a project & runs tests. (e.g. `factory run -f <file> <pipeline-name> .`) It shall be executed in a docker container that mounts the demo project, and the viewer shall be able to observe the logs and results in real time via the CLI, as well as view the results and artifacts in the GUI. The project shall RUN Pipelines in docker containers, NOT strictly itself be run in a docker container, although the the server layer must be docker ready.
43. The project SHALL be excellent to self host with a user specified number of workers. Hobbyists SHOULD feel easy launching a singular container with docker-in-docker to support a host node that can receive requests to run pipelines, then run pipelines. It should be easier and more delightful than running Jenkins.
44. The Pipeline GUI SHALL provide a way to download produced artifacts.
45. The Pipeline GUI SHALL provide statistics about prior runs.
46. The Pipeline GUI SHALL stylistically focus on minimalism with theme very focused on light grays, some whites, and tonal grays. All highlights should be primarily light & dark greens, including text. It should offer a compact and standard mode. It should feel flat, simple, mechanical, and not cookie-cutter like often seen with tailwind styles. Backgrounds should be textured with very subtle patterns to add visual interest and depth.
47. Pipelines SHALL be easy to express work in both an imperative (PUSH model) as well as workers in the pipeline PULLing work from a queue (PULL model). This shall be enabled by the substrate, but because it's a common pattern, pipeline tools SHOULD be considered for offering this to users as a first class feature.
48. Pipelines SHALL enable users to call other programs succinctly with minimal boilerplate.
49. The CLI SHALL have integration tests that verify all major features of the CLI work, including using the docker based execution.
50. The GUI SHALL show the graph of a pipeline with edges connecting between steps.
51. The project SHALL provide a deployment guide.
52. The service SHALL be configurable via ALL THINGFACTORY_* environment variables, and the documentation SHALL provide a reference for all of these. The variables MUST be correlated to a clean/crisp typed datamodel that underpins the service.
53. The CLI Dockerfile SHALL be gleam based using erlang target.
54. The web Dockerfile SHALL be node based using next.js.
55. The GUI SHALL show the node state when a pipeline is running, such as "pending", "running", "failed", "succeeded", etc. It should also show the duration of each node, and the overall pipeline in the flow diagram itself.

## Requirements

1. The web GUI SHALL use next.js (v15+) & reacts-flow. Use common pages and patterns for Job management.
2. SQLite SHALL be the default database with kysely for typescript db codegen.
3. Changes SHALL be validated.
4. All SHALL be proven to work before changes are committed.
5. Slow tests SHALL not permitted.
6. Every scenario SHALL be accompanied by tests.
7. Every GUI page SHALL be accompanied by a PASSING playwright tests. Use deep DB reset every tests, in memory sqlite, and fixtures to produce data.
8. Every update SHALL be accompanied by with user documentation, contributing documentation, or developer documentation (docs/).
9. Outdated documentation SHALL be removed.
10. The system SHALL NOT accept YAML or JSON based flows.
11. Features SHALL NOT be duplicated--DRY code is a must.
12. Gleam code compilation SHALL NOT have any errors or warnings.
13. FFI code SHALL NOT be written for gleam to erlang or javascript.
