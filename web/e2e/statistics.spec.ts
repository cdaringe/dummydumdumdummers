import { expect, test } from "./fixtures";

test.describe("Statistics Page", () => {
  test("loads and shows page heading", async ({ page }) => {
    await page.goto("/stats");
    await expect(
      page.getByRole("heading", { name: "Statistics", exact: true }),
    ).toBeVisible();
    await expect(
      page.getByText("Pipeline performance and execution metrics"),
    ).toBeVisible();
  });

  test("shows overall stat cards", async ({ page }) => {
    await page.goto("/stats");
    // Use locator scoped to the card divs (not table headers)
    const cards = page.locator(".card");
    await expect(cards.filter({ hasText: "Total Runs" }).first()).toBeVisible();
    await expect(cards.filter({ hasText: "Success Rate" }).first())
      .toBeVisible();
    await expect(cards.filter({ hasText: "Avg Duration" }).first())
      .toBeVisible();
    await expect(cards.filter({ hasText: "Total Duration" }).first())
      .toBeVisible();
  });

  test("shows run count cards", async ({ page }) => {
    await page.goto("/stats");
    await expect(page.getByText("Successful Runs")).toBeVisible();
    await expect(page.getByText("Failed Runs")).toBeVisible();
  });

  test("shows fastest pipelines table", async ({ page }) => {
    await page.goto("/stats");
    await expect(
      page.getByRole("heading", { name: "Fastest Pipelines" }),
    ).toBeVisible();
  });

  test("shows slowest pipelines table", async ({ page }) => {
    await page.goto("/stats");
    await expect(
      page.getByRole("heading", { name: "Slowest Pipelines" }),
    ).toBeVisible();
  });

  test("shows pipeline statistics table with columns", async ({ page }) => {
    await page.goto("/stats");
    await expect(
      page.getByRole("heading", { name: "Pipeline Statistics" }),
    ).toBeVisible();
    await expect(
      page.getByRole("columnheader", { name: "Pipeline" }).first(),
    ).toBeVisible();
    await expect(
      page.getByRole("columnheader", { name: "Total Runs" }).first(),
    ).toBeVisible();
    await expect(
      page.getByRole("columnheader", { name: "Success Rate" }).first(),
    ).toBeVisible();
    await expect(
      page.getByRole("columnheader", { name: "Avg Duration" }).first(),
    ).toBeVisible();
  });

  test("displays seeded pipeline data in statistics table", async ({ page }) => {
    await page.goto("/stats");
    const rows = page.locator("table tbody tr");
    await expect(rows.first()).toBeVisible();
  });

  test("pipeline links navigate to pipeline detail", async ({ page }) => {
    await page.goto("/stats");
    // Find a pipeline link in any stats table
    const pipelineLink = page.locator("table tbody tr a").first();
    await expect(pipelineLink).toBeVisible();
    await pipelineLink.click();
    await expect(page).toHaveURL(/\/pipelines\//);
  });

  test("has navigation sidebar with Statistics link active", async ({ page }) => {
    await page.goto("/stats");
    await expect(page.getByText("Thingfactory")).toBeVisible();
    const nav = page.locator("nav");
    await expect(
      nav.getByRole("link", { name: /Statistics/ }),
    ).toBeVisible();
  });
});
