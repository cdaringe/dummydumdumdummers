import { NextRequest, NextResponse } from "next/server";

export const dynamic = "force-dynamic";

export async function GET(req: NextRequest) {
  const token = req.nextUrl.searchParams.get("token");
  const url = req.nextUrl.searchParams.get("url");

  if (!token || !url) {
    return NextResponse.json(
      { error: "token and url required" },
      { status: 400 },
    );
  }

  const base = url.replace(/\/$/, "");
  const headers = {
    Authorization: `token ${token}`,
    "Content-Type": "application/json",
  };

  const res = await fetch(
    `${base}/api/v1/repos/search?limit=50&sort=newest`,
    { headers },
  );

  if (!res.ok) {
    return NextResponse.json(
      { error: "Gitea API error" },
      { status: res.status },
    );
  }

  const body = await res.json();
  const repos = (body.data ?? body) as any[];
  const result = repos.map((r: any) => ({
    name: r.name,
    full_name: r.full_name,
    default_branch: r.default_branch,
    private: r.private,
  }));

  return NextResponse.json(result);
}
