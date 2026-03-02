import { expect, test } from "./fixtures";

// Pipeline ID used from seed fixtures
const SEED_PIPELINE_ID = "basic_example@1.0.0";

test.describe("GitHub webhook receiver", () => {
  test("returns 400 when payload is missing required fields", async ({ page }) => {
    const res = await page.request.post("/api/webhooks/github", {
      data: {},
    });
    expect(res.status()).toBe(400);
  });

  test("returns 0 triggered when no matching connection exists", async ({ page }) => {
    const res = await page.request.post("/api/webhooks/github", {
      data: {
        ref: "refs/heads/main",
        repository: { name: "nonexistent-repo", owner: { login: "nobody" } },
      },
    });
    expect(res.status()).toBe(200);
    const body = await res.json();
    expect(body.ok).toBe(true);
    expect(body.triggered).toBe(0);
  });

  test("triggers pipeline when matching connection with pipeline_id exists", async ({ page }) => {
    // Create a connection linked to a seed pipeline
    await page.request.post("/api/github/connections", {
      data: {
        token: "ghp_test",
        org: "acme",
        repo: "backend",
        branch: "main",
        pipeline_id: SEED_PIPELINE_ID,
      },
    });

    const res = await page.request.post("/api/webhooks/github", {
      data: {
        ref: "refs/heads/main",
        repository: { name: "backend", owner: { login: "acme" } },
      },
    });

    expect(res.status()).toBe(200);
    const body = await res.json();
    expect(body.ok).toBe(true);
    expect(body.triggered).toBe(1);
    expect(body.run_ids).toHaveLength(1);
  });

  test("does not trigger when branch does not match", async ({ page }) => {
    await page.request.post("/api/github/connections", {
      data: {
        token: "ghp_test",
        org: "acme",
        repo: "backend",
        branch: "main",
        pipeline_id: SEED_PIPELINE_ID,
      },
    });

    const res = await page.request.post("/api/webhooks/github", {
      data: {
        ref: "refs/heads/develop",
        repository: { name: "backend", owner: { login: "acme" } },
      },
    });

    expect(res.status()).toBe(200);
    const body = await res.json();
    expect(body.triggered).toBe(0);
  });

  test("does not trigger connection without a linked pipeline", async ({ page }) => {
    await page.request.post("/api/github/connections", {
      data: {
        token: "ghp_test",
        org: "acme",
        repo: "unlinked",
        branch: "main",
        pipeline_id: null,
      },
    });

    const res = await page.request.post("/api/webhooks/github", {
      data: {
        ref: "refs/heads/main",
        repository: { name: "unlinked", owner: { login: "acme" } },
      },
    });

    expect(res.status()).toBe(200);
    const body = await res.json();
    expect(body.triggered).toBe(0);
  });
});

test.describe("Gitea webhook receiver", () => {
  test("returns 400 when payload is missing required fields", async ({ page }) => {
    const res = await page.request.post("/api/webhooks/gitea", {
      data: {},
    });
    expect(res.status()).toBe(400);
  });

  test("returns 0 triggered when no matching connection exists", async ({ page }) => {
    const res = await page.request.post("/api/webhooks/gitea", {
      data: {
        ref: "refs/heads/main",
        repository: { full_name: "nobody/nonexistent" },
      },
    });
    expect(res.status()).toBe(200);
    const body = await res.json();
    expect(body.ok).toBe(true);
    expect(body.triggered).toBe(0);
  });

  test("triggers pipeline when matching connection with pipeline_id exists", async ({ page }) => {
    await page.request.post("/api/gitea/connections", {
      data: {
        url: "https://gitea.example.com",
        token: "tok-test",
        repo: "acme/service",
        branch: "main",
        pipeline_id: SEED_PIPELINE_ID,
      },
    });

    const res = await page.request.post("/api/webhooks/gitea", {
      data: {
        ref: "refs/heads/main",
        repository: { full_name: "acme/service" },
      },
    });

    expect(res.status()).toBe(200);
    const body = await res.json();
    expect(body.ok).toBe(true);
    expect(body.triggered).toBe(1);
    expect(body.run_ids).toHaveLength(1);
  });

  test("does not trigger when branch does not match", async ({ page }) => {
    await page.request.post("/api/gitea/connections", {
      data: {
        url: "https://gitea.example.com",
        token: "tok-test",
        repo: "acme/service",
        branch: "main",
        pipeline_id: SEED_PIPELINE_ID,
      },
    });

    const res = await page.request.post("/api/webhooks/gitea", {
      data: {
        ref: "refs/heads/feature-x",
        repository: { full_name: "acme/service" },
      },
    });

    expect(res.status()).toBe(200);
    const body = await res.json();
    expect(body.triggered).toBe(0);
  });

  test("does not trigger connection without a linked pipeline", async ({ page }) => {
    await page.request.post("/api/gitea/connections", {
      data: {
        url: "https://gitea.example.com",
        token: "tok-test",
        repo: "acme/unlinked",
        branch: "main",
        pipeline_id: null,
      },
    });

    const res = await page.request.post("/api/webhooks/gitea", {
      data: {
        ref: "refs/heads/main",
        repository: { full_name: "acme/unlinked" },
      },
    });

    expect(res.status()).toBe(200);
    const body = await res.json();
    expect(body.triggered).toBe(0);
  });
});
