import { NextRequest, NextResponse } from "next/server";

export const dynamic = "force-dynamic";

export async function GET(req: NextRequest) {
  const token = req.nextUrl.searchParams.get("token");
  const org = req.nextUrl.searchParams.get("org");
  const repo = req.nextUrl.searchParams.get("repo");

  if (!token || !org || !repo) {
    return NextResponse.json(
      { error: "token, org, and repo required" },
      { status: 400 },
    );
  }

  const headers = {
    Authorization: `Bearer ${token}`,
    Accept: "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
    "User-Agent": "thingfactory",
  };

  const url = `https://api.github.com/repos/${encodeURIComponent(org)}/${
    encodeURIComponent(repo)
  }/branches?per_page=100`;
  const res = await fetch(url, { headers });
  if (!res.ok) {
    return NextResponse.json(
      { error: "GitHub API error" },
      { status: res.status },
    );
  }

  const branches = await res.json();
  return NextResponse.json(branches.map((b: any) => ({ name: b.name })));
}
