"use client";
import { Background, Controls, MiniMap, ReactFlow } from "@xyflow/react";
import "@xyflow/react/dist/style.css";
import { PipelineDagNode } from "./PipelineDagNode";
import type { DagGraph } from "@/lib/dag";

const nodeTypes = { pipelineStep: PipelineDagNode };

type Props = { graph: DagGraph };

export function PipelineDag({ graph }: Props) {
  return (
    <div
      style={{
        height: 420,
        border: "1px solid var(--color-gray-300)",
        borderRadius: "var(--border-radius-lg)",
      }}
      data-testid="pipeline-dag"
    >
      {/* Test hook for edge assertions without depending on React Flow internals */}
      <div data-testid="pipeline-dag-edges" style={{ display: "none" }}>
        {graph.edges.map((e) => (
          <span key={e.id} data-testid={`edge-${e.id}`}>
            {e.source}
            {"->"}
            {e.target}
          </span>
        ))}
      </div>
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
