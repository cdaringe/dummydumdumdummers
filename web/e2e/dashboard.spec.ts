import { test, expect } from "./fixtures";

test.describe("Dashboard", () => {
  test("loads and shows pipeline stats", async ({ page }) => {
    await page.goto("/");
    await expect(page.getByRole("heading", { name: "Dashboard" })).toBeVisible();
  });

  test("shows stat cards", async ({ page }) => {
    await page.goto("/");
    await expect(page.getByText("Total Pipelines")).toBeVisible();
    await expect(page.getByText("Total Runs")).toBeVisible();
    await expect(page.getByText("Successful Runs")).toBeVisible();
    await expect(page.getByText("Failed Runs")).toBeVisible();
  });

  test("shows recent runs table", async ({ page }) => {
    await page.goto("/");
    await expect(page.getByRole("heading", { name: "Recent Runs" })).toBeVisible();
    // Seeded data should populate at least one row
    const rows = page.locator("table tbody tr");
    await expect(rows.first()).toBeVisible();
  });

  test("navigates to pipeline detail from recent runs", async ({ page }) => {
    await page.goto("/");
    const pipelineLink = page.locator("table tbody tr").first().locator("a").first();
    await pipelineLink.click();
    await page.waitForLoadState("networkidle");
    await expect(page.url()).toContain("/pipelines/");
  });

  test("navigates to run detail from recent runs", async ({ page }) => {
    await page.goto("/");
    const detailLink = page.locator("text=Details →").first();
    await detailLink.click();
    await page.waitForLoadState("networkidle");
    await expect(page.url()).toContain("/runs/");
  });

  test("has navigation sidebar with correct links", async ({ page }) => {
    await page.goto("/");
    // Check sidebar title
    await expect(page.getByText("Thingfactory")).toBeVisible();
    // Check sidebar links specifically (in the nav element)
    const nav = page.locator("nav");
    await expect(nav.getByRole("link", { name: /Pipelines/ })).toBeVisible();
    await expect(nav.getByRole("link", { name: /Runs/ })).toBeVisible();
    await expect(nav.getByRole("link", { name: /Statistics/ })).toBeVisible();
  });
});
