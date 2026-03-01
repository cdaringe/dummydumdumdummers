"use client";

import { Artifact } from "@/lib/types";
import { useEffect, useState } from "react";

type Props = { runId: string };

export function ArtifactsList({ runId }: Props) {
  const [artifacts, setArtifacts] = useState<Artifact[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function fetchArtifacts() {
      try {
        const response = await fetch(`/api/runs/${runId}/artifacts`);
        if (!response.ok) {
          setError("Failed to load artifacts");
          return;
        }
        const data = await response.json();
        setArtifacts(data || []);
      } catch (err) {
        setError("Failed to load artifacts");
        console.error(err);
      } finally {
        setLoading(false);
      }
    }

    fetchArtifacts();
  }, [runId]);

  if (loading) {
    return (
      <div style={{ color: "var(--color-gray-500)" }}>Loading artifacts...</div>
    );
  }

  if (error) {
    return <div style={{ color: "var(--color-gray-800)" }}>{error}</div>;
  }

  if (artifacts.length === 0) {
    return (
      <div
        style={{
          color: "var(--color-gray-500)",
          textAlign: "center",
          padding: "var(--spacing-2xl)",
        }}
      >
        No artifacts produced
      </div>
    );
  }

  return (
    <div>
      {artifacts.map((artifact, i) => (
        <div
          key={artifact.id}
          style={{
            display: "grid",
            gridTemplateColumns: "1fr 120px",
            alignItems: "center",
            gap: "var(--spacing-md)",
            padding: "var(--spacing-md) 0",
            borderBottom: i < artifacts.length - 1
              ? "1px solid var(--color-gray-200)"
              : "none",
          }}
        >
          <span
            style={{
              fontFamily: "monospace",
              fontSize: "var(--font-size-base)",
              fontWeight: 500,
              overflow: "hidden",
              textOverflow: "ellipsis",
              whiteSpace: "nowrap",
            }}
          >
            {artifact.name}
          </span>
          <a
            href={`/api/artifacts/${artifact.id}`}
            download={artifact.name}
            style={{
              display: "inline-block",
              padding: "var(--spacing-sm) var(--spacing-md)",
              borderRadius: "var(--border-radius-sm)",
              backgroundColor: "var(--color-gray-200)",
              color: "var(--color-gray-900)",
              textDecoration: "none",
              fontSize: "var(--font-size-sm)",
              fontWeight: 600,
              textAlign: "center",
              cursor: "pointer",
              transition: "background-color 0.2s",
            }}
            onMouseEnter={(e) => {
              (e.currentTarget as HTMLAnchorElement).style.backgroundColor =
                "var(--color-gray-300)";
            }}
            onMouseLeave={(e) => {
              (e.currentTarget as HTMLAnchorElement).style.backgroundColor =
                "var(--color-gray-200)";
            }}
          >
            Download
          </a>
        </div>
      ))}
    </div>
  );
}
