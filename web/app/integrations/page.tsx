"use client";

import { useCallback, useEffect, useState } from "react";

interface GitHubOrg {
  login: string;
  avatar_url: string;
  type: "User" | "Organization";
}

interface GitHubRepo {
  name: string;
  full_name: string;
  default_branch: string;
  private: boolean;
}

interface GitHubBranch {
  name: string;
}

interface GitHubConnection {
  id: string;
  org: string;
  repo: string;
  branch: string;
  pipeline_id: string | null;
  created_at: string;
}

interface Pipeline {
  id: string;
  name: string;
  version: string;
}

export default function IntegrationsPage() {
  const [connections, setConnections] = useState<GitHubConnection[]>([]);
  const [pipelines, setPipelines] = useState<Pipeline[]>([]);

  // Form state
  const [token, setToken] = useState("");
  const [orgs, setOrgs] = useState<GitHubOrg[]>([]);
  const [selectedOrg, setSelectedOrg] = useState<GitHubOrg | null>(null);
  const [repos, setRepos] = useState<GitHubRepo[]>([]);
  const [selectedRepo, setSelectedRepo] = useState<GitHubRepo | null>(null);
  const [branches, setBranches] = useState<GitHubBranch[]>([]);
  const [selectedBranch, setSelectedBranch] = useState("");
  const [selectedPipeline, setSelectedPipeline] = useState("");

  // Loading/error state
  const [loadingOrgs, setLoadingOrgs] = useState(false);
  const [loadingRepos, setLoadingRepos] = useState(false);
  const [loadingBranches, setLoadingBranches] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");

  const loadConnections = useCallback(async () => {
    const res = await fetch("/api/github/connections");
    if (res.ok) setConnections(await res.json());
  }, []);

  useEffect(() => {
    loadConnections();
    fetch("/api/pipelines")
      .then((r) => r.json())
      .then((data: any[]) =>
        setPipelines(data.map((p) => ({ id: p.id, name: p.name, version: p.version })))
      )
      .catch(() => {});
  }, [loadConnections]);

  const fetchOrgs = async () => {
    if (!token.trim()) {
      setError("Please enter a GitHub token.");
      return;
    }
    setError("");
    setSuccess("");
    setLoadingOrgs(true);
    setOrgs([]);
    setSelectedOrg(null);
    setRepos([]);
    setSelectedRepo(null);
    setBranches([]);
    setSelectedBranch("");
    try {
      const res = await fetch(
        `/api/github/orgs?token=${encodeURIComponent(token)}`,
      );
      if (!res.ok) {
        setError("Failed to fetch organizations. Check your token.");
        return;
      }
      const data: GitHubOrg[] = await res.json();
      setOrgs(data);
    } catch {
      setError("Network error fetching organizations.");
    } finally {
      setLoadingOrgs(false);
    }
  };

  const onOrgChange = async (login: string) => {
    const org = orgs.find((o) => o.login === login) ?? null;
    setSelectedOrg(org);
    setSelectedRepo(null);
    setRepos([]);
    setBranches([]);
    setSelectedBranch("");
    if (!org) return;

    setLoadingRepos(true);
    try {
      const res = await fetch(
        `/api/github/repos?token=${encodeURIComponent(token)}&org=${encodeURIComponent(org.login)}&type=${org.type}`,
      );
      if (res.ok) setRepos(await res.json());
    } finally {
      setLoadingRepos(false);
    }
  };

  const onRepoChange = async (repoName: string) => {
    const repo = repos.find((r) => r.name === repoName) ?? null;
    setSelectedRepo(repo);
    setBranches([]);
    setSelectedBranch("");
    if (!repo || !selectedOrg) return;

    setLoadingBranches(true);
    try {
      const res = await fetch(
        `/api/github/branches?token=${encodeURIComponent(token)}&org=${encodeURIComponent(selectedOrg.login)}&repo=${encodeURIComponent(repo.name)}`,
      );
      if (res.ok) {
        const data: GitHubBranch[] = await res.json();
        setBranches(data);
        setSelectedBranch(repo.default_branch);
      }
    } finally {
      setLoadingBranches(false);
    }
  };

  const saveConnection = async () => {
    if (!selectedOrg || !selectedRepo || !selectedBranch) {
      setError("Please select an organization, repository, and branch.");
      return;
    }
    setSaving(true);
    setError("");
    setSuccess("");
    try {
      const res = await fetch("/api/github/connections", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          token,
          org: selectedOrg.login,
          repo: selectedRepo.name,
          branch: selectedBranch,
          pipeline_id: selectedPipeline || null,
        }),
      });
      if (!res.ok) {
        setError("Failed to save connection.");
        return;
      }
      setSuccess(
        `Registered ${selectedOrg.login}/${selectedRepo.name}@${selectedBranch} successfully.`,
      );
      // Reset form
      setToken("");
      setOrgs([]);
      setSelectedOrg(null);
      setRepos([]);
      setSelectedRepo(null);
      setBranches([]);
      setSelectedBranch("");
      setSelectedPipeline("");
      await loadConnections();
    } finally {
      setSaving(false);
    }
  };

  const deleteConnection = async (id: string) => {
    await fetch(`/api/github/connections/${id}`, { method: "DELETE" });
    await loadConnections();
  };

  const labelStyle: React.CSSProperties = {
    display: "block",
    fontSize: "var(--font-size-sm)",
    color: "var(--color-gray-500)",
    marginBottom: "var(--spacing-xs)",
    fontWeight: 500,
  };

  const inputStyle: React.CSSProperties = {
    width: "100%",
    padding: "var(--spacing-sm) var(--spacing-md)",
    background: "var(--color-gray-900)",
    border: "1px solid var(--color-gray-700)",
    borderRadius: "var(--border-radius-md)",
    color: "var(--color-gray-100)",
    fontSize: "var(--font-size-base)",
    fontFamily: "monospace",
  };

  const selectStyle: React.CSSProperties = {
    ...inputStyle,
    cursor: "pointer",
  };

  const fieldStyle: React.CSSProperties = {
    marginBottom: "var(--spacing-lg)",
  };

  return (
    <div>
      <div className="page-header">
        <h1>Integrations</h1>
        <p>Connect GitHub repositories to pipeline triggers.</p>
      </div>

      {/* GitHub Connection Form */}
      <div className="card" style={{ marginBottom: "var(--spacing-xl)" }}>
        <h2
          style={{
            fontSize: "var(--font-size-lg)",
            fontWeight: 600,
            marginBottom: "var(--spacing-lg)",
            color: "var(--color-gray-200)",
          }}
        >
          Connect GitHub Repository
        </h2>

        {error && (
          <div
            style={{
              padding: "var(--spacing-md)",
              marginBottom: "var(--spacing-lg)",
              background: "var(--color-status-failed-bg, #1a0505)",
              border: "1px solid var(--color-status-failed)",
              borderRadius: "var(--border-radius-md)",
              color: "var(--color-status-failed)",
              fontSize: "var(--font-size-sm)",
            }}
          >
            {error}
          </div>
        )}

        {success && (
          <div
            style={{
              padding: "var(--spacing-md)",
              marginBottom: "var(--spacing-lg)",
              background: "var(--color-status-ok-bg, #051a0a)",
              border: "1px solid var(--color-status-ok)",
              borderRadius: "var(--border-radius-md)",
              color: "var(--color-status-ok)",
              fontSize: "var(--font-size-sm)",
            }}
          >
            {success}
          </div>
        )}

        {/* Step 1: Token */}
        <div style={fieldStyle}>
          <label style={labelStyle} htmlFor="gh-token">
            GitHub Personal Access Token
          </label>
          <div style={{ display: "flex", gap: "var(--spacing-md)" }}>
            <input
              id="gh-token"
              type="password"
              value={token}
              onChange={(e) => setToken(e.target.value)}
              placeholder="ghp_..."
              style={{ ...inputStyle, flex: 1 }}
              aria-label="GitHub token"
              data-testid="gh-token-input"
            />
            <button
              onClick={fetchOrgs}
              disabled={loadingOrgs}
              className="btn btn-primary"
              data-testid="fetch-orgs-btn"
            >
              {loadingOrgs ? "Loading…" : "Load Organizations"}
            </button>
          </div>
          <p
            style={{
              marginTop: "var(--spacing-xs)",
              fontSize: "var(--font-size-xs)",
              color: "var(--color-gray-600)",
            }}
          >
            Requires{" "}
            <code>repo</code> scope. Token is stored locally and used only to
            proxy GitHub API calls.
          </p>
        </div>

        {/* Step 2: Organization */}
        {orgs.length > 0 && (
          <div style={fieldStyle}>
            <label style={labelStyle} htmlFor="gh-org">
              Organization / Account
            </label>
            <select
              id="gh-org"
              value={selectedOrg?.login ?? ""}
              onChange={(e) => onOrgChange(e.target.value)}
              style={selectStyle}
              data-testid="gh-org-select"
            >
              <option value="">— select —</option>
              {orgs.map((o) => (
                <option key={o.login} value={o.login}>
                  {o.login} ({o.type})
                </option>
              ))}
            </select>
          </div>
        )}

        {/* Step 3: Repository */}
        {selectedOrg && (
          <div style={fieldStyle}>
            <label style={labelStyle} htmlFor="gh-repo">
              Repository
              {loadingRepos && (
                <span
                  style={{ marginLeft: "var(--spacing-sm)", fontWeight: 400 }}
                >
                  loading…
                </span>
              )}
            </label>
            <select
              id="gh-repo"
              value={selectedRepo?.name ?? ""}
              onChange={(e) => onRepoChange(e.target.value)}
              disabled={loadingRepos}
              style={selectStyle}
              data-testid="gh-repo-select"
            >
              <option value="">— select —</option>
              {repos.map((r) => (
                <option key={r.name} value={r.name}>
                  {r.name}
                  {r.private ? " [private]" : ""}
                </option>
              ))}
            </select>
          </div>
        )}

        {/* Step 4: Branch (autopopulated) */}
        {selectedRepo && (
          <div style={fieldStyle}>
            <label style={labelStyle} htmlFor="gh-branch">
              Branch
              {loadingBranches && (
                <span
                  style={{ marginLeft: "var(--spacing-sm)", fontWeight: 400 }}
                >
                  loading…
                </span>
              )}
            </label>
            <select
              id="gh-branch"
              value={selectedBranch}
              onChange={(e) => setSelectedBranch(e.target.value)}
              disabled={loadingBranches}
              style={selectStyle}
              data-testid="gh-branch-select"
            >
              <option value="">— select —</option>
              {branches.map((b) => (
                <option key={b.name} value={b.name}>
                  {b.name}
                  {b.name === selectedRepo.default_branch ? " (default)" : ""}
                </option>
              ))}
            </select>
          </div>
        )}

        {/* Step 5: Link to Pipeline (optional) */}
        {selectedBranch && (
          <div style={fieldStyle}>
            <label style={labelStyle} htmlFor="gh-pipeline">
              Link to Pipeline (optional)
            </label>
            <select
              id="gh-pipeline"
              value={selectedPipeline}
              onChange={(e) => setSelectedPipeline(e.target.value)}
              style={selectStyle}
              data-testid="gh-pipeline-select"
            >
              <option value="">— none —</option>
              {pipelines.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.name} v{p.version}
                </option>
              ))}
            </select>
            <p
              style={{
                marginTop: "var(--spacing-xs)",
                fontSize: "var(--font-size-xs)",
                color: "var(--color-gray-600)",
              }}
            >
              When linked, push events to this branch will trigger the selected
              pipeline.
            </p>
          </div>
        )}

        {/* Register button */}
        {selectedBranch && (
          <button
            onClick={saveConnection}
            disabled={saving}
            className="btn btn-primary"
            data-testid="register-btn"
          >
            {saving ? "Registering…" : "Register Connection"}
          </button>
        )}
      </div>

      {/* Existing Connections */}
      <div className="card">
        <h2
          style={{
            fontSize: "var(--font-size-lg)",
            fontWeight: 600,
            marginBottom: "var(--spacing-lg)",
            color: "var(--color-gray-200)",
          }}
        >
          Registered Connections
        </h2>

        {connections.length === 0
          ? (
            <p
              style={{
                color: "var(--color-gray-600)",
                fontSize: "var(--font-size-sm)",
              }}
            >
              No connections registered yet.
            </p>
          )
          : (
            <table>
              <thead>
                <tr>
                  <th>Repository</th>
                  <th>Branch</th>
                  <th>Pipeline</th>
                  <th>Registered</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {connections.map((c) => (
                  <tr key={c.id}>
                    <td style={{ fontFamily: "monospace" }}>
                      {c.org}/{c.repo}
                    </td>
                    <td style={{ fontFamily: "monospace" }}>{c.branch}</td>
                    <td style={{ color: "var(--color-gray-500)" }}>
                      {c.pipeline_id ?? "—"}
                    </td>
                    <td
                      style={{
                        color: "var(--color-gray-500)",
                        fontSize: "var(--font-size-sm)",
                      }}
                    >
                      {new Date(c.created_at).toLocaleString()}
                    </td>
                    <td>
                      <button
                        onClick={() => deleteConnection(c.id)}
                        className="btn btn-sm"
                        style={{
                          background: "transparent",
                          color: "var(--color-status-failed)",
                          border: "1px solid var(--color-status-failed)",
                        }}
                        data-testid={`delete-connection-${c.id}`}
                      >
                        Remove
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
      </div>
    </div>
  );
}
