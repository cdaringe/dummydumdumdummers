import gleam/string
import gleeunit/should
import thingfactory/examples
import thingfactory/kubernetes_runner
import thingfactory/runner_host

// ---------------------------------------------------------------------------
// Configuration construction
// ---------------------------------------------------------------------------

pub fn default_config_sets_image_test() {
  let config = kubernetes_runner.default_config("node:20-alpine")
  config.image |> should.equal("node:20-alpine")
  config.namespace |> should.equal("default")
  config.service_account |> should.equal("")
  config.kubeconfig |> should.equal("")
  config.restart_policy |> should.equal("Never")
  config.ttl_seconds |> should.equal(600)
}

pub fn default_config_resource_defaults_test() {
  let config = kubernetes_runner.default_config("golang:1.22")
  config.limits.cpu |> should.equal("500m")
  config.limits.memory |> should.equal("256Mi")
  config.requests.cpu |> should.equal("100m")
  config.requests.memory |> should.equal("64Mi")
}

pub fn with_namespace_test() {
  let config =
    kubernetes_runner.default_config("node:20")
    |> kubernetes_runner.with_namespace("ci-jobs")
  config.namespace |> should.equal("ci-jobs")
}

pub fn with_service_account_test() {
  let config =
    kubernetes_runner.default_config("node:20")
    |> kubernetes_runner.with_service_account("pipeline-runner")
  config.service_account |> should.equal("pipeline-runner")
}

pub fn with_kubeconfig_test() {
  let config =
    kubernetes_runner.default_config("node:20")
    |> kubernetes_runner.with_kubeconfig("/home/user/.kube/config")
  config.kubeconfig |> should.equal("/home/user/.kube/config")
}

pub fn with_limits_test() {
  let config =
    kubernetes_runner.default_config("node:20")
    |> kubernetes_runner.with_limits("2", "1Gi")
  config.limits.cpu |> should.equal("2")
  config.limits.memory |> should.equal("1Gi")
}

pub fn with_requests_test() {
  let config =
    kubernetes_runner.default_config("node:20")
    |> kubernetes_runner.with_requests("500m", "256Mi")
  config.requests.cpu |> should.equal("500m")
  config.requests.memory |> should.equal("256Mi")
}

pub fn with_ttl_test() {
  let config =
    kubernetes_runner.default_config("node:20")
    |> kubernetes_runner.with_ttl(3600)
  config.ttl_seconds |> should.equal(3600)
}

pub fn config_chaining_test() {
  let config =
    kubernetes_runner.default_config("rust:1.75")
    |> kubernetes_runner.with_namespace("build")
    |> kubernetes_runner.with_service_account("builder")
    |> kubernetes_runner.with_limits("4", "4Gi")
    |> kubernetes_runner.with_requests("1", "1Gi")
    |> kubernetes_runner.with_ttl(1800)

  config.image |> should.equal("rust:1.75")
  config.namespace |> should.equal("build")
  config.service_account |> should.equal("builder")
  config.limits.cpu |> should.equal("4")
  config.limits.memory |> should.equal("4Gi")
  config.requests.cpu |> should.equal("1")
  config.requests.memory |> should.equal("1Gi")
  config.ttl_seconds |> should.equal(1800)
}

// ---------------------------------------------------------------------------
// Job manifest generation
// ---------------------------------------------------------------------------

pub fn build_job_yaml_basic_test() {
  let config = kubernetes_runner.default_config("node:20-alpine")
  let yaml = kubernetes_runner.build_job_yaml(config, "my-job", ["npm", "test"])

  { string.contains(yaml, "apiVersion: batch/v1") } |> should.be_true()
  { string.contains(yaml, "kind: Job") } |> should.be_true()
  { string.contains(yaml, "name: my-job") } |> should.be_true()
  { string.contains(yaml, "namespace: default") } |> should.be_true()
  { string.contains(yaml, "image: node:20-alpine") } |> should.be_true()
  { string.contains(yaml, "restartPolicy: Never") } |> should.be_true()
}

pub fn build_job_yaml_command_test() {
  let config = kubernetes_runner.default_config("node:20")
  let yaml =
    kubernetes_runner.build_job_yaml(config, "test-job", ["npm", "run", "test"])

  { string.contains(yaml, "command: [\"npm\"]") } |> should.be_true()
  { string.contains(yaml, "- \"run\"") } |> should.be_true()
  { string.contains(yaml, "- \"test\"") } |> should.be_true()
}

pub fn build_job_yaml_single_command_test() {
  let config = kubernetes_runner.default_config("alpine:3.18")
  let yaml = kubernetes_runner.build_job_yaml(config, "simple", ["ls"])

  { string.contains(yaml, "command: [\"ls\"]") } |> should.be_true()
  // No args section for single command
  { string.contains(yaml, "args:") } |> should.be_false()
}

