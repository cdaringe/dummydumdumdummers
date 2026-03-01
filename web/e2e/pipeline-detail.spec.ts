import { test, expect } from "./fixtures";

test.describe("Pipeline Detail", () => {
  test("loads typescript_build pipeline detail page", async ({ page }) => {
    await page.goto("/pipelines/typescript_build/1.0.0");
    await expect(page.getByRole("heading", { name: "typescript_build" })).toBeVisible();
  });

  test("shows pipeline metadata (version, steps count, schedule)", async ({
    page,
  }) => {
    await page.goto("/pipelines/typescript_build/1.0.0");
    await expect(page.getByText(/v1\.0\.0/)).toBeVisible();
    await expect(page.getByText(/6 steps/)).toBeVisible();
  });

  test("renders the React Flow DAG canvas", async ({ page }) => {
    await page.goto("/pipelines/typescript_build/1.0.0");
    const dag = page.locator("[data-testid='pipeline-dag']");
    await expect(dag).toBeVisible();
    // React Flow renders its wrapper with rf__wrapper
    const rfWrapper = page.locator(".react-flow__renderer, .react-flow__viewport, [data-testid='rf__wrapper']");
    await expect(rfWrapper.first()).toBeVisible({ timeout: 10000 });
  });

  test("draws an edge for every declared dependency", async ({ page }) => {
    await page.goto("/pipelines/typescript_build/1.0.0");
    await page.waitForTimeout(500);

    // typescript_build has 6 dependency edges:
    // checkout->install-deps, install-deps->lint, install-deps->compile,
    // compile->unit_tests, lint->package, unit_tests->package
    const edges = page.locator("[data-testid='pipeline-dag-edges'] span");
    await expect(edges).toHaveCount(6);

    // Spot-check a specific edge id to ensure wiring is correct (div is hidden, use toBeAttached)
    await expect(page.locator('[data-testid="edge-install-deps->lint"]')).toBeAttached();
  });

  test("shows step nodes in the DAG", async ({ page }) => {
    await page.goto("/pipelines/typescript_build/1.0.0");
    // Wait for React Flow to hydrate
    await page.waitForTimeout(1000);
    // Step names should appear in the custom nodes
    const dag = page.locator("[data-testid='pipeline-dag']");
    const checkoutNode = dag.locator("[data-testid='rf__node-checkout'], div[class*='react-flow']:has-text('checkout')").first();
    await expect(checkoutNode).toBeVisible({ timeout: 5000 });
  });

  test("shows steps table with correct step count", async ({ page }) => {
    await page.goto("/pipelines/typescript_build/1.0.0");
    await expect(page.getByText("Steps (6)")).toBeVisible();
    await expect(page.getByRole("cell", { name: "checkout" }).first()).toBeVisible();
    await expect(page.getByRole("cell", { name: "unit_tests" }).first()).toBeVisible();
  });

  test("shows run history table", async ({ page }) => {
    await page.goto("/pipelines/typescript_build/1.0.0");
    await expect(page.getByText("Run History")).toBeVisible();
    const rows = page.locator("table").last().locator("tbody tr");
    await expect(rows.first()).toBeVisible();
  });

  test("can navigate to a run detail from run history", async ({ page }) => {
    await page.goto("/pipelines/typescript_build/1.0.0");
    const detailLink = page.locator("text=Details →").first();
    await detailLink.click();
    await page.waitForLoadState("networkidle");
    await expect(page.url()).toContain("/runs/");
  });

  test("shows parallel pipeline DAG correctly (parallel_build)", async ({
    page,
  }) => {
    await page.goto("/pipelines/parallel_build/1.0.0");
    await expect(page.getByRole("heading", { name: "parallel_build" })).toBeVisible();
    await page.waitForTimeout(1000);
    // Parallel pipeline has 5 steps
    await expect(page.getByText("Steps (5)")).toBeVisible();
  });

  test("shows back navigation link", async ({ page }) => {
    await page.goto("/pipelines/typescript_build/1.0.0");
    await expect(page.getByText("← Pipelines")).toBeVisible();
  });

  test("returns 404 for unknown pipeline", async ({ page }) => {
    const response = await page.goto("/pipelines/nonexistent/9.9.9");
    expect(response?.status()).toBe(404);
  });
});
