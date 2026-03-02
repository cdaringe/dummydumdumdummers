import { expect, test } from "./fixtures";

const MOCK_ORGS = [
  { login: "testuser", avatar_url: "", type: "User" },
  { login: "testorg", avatar_url: "", type: "Organization" },
];

const MOCK_REPOS = [
  { name: "my-app", full_name: "testuser/my-app", default_branch: "main", private: false },
  { name: "my-lib", full_name: "testuser/my-lib", default_branch: "main", private: true },
];

const MOCK_BRANCHES = [
  { name: "main" },
  { name: "develop" },
  { name: "feature/new-thing" },
];

test.describe("GitHub Integrations Page", () => {
  test("loads and shows the integrations page", async ({ page }) => {
    await page.goto("/integrations");
    await expect(page.getByRole("heading", { name: "Integrations" })).toBeVisible();
    await expect(page.getByTestId("gh-token-input")).toBeVisible();
    await expect(page.getByTestId("fetch-orgs-btn")).toBeVisible();
  });

  test("shows empty connections list initially", async ({ page }) => {
    await page.goto("/integrations");
    await expect(page.getByText("No connections registered yet.")).toBeVisible();
  });

  test("sidebar shows Integrations link", async ({ page }) => {
    await page.goto("/");
    await expect(page.getByRole("link", { name: /Integrations/ })).toBeVisible();
  });

  test("cascading dropdowns: org -> repo -> branch selection", async ({ page }) => {
    // Mock GitHub API proxy routes
    await page.route("/api/github/orgs*", (route) => {
      route.fulfill({ json: MOCK_ORGS });
    });
    await page.route("/api/github/repos*", (route) => {
      route.fulfill({ json: MOCK_REPOS });
    });
    await page.route("/api/github/branches*", (route) => {
      route.fulfill({ json: MOCK_BRANCHES });
    });

    await page.goto("/integrations");

    // Enter a token
    await page.getByTestId("gh-token-input").fill("ghp_testtoken123");

    // Click Load Organizations
    await page.getByTestId("fetch-orgs-btn").click();

    // Org dropdown should appear
    await expect(page.getByTestId("gh-org-select")).toBeVisible();

    // Select an org
    await page.getByTestId("gh-org-select").selectOption("testuser");

    // Repo dropdown should appear
    await expect(page.getByTestId("gh-repo-select")).toBeVisible();

    // Select a repo
    await page.getByTestId("gh-repo-select").selectOption("my-app");

    // Branch dropdown should appear
    await expect(page.getByTestId("gh-branch-select")).toBeVisible();

    // Branch should be auto-selected to default (main)
    await expect(page.getByTestId("gh-branch-select")).toHaveValue("main");

    // All branches should be listed
    const branchOptions = page.getByTestId("gh-branch-select").locator("option");
    await expect(branchOptions).toHaveCount(MOCK_BRANCHES.length + 1); // +1 for "— select —"
  });

  test("can select a different branch", async ({ page }) => {
    await page.route("/api/github/orgs*", (route) => {
      route.fulfill({ json: MOCK_ORGS });
    });
    await page.route("/api/github/repos*", (route) => {
      route.fulfill({ json: MOCK_REPOS });
    });
    await page.route("/api/github/branches*", (route) => {
      route.fulfill({ json: MOCK_BRANCHES });
    });

    await page.goto("/integrations");
    await page.getByTestId("gh-token-input").fill("ghp_testtoken123");
    await page.getByTestId("fetch-orgs-btn").click();
    await page.getByTestId("gh-org-select").selectOption("testuser");
    await page.getByTestId("gh-repo-select").selectOption("my-app");

    // Select a different branch
    await page.getByTestId("gh-branch-select").selectOption("develop");
    await expect(page.getByTestId("gh-branch-select")).toHaveValue("develop");
  });

  test("shows pipeline selector after branch selection", async ({ page }) => {
    await page.route("/api/github/orgs*", (route) => {
      route.fulfill({ json: MOCK_ORGS });
    });
    await page.route("/api/github/repos*", (route) => {
      route.fulfill({ json: MOCK_REPOS });
    });
    await page.route("/api/github/branches*", (route) => {
      route.fulfill({ json: MOCK_BRANCHES });
    });

    await page.goto("/integrations");
    await page.getByTestId("gh-token-input").fill("ghp_testtoken123");
    await page.getByTestId("fetch-orgs-btn").click();
    await page.getByTestId("gh-org-select").selectOption("testuser");
    await page.getByTestId("gh-repo-select").selectOption("my-app");

    // Pipeline selector and Register button should appear
    await expect(page.getByTestId("gh-pipeline-select")).toBeVisible();
    await expect(page.getByTestId("register-btn")).toBeVisible();
  });

  test("can register a connection and it appears in the list", async ({ page }) => {
    await page.route("/api/github/orgs*", (route) => {
      route.fulfill({ json: MOCK_ORGS });
    });
    await page.route("/api/github/repos*", (route) => {
      route.fulfill({ json: MOCK_REPOS });
    });
    await page.route("/api/github/branches*", (route) => {
      route.fulfill({ json: MOCK_BRANCHES });
    });

    await page.goto("/integrations");
    await page.getByTestId("gh-token-input").fill("ghp_testtoken123");
    await page.getByTestId("fetch-orgs-btn").click();
    await page.getByTestId("gh-org-select").selectOption("testuser");
    await page.getByTestId("gh-repo-select").selectOption("my-app");
    await page.getByTestId("gh-branch-select").selectOption("main");

    // Click register
    await page.getByTestId("register-btn").click();

    // Success message
    await expect(
      page.getByText(/Registered testuser\/my-app@main successfully/),
    ).toBeVisible();

    // Connection appears in the list
    await expect(page.getByText("testuser/my-app")).toBeVisible();
    await expect(page.locator("table").getByText("main")).toBeVisible();
  });

  test("can delete a registered connection", async ({ page }) => {
    // Pre-seed a connection via the API
    await page.request.post("/api/github/connections", {
      data: {
        token: "ghp_test",
        org: "acme",
        repo: "backend",
        branch: "main",
        pipeline_id: null,
      },
    });

    await page.goto("/integrations");

    // Connection should be in the list
    await expect(page.getByText("acme/backend")).toBeVisible();

    // Click Remove
    await page.getByRole("button", { name: "Remove" }).first().click();

    // Connection should be gone
    await expect(page.getByText("No connections registered yet.")).toBeVisible();
  });
});
