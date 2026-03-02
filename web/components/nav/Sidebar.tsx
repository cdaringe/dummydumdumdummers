"use client";

import Link from "next/link";
import { useTheme } from "@/lib/theme-context";
import { useEffect, useState } from "react";

const navItems = [
  { href: "/", label: "Dashboard", icon: "::" },
  { href: "/pipelines", label: "Pipelines", icon: "|>" },
  { href: "/runs", label: "Runs", icon: ">>" },
  { href: "/stats", label: "Statistics", icon: "#=" },
  { href: "/integrations", label: "Integrations", icon: "<>" },
];

export function Sidebar() {
  const { mode, setMode } = useTheme();
  const [isMounted, setIsMounted] = useState(false);

  useEffect(() => {
    setIsMounted(true);
  }, []);

  const toggleMode = () => {
    setMode(mode === "standard" ? "compact" : "standard");
  };

  return (
    <nav
      style={{
        width: "var(--sidebar-width)",
        minHeight: "100vh",
        background: "var(--color-gray-950)",
        color: "var(--color-gray-100)",
        display: "flex",
        flexDirection: "column",
        padding: "var(--spacing-xl) 0",
        flexShrink: 0,
      }}
    >
      <div
        style={{
          padding: "0 var(--spacing-lg) var(--spacing-xl)",
          borderBottom: "1px solid var(--color-gray-800)",
          marginBottom: "var(--spacing-lg)",
        }}
      >
        <div
          style={{
            fontWeight: 700,
            fontSize: "var(--font-size-lg)",
            color: "var(--color-gray-100)",
            fontFamily: "monospace",
          }}
        >
          thingfactory
        </div>
        <div
          style={{
            fontSize: "var(--font-size-xs)",
            color: "var(--color-gray-600)",
            marginTop: "var(--spacing-xs)",
          }}
        >
          Pipeline Dashboard
        </div>
      </div>

      <div style={{ flex: 1 }}>
        {navItems.map((item) => (
          <Link
            key={item.href}
            href={item.href}
            style={{
              display: "flex",
              alignItems: "center",
              gap: "var(--spacing-md)",
              padding: "var(--spacing-md) var(--spacing-lg)",
              color: "var(--color-gray-400)",
              textDecoration: "none",
              fontSize: "var(--font-size-base)",
              fontWeight: 500,
              borderRadius: 0,
              transition: "all 0.2s ease",
            }}
            onMouseEnter={(e) => {
              const target = e.currentTarget;
              target.style.background = "var(--color-gray-800)";
              target.style.color = "var(--color-primary-light)";
            }}
            onMouseLeave={(e) => {
              const target = e.currentTarget;
              target.style.background = "transparent";
              target.style.color = "var(--color-gray-400)";
            }}
          >
            <span
              style={{
                fontFamily: "monospace",
                fontSize: "var(--font-size-sm)",
                minWidth: 20,
              }}
            >
              {item.icon}
            </span>
            {item.label}
          </Link>
        ))}
      </div>

      {isMounted && (
        <div
          style={{
            padding: "0 var(--spacing-lg) var(--spacing-xl)",
            borderTop: "1px solid var(--color-gray-800)",
            marginTop: "auto",
          }}
        >
          <button
            onClick={toggleMode}
            style={{
              width: "100%",
              padding: "var(--spacing-md) var(--spacing-lg)",
              marginTop: "var(--spacing-lg)",
              background: "var(--color-gray-800)",
              color: "var(--color-gray-100)",
              border: "1px solid var(--color-gray-700)",
              borderRadius: "var(--border-radius-md)",
              cursor: "pointer",
              fontSize: "var(--font-size-sm)",
              fontWeight: 500,
              transition: "all 0.2s ease",
            }}
            onMouseEnter={(e) => {
              const target = e.currentTarget;
              target.style.background = "var(--color-primary-darker)";
              target.style.borderColor = "var(--color-primary)";
            }}
            onMouseLeave={(e) => {
              const target = e.currentTarget;
              target.style.background = "var(--color-gray-800)";
              target.style.borderColor = "var(--color-gray-700)";
            }}
          >
            {mode === "standard" ? "[-] compact" : "[+] standard"}
          </button>
        </div>
      )}
    </nav>
  );
}
