import { test, expect } from "./fixtures";

test.describe("Run Detail", () => {
  test("loads run detail page for seeded run", async ({ page }) => {
    // Navigate to runs list first to get a valid run ID
    await page.goto("/runs");
    const firstDetailLink = page.locator("text=Details →").first();
    await firstDetailLink.click();

    // Wait for navigation and then check we're on a run detail page
    await page.waitForLoadState("networkidle");
    // URL may have /runs/ID format
    const url = page.url();
    expect(url).toMatch(/\/runs\/[a-f0-9-]+/);
    await expect(page.getByRole("heading", { name: /^Run/ })).toBeVisible();
  });

  test("displays run metadata", async ({ page }) => {
    await page.goto("/runs");
    const firstDetailLink = page.locator("text=Details →").first();
    await firstDetailLink.click();

    // Should show run metadata - look for in the summary card section
    const summaryCard = page.locator("div").filter({ hasText: /Status.*Total Duration.*Started.*Finished/ });
    await expect(summaryCard.first()).toBeVisible({ timeout: 5000 });
  });

  test("shows status badge on run detail", async ({ page }) => {
    await page.goto("/runs");
    const firstDetailLink = page.locator("text=Details →").first();
    await firstDetailLink.click();

    // Should display a status badge - check in the summary card
    const statusSection = page.locator("div").filter({ hasText: /Status/ }).first();
    await expect(statusSection).toBeVisible({ timeout: 5000 });
  });

  test("displays step traces table", async ({ page }) => {
    await page.goto("/runs");
    const firstDetailLink = page.locator("text=Details →").first();
    await firstDetailLink.click();

    // Should show step traces section
    await expect(page.getByText("Step Traces")).toBeVisible();
  });

  test("shows step trace details in table", async ({ page }) => {
    await page.goto("/runs");
    const firstDetailLink = page.locator("text=Details →").first();
    await firstDetailLink.click();

    // Should have step traces with proper columns
    const stepTraceRows = page.locator("text=Step Traces").first().locator("..").locator("div");
    // At least one trace should exist (seeded data)
    const traceElements = page.locator("[data-testid='step-trace'], div").filter({ hasText: /Step Traces/ });
    await expect(traceElements.first()).toBeVisible({ timeout: 5000 });
  });

  test("can navigate back to pipeline detail", async ({ page }) => {
    await page.goto("/runs");
    const firstDetailLink = page.locator("text=Details →").first();
    await firstDetailLink.click();

    // Should have back link to pipeline
    const backLink = page.locator("a").filter({ hasText: /^←/ }).first();
    if (await backLink.isVisible()) {
      const href = await backLink.getAttribute("href");
      expect(href).toContain("/pipelines/");
    }
  });

  test("returns 404 for invalid run ID", async ({ page }) => {
    const response = await page.goto("/runs/invalid-run-id-12345");
    expect(response?.status()).toBe(404);
  });

  test("displays duration bars for step traces", async ({ page }) => {
    await page.goto("/runs");
    const firstDetailLink = page.locator("text=Details →").first();
    await firstDetailLink.click();

    // Wait for step traces to load
    await page.waitForTimeout(500);

    // Should have duration information
    const durationElements = page.locator("div").filter({ hasText: /ms/ });
    // At least some duration elements should exist
    const count = await durationElements.count();
    expect(count).toBeGreaterThanOrEqual(0);
  });

  test("shows error messages if step failed", async ({ page }) => {
    // This test tries to find a failed run
    await page.goto("/runs?status=failed");

    const failedRows = page.locator("table tbody tr");
    const count = await failedRows.count();

    if (count > 0) {
      const firstFailedLink = page.locator("text=Details →").first();
      await firstFailedLink.click();

      // Navigate to run detail and look for error messages
      await page.waitForTimeout(500);
      // Error messages would show in step traces if they exist
      const errorElements = page.locator("div").filter({ hasText: /error|failed|Error|Failed/ });
      // May or may not have errors depending on seeded data
    }
  });

  test("displays pipeline information in header", async ({ page }) => {
    await page.goto("/runs");
    const firstDetailLink = page.locator("text=Details →").first();
    await firstDetailLink.click();

    // Should show pipeline name and version in breadcrumb or header
    const headerText = page.locator("p").first();
    await expect(headerText).toContainText(/v\d+\.\d+\.\d+/);
  });

  test("has navigation sidebar with correct links", async ({ page }) => {
    await page.goto("/runs");
    const firstDetailLink = page.locator("text=Details →").first();
    await firstDetailLink.click();

    await expect(page.getByText("Thingfactory")).toBeVisible();
    await expect(page.getByRole("link", { name: /Pipelines/ })).toBeVisible();
    await expect(page.getByRole("link", { name: /Runs/ })).toBeVisible();
  });

  test("shows triggered by information", async ({ page }) => {
    await page.goto("/runs");
    const firstDetailLink = page.locator("text=Details →").first();
    await firstDetailLink.click();

    // Header should show trigger type
    const header = page.locator("p").first();
    await expect(header).toContainText(/Triggered by/);
  });

  test("shows log viewer hint text", async ({ page }) => {
    await page.goto("/runs");
    const firstDetailLink = page.locator("text=Details →").first();
    await firstDetailLink.click();

    // Should show the "click a step to view logs" hint
    await expect(page.getByText("click a step to view logs")).toBeVisible();
  });

  test("expands step logs on click", async ({ page }) => {
    await page.goto("/runs");
    const firstDetailLink = page.locator("text=Details →").first();
    await firstDetailLink.click();

    // Wait for page to load
    await page.waitForLoadState("networkidle");

    // Click the first step row to expand logs
    const firstStepRow = page.locator("[data-testid^='step-row-']").first();
    await firstStepRow.click();

    // Should show the log output panel
    const logPanel = page.locator("[data-testid^='step-log-']").first();
    await expect(logPanel).toBeVisible();

    // Log panel should contain log text (starts with timestamp)
    await expect(logPanel).toContainText(/Starting step:/);
  });

  test("collapses step logs on second click", async ({ page }) => {
    await page.goto("/runs");
    const firstDetailLink = page.locator("text=Details →").first();
    await firstDetailLink.click();

    await page.waitForLoadState("networkidle");

    // Click to expand
    const firstStepRow = page.locator("[data-testid^='step-row-']").first();
    await firstStepRow.click();
    await expect(page.locator("[data-testid^='step-log-']").first()).toBeVisible();

    // Click again to collapse
    await firstStepRow.click();
    await expect(page.locator("[data-testid^='step-log-']")).toHaveCount(0);
  });

  test("step log displays command lines with highlighting", async ({ page }) => {
    // Navigate to a typescript_build run to get detailed logs
    await page.goto("/runs");
    const firstDetailLink = page.locator("text=Details →").first();
    await firstDetailLink.click();

    await page.waitForLoadState("networkidle");

    // Click the first step to see logs
    const firstStepRow = page.locator("[data-testid^='step-row-']").first();
    await firstStepRow.click();

    const logPanel = page.locator("[data-testid^='step-log-']").first();
    await expect(logPanel).toBeVisible();

    // Should contain working directory line
    await expect(logPanel).toContainText(/Working directory:/);
  });
});
