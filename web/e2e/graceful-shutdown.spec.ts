import { expect, test } from "./fixtures";

test.describe("Graceful Shutdown / Drain Mode (Scenario 64)", () => {
  test("new trigger is blocked and recorded as 'blocked' when drain mode is active", async ({
    page,
  }) => {
    // Enter drain mode via admin API
    const drainResp = await page.request.post("/api/admin/drain");
    expect(drainResp.ok()).toBe(true);
    const body = await drainResp.json();
    expect(body.draining).toBe(true);

    // Trigger a pipeline — it should be accepted (redirect) but recorded as blocked
    const triggerResp = await page.request.post(
      "/api/pipelines/basic_example/1.0.0/trigger",
      { maxRedirects: 0 },
    );
    // 303 redirect to the (blocked) run detail page
    expect(triggerResp.status()).toBe(303);
    const location = triggerResp.headers()["location"] ?? "";
    expect(location).toMatch(/\/runs\/[a-f0-9-]+/);

    // Verify the run is recorded with "blocked" status via the API
    const runId = location.split("/runs/")[1];
    const runResp = await page.request.get(`/api/runs/${runId}`);
    expect(runResp.ok()).toBe(true);
    const run = await runResp.json();
    expect(run.status).toBe("blocked");
  });

  test("exits drain mode and allows new triggers after DELETE /api/admin/drain", async ({
    page,
  }) => {
    // Enter then exit drain mode
    await page.request.post("/api/admin/drain");
    const exitResp = await page.request.delete("/api/admin/drain");
    expect(exitResp.ok()).toBe(true);
    const body = await exitResp.json();
    expect(body.draining).toBe(false);

    // Trigger should now create a running (not blocked) run
    const triggerResp = await page.request.post(
      "/api/pipelines/basic_example/1.0.0/trigger",
      { maxRedirects: 0 },
    );
    expect(triggerResp.status()).toBe(303);
    const location = triggerResp.headers()["location"] ?? "";

    // Verify via API that the run is NOT blocked
    const runId = location.split("/runs/")[1];
    const runResp = await page.request.get(`/api/runs/${runId}`);
    expect(runResp.ok()).toBe(true);
    const run = await runResp.json();
    expect(run.status).not.toBe("blocked");
  });

  test("resume-blocked endpoint re-executes blocked runs", async ({ page }) => {
    // Enter drain mode, trigger a pipeline (creates blocked run)
    await page.request.post("/api/admin/drain");
    const triggerResp = await page.request.post(
      "/api/pipelines/basic_example/1.0.0/trigger",
      { maxRedirects: 0 },
    );
    const location = triggerResp.headers()["location"] ?? "";
    const runId = location.split("/runs/")[1];

    // Confirm the run is blocked
    const beforeResp = await page.request.get(`/api/runs/${runId}`);
    expect((await beforeResp.json()).status).toBe("blocked");

    // Exit drain mode so resumed runs can execute
    await page.request.delete("/api/admin/drain");

    // Simulate server restart recovery: resume blocked runs
    const resumeResp = await page.request.post("/api/admin/resume-blocked");
    expect(resumeResp.ok()).toBe(true);

    // After resuming, the run transitions away from "blocked"
    const afterResp = await page.request.get(`/api/runs/${runId}`);
    expect(afterResp.ok()).toBe(true);
    const afterRun = await afterResp.json();
    expect(afterRun.status).not.toBe("blocked");
  });

  test("resume-blocked endpoint succeeds with no blocked or running runs", async ({
    page,
  }) => {
    // Fresh DB (after reset) has no blocked or orphaned running runs.
    // The endpoint should succeed without error.
    const resp = await page.request.post("/api/admin/resume-blocked");
    expect(resp.ok()).toBe(true);
    const body = await resp.json();
    expect(body.ok).toBe(true);
  });
});
