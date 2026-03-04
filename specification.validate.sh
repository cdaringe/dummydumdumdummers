#!/usr/bin/env bash
set -euo pipefail

# specification.validate.sh
# Validates that specification requirements are met.
# Fill in your validation logic below.
# Exit 0 on success, non-zero on failure.
# stdout/stderr will be captured and provided to the agent on failure.
rm -rf build
deno fmt .
npm --prefix web run lint
gleam test
gleam build --target erlang --warnings-as-errors
docker build -t thingfactory .
npm --prefix web run test:e2e
