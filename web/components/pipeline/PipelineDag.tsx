"use client";
import { ReactFlow, Background, Controls, MiniMap } from "@xyflow/react";
import "@xyflow/react/dist/style.css";
import { PipelineDagNode } from "./PipelineDagNode";
import type { DagGraph } from "@/lib/dag";

const nodeTypes = { pipelineStep: PipelineDagNode };

type Props = { graph: DagGraph };

export function PipelineDag({ graph }: Props) {
  return (
    <div
      style={{ height: 420, border: "1px solid var(--color-gray-300)", borderRadius: "var(--border-radius-lg)" }}
      data-testid="pipeline-dag"
    >
      <ReactFlow
        nodes={graph.nodes}
        edges={graph.edges}
        nodeTypes={nodeTypes}
        fitView
        fitViewOptions={{ padding: 0.2 }}
        proOptions={{ hideAttribution: true }}
      >
        <Background />
        <Controls />
        <MiniMap />
      </ReactFlow>
    </div>
  );
}