pub fn build_job_yaml_resources_test() {
  let config =
    kubernetes_runner.default_config("golang:1.22")
    |> kubernetes_runner.with_limits("2", "1Gi")
    |> kubernetes_runner.with_requests("500m", "256Mi")

  let yaml =
    kubernetes_runner.build_job_yaml(config, "go-build", ["go", "build"])

  { string.contains(yaml, "cpu: 2") } |> should.be_true()
  { string.contains(yaml, "memory: 1Gi") } |> should.be_true()
  { string.contains(yaml, "cpu: 500m") } |> should.be_true()
  { string.contains(yaml, "memory: 256Mi") } |> should.be_true()
}

pub fn build_job_yaml_namespace_test() {
  let config =
    kubernetes_runner.default_config("node:20")
    |> kubernetes_runner.with_namespace("ci-builds")

  let yaml = kubernetes_runner.build_job_yaml(config, "job1", ["echo", "hi"])

  { string.contains(yaml, "namespace: ci-builds") } |> should.be_true()
}

pub fn build_job_yaml_service_account_test() {
  let config =
    kubernetes_runner.default_config("node:20")
    |> kubernetes_runner.with_service_account("pipeline-sa")

  let yaml =
    kubernetes_runner.build_job_yaml(config, "sa-job", ["npm", "install"])

  { string.contains(yaml, "serviceAccountName: pipeline-sa") }
  |> should.be_true()
}

pub fn build_job_yaml_no_service_account_test() {
  let config = kubernetes_runner.default_config("node:20")
  let yaml = kubernetes_runner.build_job_yaml(config, "no-sa", ["echo", "hi"])

  { string.contains(yaml, "serviceAccountName") } |> should.be_false()
}

pub fn build_job_yaml_ttl_test() {
  let config =
    kubernetes_runner.default_config("node:20")
    |> kubernetes_runner.with_ttl(3600)

  let yaml = kubernetes_runner.build_job_yaml(config, "ttl-job", ["ls"])

  { string.contains(yaml, "ttlSecondsAfterFinished: 3600") } |> should.be_true()
}

pub fn build_job_yaml_empty_command_test() {
  let config = kubernetes_runner.default_config("busybox")
  let yaml = kubernetes_runner.build_job_yaml(config, "empty", [])

  // No command directive for empty command
  { string.contains(yaml, "command:") } |> should.be_false()
}

// ---------------------------------------------------------------------------
// Runner host with Kubernetes backend
// ---------------------------------------------------------------------------

pub fn with_kubernetes_creates_k8s_host_test() {
  let k8s_config = kubernetes_runner.default_config("node:20")
  let host = runner_host.with_kubernetes(k8s_config, 4)

  let s = runner_host.status(host)
  s.worker_count |> should.equal(4)

  case runner_host.get_backend(host) {
    runner_host.Kubernetes(_) -> should.be_true(True)
    runner_host.Local -> should.fail()
  }
}

pub fn with_kubernetes_clamps_workers_test() {
  let k8s_config = kubernetes_runner.default_config("node:20")
  let host = runner_host.with_kubernetes(k8s_config, 0)

  let s = runner_host.status(host)
  s.worker_count |> should.equal(1)
}

pub fn default_backend_is_local_test() {
  let host = runner_host.with_workers(2)
  case runner_host.get_backend(host) {
    runner_host.Local -> should.be_true(True)
    runner_host.Kubernetes(_) -> should.fail()
  }
}

pub fn new_backend_is_local_test() {
  let host = runner_host.new()
  case runner_host.get_backend(host) {
    runner_host.Local -> should.be_true(True)
    runner_host.Kubernetes(_) -> should.fail()
  }
}

pub fn set_backend_test() {
  let host = runner_host.with_workers(2)
  let k8s_config = kubernetes_runner.default_config("node:20")
  let host =
    runner_host.set_backend(host, runner_host.Kubernetes(config: k8s_config))

  case runner_host.get_backend(host) {
    runner_host.Kubernetes(config) -> config.image |> should.equal("node:20")
    runner_host.Local -> should.fail()
  }
}

pub fn set_backend_to_local_test() {
  let k8s_config = kubernetes_runner.default_config("node:20")
  let host = runner_host.with_kubernetes(k8s_config, 4)
  let host = runner_host.set_backend(host, runner_host.Local)

  case runner_host.get_backend(host) {
    runner_host.Local -> should.be_true(True)
    runner_host.Kubernetes(_) -> should.fail()
  }
}

// ---------------------------------------------------------------------------
// Kubernetes example pipeline structure
// ---------------------------------------------------------------------------

pub fn kubernetes_build_pipeline_structure_test() {
  let _p = examples.kubernetes_build_pipeline()
  // Pipeline builds without error — validates types and K8s step integration
  should.be_true(True)
}
