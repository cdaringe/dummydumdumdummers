import { expect, test } from "./fixtures";

const MOCK_REPOS = [
  {
    name: "my-service",
    full_name: "alice/my-service",
    default_branch: "main",
    private: false,
  },
  {
    name: "private-lib",
    full_name: "alice/private-lib",
    default_branch: "master",
    private: true,
  },
];

const MOCK_BRANCHES = [
  { name: "main" },
  { name: "develop" },
  { name: "feature/auth" },
];

test.describe("Gitea Integrations", () => {
  test("shows Gitea form on integrations page", async ({ page }) => {
    await page.goto("/integrations");
    await expect(page.getByRole("heading", { name: "Integrations" }))
      .toBeVisible();
    await expect(page.getByTestId("gitea-url-input")).toBeVisible();
    await expect(page.getByTestId("gitea-token-input")).toBeVisible();
    await expect(page.getByTestId("fetch-gitea-repos-btn")).toBeVisible();
  });

  test("shows empty Gitea connections initially", async ({ page }) => {
    await page.goto("/integrations");
    await expect(page.getByTestId("gitea-empty-state")).toBeVisible();
  });

  test("cascading dropdowns: repo -> branch after loading repos", async ({ page }) => {
    await page.route("/api/gitea/repos*", (route) => {
      route.fulfill({ json: MOCK_REPOS });
    });
    await page.route("/api/gitea/branches*", (route) => {
      route.fulfill({ json: MOCK_BRANCHES });
    });

    await page.goto("/integrations");

    // Fill in the Gitea instance URL and token
    await page.getByTestId("gitea-url-input").fill(
      "https://gitea.example.com",
    );
    await page.getByTestId("gitea-token-input").fill("gitea-token-abc123");

    // Click Load Repositories
    await page.getByTestId("fetch-gitea-repos-btn").click();

    // Repo dropdown should appear
    await expect(page.getByTestId("gitea-repo-select")).toBeVisible();

    // Select a repo
    await page.getByTestId("gitea-repo-select").selectOption(
      "alice/my-service",
    );

    // Branch dropdown should appear
    await expect(page.getByTestId("gitea-branch-select")).toBeVisible();

    // Branch should be pre-selected to default_branch (main)
    await expect(page.getByTestId("gitea-branch-select")).toHaveValue("main");

    // All branches should be listed
    const branchOptions = page.getByTestId("gitea-branch-select").locator(
      "option",
    );
    await expect(branchOptions).toHaveCount(MOCK_BRANCHES.length + 1); // +1 for "— select —"
  });

  test("can select a non-default branch", async ({ page }) => {
    await page.route("/api/gitea/repos*", (route) => {
      route.fulfill({ json: MOCK_REPOS });
    });
    await page.route("/api/gitea/branches*", (route) => {
      route.fulfill({ json: MOCK_BRANCHES });
    });

    await page.goto("/integrations");
    await page.getByTestId("gitea-url-input").fill("https://gitea.example.com");
    await page.getByTestId("gitea-token-input").fill("gitea-token-abc123");
    await page.getByTestId("fetch-gitea-repos-btn").click();
    await page.getByTestId("gitea-repo-select").selectOption(
      "alice/my-service",
    );

    await page.getByTestId("gitea-branch-select").selectOption("develop");
    await expect(page.getByTestId("gitea-branch-select")).toHaveValue(
      "develop",
    );
  });

  test("shows pipeline selector and register button after branch selection", async ({ page }) => {
    await page.route("/api/gitea/repos*", (route) => {
      route.fulfill({ json: MOCK_REPOS });
    });
    await page.route("/api/gitea/branches*", (route) => {
      route.fulfill({ json: MOCK_BRANCHES });
    });

    await page.goto("/integrations");
    await page.getByTestId("gitea-url-input").fill("https://gitea.example.com");
    await page.getByTestId("gitea-token-input").fill("gitea-token-abc123");
    await page.getByTestId("fetch-gitea-repos-btn").click();
    await page.getByTestId("gitea-repo-select").selectOption(
      "alice/my-service",
    );

    await expect(page.getByTestId("gitea-pipeline-select")).toBeVisible();
    await expect(page.getByTestId("gitea-register-btn")).toBeVisible();
  });

  test("can register a Gitea connection and it appears in the list", async ({ page }) => {
    await page.route("/api/gitea/repos*", (route) => {
      route.fulfill({ json: MOCK_REPOS });
    });
    await page.route("/api/gitea/branches*", (route) => {
      route.fulfill({ json: MOCK_BRANCHES });
    });

    await page.goto("/integrations");
    await page.getByTestId("gitea-url-input").fill("https://gitea.example.com");
    await page.getByTestId("gitea-token-input").fill("gitea-token-abc123");
    await page.getByTestId("fetch-gitea-repos-btn").click();
    await page.getByTestId("gitea-repo-select").selectOption(
      "alice/my-service",
    );
    await page.getByTestId("gitea-branch-select").selectOption("main");

    await page.getByTestId("gitea-register-btn").click();

    // Success message
    await expect(
      page.getByText(/Registered alice\/my-service@main successfully/),
    ).toBeVisible();

    // Connection appears in the table
    await expect(page.getByText("alice/my-service")).toBeVisible();
  });

  test("can delete a registered Gitea connection", async ({ page }) => {
    // Pre-seed a connection via the API
    await page.request.post("/api/gitea/connections", {
      data: {
        url: "https://gitea.myorg.com",
        token: "tok-test",
        repo: "org/backend",
        branch: "main",
        pipeline_id: null,
      },
    });

    await page.goto("/integrations");

    // Connection should be visible
    await expect(page.getByText("org/backend")).toBeVisible();

    // Click Remove (Gitea connections section)
    const removeButtons = page.getByRole("button", { name: "Remove" });
    await removeButtons.last().click();

    // Connection should be gone
    await expect(page.getByTestId("gitea-empty-state")).toBeVisible();
  });
});
