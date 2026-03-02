import { NextRequest, NextResponse } from "next/server";

export const dynamic = "force-dynamic";

export async function GET(req: NextRequest) {
  const token = req.nextUrl.searchParams.get("token");
  if (!token) {
    return NextResponse.json({ error: "token required" }, { status: 400 });
  }

  const headers = {
    Authorization: `Bearer ${token}`,
    Accept: "application/vnd.github+json",
    "X-GitHub-Api-Version": "2022-11-28",
    "User-Agent": "thingfactory",
  };

  // Fetch authenticated user
  const userRes = await fetch("https://api.github.com/user", { headers });
  if (!userRes.ok) {
    return NextResponse.json(
      { error: "Invalid token or GitHub API error" },
      { status: userRes.status },
    );
  }
  const user = await userRes.json();

  // Fetch orgs the user belongs to
  const orgsRes = await fetch("https://api.github.com/user/orgs?per_page=100", {
    headers,
  });
  const orgs = orgsRes.ok ? await orgsRes.json() : [];

  // Include the user itself as a selectable "org" (personal repos)
  const all = [
    { login: user.login, avatar_url: user.avatar_url, type: "User" },
    ...orgs.map((o: any) => ({
      login: o.login,
      avatar_url: o.avatar_url,
      type: "Organization",
    })),
  ];

  return NextResponse.json(all);
}
