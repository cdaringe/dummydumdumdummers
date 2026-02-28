import { test as base } from "@playwright/test";

/**
 * Custom Playwright test fixture that performs a deep DB reset before each test.
 * The server runs with DATABASE_PATH=:memory: (in-memory SQLite), and this
 * fixture calls POST /api/test/reset to clear all tables and re-seed with
 * fixture data, ensuring full test isolation.
 */
export const test = base.extend({
  page: async ({ page }, use) => {
    // Deep DB reset: clear all data and re-seed before each test
    const response = await page.request.post("/api/test/reset");
    if (!response.ok()) {
      throw new Error(
        `DB reset failed: ${response.status()} ${await response.text()}`
      );
    }
    await use(page);
  },
});

export { expect } from "@playwright/test";
