import type { Task, Tasks } from "https://deno.land/x/rad@v8.0.3/src/mod.ts";

const format: Task = {
  fn: async ({ sh }) => {
    await sh(`gleam format`);
    await sh(`npm --prefix web run lint -- --fix`);
  },
};

const test: Task = {
  fn: ({ sh }) => sh(`gleam test`),
};

const testE2e: Task = {
  fn: ({ sh }) => sh(`npm --prefix web run test:e2e`),
};

const build: Task = {
  fn: async ({ sh }) => {
    await sh(`gleam build --target erlang --warnings-as-errors`);
    await sh(`npm --prefix web run build`);
  },
};

const dockerBuild: Task = {
  fn: async ({ sh }) => {
    await sh(`docker build -t thingfactory .`);
    await sh(`docker build -t thingfactory-web -f web/Dockerfile web`);
  },
};

const check: Task = {
  dependsOn: [format, test, build],
  dependsOnSerial: true,
};

const deploy: Task = {
  dependsOn: [check],
  fn: async ({ sh, logger }) => {
    const host = Deno.env.get("DEPLOY_HOST");
    const repo = Deno.env.get("DEPLOY_REPO") ||
      "git@github.com:cdaringe/thingfactory.git";
    const dir = Deno.env.get("DEPLOY_DIR") || "/opt/thingfactory";
    const user = Deno.env.get("DEPLOY_USER") || "root";
    const branch = Deno.env.get("DEPLOY_BRANCH") || "main";
    const dataDir = Deno.env.get("THINGFACTORY_DATA_DIRNAME") ||
      `${dir}/data`;
    if (!host) throw new Error("DEPLOY_HOST env var is required");

    const target = `${user}@${host}`;
    const ssh = (cmd: string) => sh(`ssh ${target} '${cmd}'`);

    logger.info(`deploying to ${target}:${dir}`);

    // ensure target dir exists and clone or pull
    await ssh(
      `mkdir -p ${dir} && cd ${dir} && ` +
        `(test -d .git && git fetch origin && git reset --hard origin/${branch} || ` +
        `git clone --branch ${branch} ${repo} .)`,
    );

    // create data subdirectories
    await ssh(
      `mkdir -p ${dataDir}/db ${dataDir}/logs ${dataDir}/backups`,
    );

    // build images on the remote host
    await ssh(
      `cd ${dir} && docker compose build`,
    );

    // bring services up with persistent data volumes
    await ssh(
      `cd ${dir} && THINGFACTORY_DATA_DIRNAME=${dataDir} docker compose up -d --remove-orphans`,
    );

    logger.info(`deployed to ${target}`);
  },
};

export const tasks: Tasks = {
  format,
  f: format,
  test,
  t: test,
  testE2e,
  te: testE2e,
  build,
  b: build,
  dockerBuild,
  db: dockerBuild,
  check,
  c: check,
  deploy,
  d: deploy,
};
