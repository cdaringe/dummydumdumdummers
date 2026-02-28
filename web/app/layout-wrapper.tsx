'use client';

import { Sidebar } from "@/components/nav/Sidebar";
import { ThemeProvider } from "@/lib/theme-context";

export function LayoutWrapper({ children }: { children: React.ReactNode }) {
  return (
    <ThemeProvider>
      <div style={{ display: "flex", minHeight: "100vh" }}>
        <Sidebar />
        <main
          style={{
            flex: 1,
            padding: "var(--spacing-2xl) var(--spacing-2xl)",
            maxWidth: 1200,
            width: "100%",
          }}
        >
          {children}
        </main>
      </div>
    </ThemeProvider>
  );
}
