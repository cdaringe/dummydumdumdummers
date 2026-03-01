import Link from "next/link";

export default function NotFound() {
  return (
    <div style={{ textAlign: "center", padding: "var(--spacing-2xl)" }}>
      <h1 style={{ fontSize: "var(--font-size-2xl)", marginBottom: "var(--spacing-lg)", color: "var(--color-gray-950)" }}>404</h1>
      <p style={{ color: "var(--color-gray-600)", marginBottom: "var(--spacing-xl)" }}>
        Page not found
      </p>
      <Link
        href="/"
        className="btn btn-primary"
      >
        Go Home
      </Link>
    </div>
  );
}
