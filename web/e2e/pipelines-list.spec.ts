import { test, expect } from "./fixtures";

test.describe("Pipelines List", () => {
  test("loads and shows pipeline table", async ({ page }) => {
    await page.goto("/pipelines");
    await expect(page.getByRole("heading", { name: "Pipelines" })).toBeVisible();
    await expect(page.locator("table")).toBeVisible();
  });

  test("shows at least 24 seeded pipelines", async ({ page }) => {
    await page.goto("/pipelines");
    const rows = page.locator("table tbody tr");
    const count = await rows.count();
    expect(count).toBeGreaterThanOrEqual(24);
  });

  test("each row has a pipeline name link", async ({ page }) => {
    await page.goto("/pipelines");
    const firstRow = page.locator("table tbody tr").first();
    const link = firstRow.locator("a").first();
    await expect(link).toBeVisible();
    const href = await link.getAttribute("href");
    expect(href).toContain("/pipelines/");
  });

  test("clicking a pipeline navigates to detail page", async ({ page }) => {
    await page.goto("/pipelines");
    await page.locator("table tbody tr").first().locator("a").first().click();
    await page.waitForLoadState("networkidle");
    await expect(page.url()).toContain("/pipelines/");
    await expect(page.locator("h1")).toBeVisible();
  });

  test("shows last run status in table", async ({ page }) => {
    await page.goto("/pipelines");
    // Should show at least one status badge (seeded runs exist)
    const badges = page.locator("table tbody tr td").filter({ hasText: /Success|Failed|Running/ });
    const count = await badges.count();
    expect(count).toBeGreaterThan(0);
  });

  test("has trigger run button per row", async ({ page }) => {
    await page.goto("/pipelines");
    const triggerButtons = page.locator("button", { hasText: "▶ Run" });
    const count = await triggerButtons.count();
    expect(count).toBeGreaterThan(0);
  });

  test("shows schedule information", async ({ page }) => {
    await page.goto("/pipelines");
    // Several pipelines have schedules - at least one should show non-"On demand"
    // Look for schedule info in table cells
    const scheduleCell = page.locator("table tbody tr td").filter({ hasText: /Daily at|Weekly on|Monthly|Every|Cron/ }).first();
    await expect(scheduleCell).toBeVisible();
  });
});
