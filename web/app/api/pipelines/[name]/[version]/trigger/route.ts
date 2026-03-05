import { NextResponse } from "next/server";
import { triggerPipeline } from "@/lib/trigger-pipeline";

export const dynamic = "force-dynamic";

type Params = { params: Promise<{ name: string; version: string }> };

export async function POST(req: Request, { params }: Params) {
  const { name, version } = await params;
  const pipelineId = `${name}@${version}`;

  let runId: string | null;
  try {
    runId = await triggerPipeline(pipelineId, "manual");
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    return NextResponse.json({ error: msg }, { status: 403 });
  }

  if (!runId) {
    return NextResponse.json({ error: "Pipeline not found" }, { status: 404 });
  }

  const url = new URL(`/runs/${runId}`, req.url);
  return NextResponse.redirect(url, 303);
}
