import { NextRequest, NextResponse } from "next/server";

export const dynamic = "force-dynamic";

export async function GET(req: NextRequest) {
  const token = req.nextUrl.searchParams.get("token");
  const url = req.nextUrl.searchParams.get("url");
  const repo = req.nextUrl.searchParams.get("repo");

  if (!token || !url || !repo) {
    return NextResponse.json(
      { error: "token, url, and repo required" },
      { status: 400 },
    );
  }

  const base = url.replace(/\/$/, "");
  const headers = {
    Authorization: `token ${token}`,
    "Content-Type": "application/json",
  };

  const res = await fetch(
    `${base}/api/v1/repos/${repo}/branches?limit=100`,
    { headers },
  );

  if (!res.ok) {
    return NextResponse.json(
      { error: "Gitea API error" },
      { status: res.status },
    );
  }

  const branches = await res.json();
  return NextResponse.json(
    (branches as any[]).map((b: any) => ({ name: b.name })),
  );
}
