import { db } from "@/lib/db";
import { NextRequest, NextResponse } from "next/server";

type Props = { params: Promise<{ id: string }> };

export async function GET(req: NextRequest, { params }: Props) {
  const { id } = await params;

  try {
    const artifact = await db
      .selectFrom("artifacts")
      .selectAll()
      .where("id", "=", id)
      .executeTakeFirst();

    if (!artifact) {
      return NextResponse.json({ error: "Artifact not found" }, { status: 404 });
    }

    // Return as downloadable file
    return new NextResponse(artifact.content, {
      headers: {
        "Content-Type": "application/octet-stream",
        "Content-Disposition": `attachment; filename="${artifact.name}"`,
      },
    });
  } catch (error) {
    return NextResponse.json(
      { error: "Failed to fetch artifact" },
      { status: 500 }
    );
  }
}
