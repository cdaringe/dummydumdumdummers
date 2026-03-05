import { expect, test } from "./fixtures";

/**
 * Scenario 67: Pipelines opting in to run on executors with certain labels.
 *
 * The default executor pool contains one instance:
 *   { id: "default", labels: ["local", "standard"], config: { kind: "local" } }
 *
 * labeled_executor_standard requires ["standard"]  → resolves to the default local executor → success
 * labeled_executor_gpu        requires ["gpu"]      → no pool match → 403
 */

test.describe("Executor label-based selection (scenario 67)", () => {
  test("pipeline with satisfied label requirement triggers successfully", async ({
    page,
  }) => {
    // Trigger a pipeline whose executor is { kind: "labeled", requiredLabels: ["standard"] }
    // The default pool has an instance with labels ["local", "standard"], so it matches.
    const res = await page.request.post(
      "/api/pipelines/labeled_executor_standard/1.0.0/trigger",
      { maxRedirects: 0 },
    );
    // 303 redirect to /runs/:id means a run was created successfully
    expect(res.status()).toBe(303);
    expect(res.headers()["location"]).toMatch(/\/runs\//);
  });

  test("pipeline with unsatisfied label requirement is rejected with 403", async ({
    page,
  }) => {
    // Trigger a pipeline whose executor is { kind: "labeled", requiredLabels: ["gpu"] }
    // No executor in the default pool has the "gpu" label.
    const res = await page.request.post(
      "/api/pipelines/labeled_executor_gpu/1.0.0/trigger",
      { maxRedirects: 0 },
    );
    expect(res.status()).toBe(403);
    const body = await res.json();
    expect(body.error).toMatch(/gpu/);
  });
});
