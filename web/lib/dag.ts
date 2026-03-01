import type { Edge, Node } from "@xyflow/react";
import type { LoopConfig, StepDefinition } from "./types";

export interface StepNodeData {
  label: string;
  status: string;
  duration_ms?: number;
  loop?: LoopConfig;
  [key: string]: unknown;
}

export interface DagGraph {
  nodes: Node<StepNodeData>[];
  edges: Edge[];
}

export type TraceData = Record<
  string,
  { status: string; duration_ms?: number }
>;

export function buildDagGraph(
  steps: StepDefinition[],
  traceData: TraceData,
): DagGraph {
  const xGap = 260;
  const yGap = 100;

  // Group steps by depth (BFS-style layering based on dependencies)
  const depthMap = new Map<string, number>();
  const remaining = [...steps];
  let changed = true;

  // Initialize steps with no dependencies at depth 0
  for (const step of steps) {
    if (step.depends_on.length === 0) {
      depthMap.set(step.name, 0);
    }
  }

  // Iteratively resolve depths
  while (changed) {
    changed = false;
    for (const step of remaining) {
      if (depthMap.has(step.name)) continue;
      const depDepths = step.depends_on.map((d) => depthMap.get(d));
      if (depDepths.every((d) => d !== undefined)) {
        depthMap.set(step.name, Math.max(...(depDepths as number[])) + 1);
        changed = true;
      }
    }
  }

  // Fallback: any unresolved step gets depth based on index
  for (let i = 0; i < steps.length; i++) {
    if (!depthMap.has(steps[i]!.name)) {
      depthMap.set(steps[i]!.name, i);
    }
  }

  // Group by depth for Y positioning
  const depthGroups = new Map<number, string[]>();
  for (const [name, depth] of depthMap) {
    const group = depthGroups.get(depth) ?? [];
    group.push(name);
    depthGroups.set(depth, group);
  }

  const nodes: Node<StepNodeData>[] = steps.map((step) => {
    const depth = depthMap.get(step.name) ?? 0;
    const group = depthGroups.get(depth) ?? [step.name];
    const yIndex = group.indexOf(step.name);
    const trace = traceData[step.name];

    return {
      id: step.name,
      type: "pipelineStep",
      position: {
        x: depth * xGap,
        y: yIndex * yGap,
      },
      data: {
        label: step.name,
        status: trace?.status ?? "pending",
        duration_ms: trace?.duration_ms,
        loop: step.loop,
      },
    };
  });

  const edges: Edge[] = [];
  for (const step of steps) {
    for (const dep of step.depends_on) {
      edges.push({
        id: `${dep}->${step.name}`,
        source: dep,
        target: step.name,
        animated: false,
      });
    }
  }

  return { nodes, edges };
}
