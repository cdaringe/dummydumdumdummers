import { NextRequest, NextResponse } from "next/server";

export const dynamic = "force-dynamic";

export async function GET(req: NextRequest) {
  const token = req.nextUrl.searchParams.get("token");
  const org = req.nextUrl.searchParams.get("org");
  const type = req.nextUrl.searchParams.get("type") ?? "Organization";

  if (!token || !org) {
    return NextResponse.json(
      { error: "token and org required" },
      { status: 400 },
    );
  }

  const headers = {
    Authorization: `Bearer ${token}`,
    Accept: "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
    "User-Agent": "thingfactory",
  };

  const url = type === "User"
    ? `https://api.github.com/users/${encodeURIComponent(org)}/repos?per_page=100&sort=updated`
    : `https://api.github.com/orgs/${encodeURIComponent(org)}/repos?per_page=100&sort=updated`;

  const res = await fetch(url, { headers });
  if (!res.ok) {
    return NextResponse.json(
      { error: "GitHub API error" },
      { status: res.status },
    );
  }

  const repos = await res.json();
  const result = repos.map((r: any) => ({
    name: r.name,
    full_name: r.full_name,
    default_branch: r.default_branch,
    private: r.private,
  }));

  return NextResponse.json(result);
}
