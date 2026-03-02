import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  workers: 1,
  reporter: "list",
  use: {
    baseURL: "http://localhost:3000",
    trace: "on-first-retry",
    video: "on",
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] },
    },
  ],
  webServer: {
    // dev:e2e skips the predev db:setup hook so the server can manage its own
    // in-memory DB initialization (auto-migrated and auto-seeded in db.ts).
    command: "npm run dev:e2e",
    url: "http://localhost:3000/api/health",
    reuseExistingServer: !process.env.CI,
    timeout: 60000,
    env: {
      THINGFACTORY_DATABASE_PATH: ":memory:",
    },
  },
});
