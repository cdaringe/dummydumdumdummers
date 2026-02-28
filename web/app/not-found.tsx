import Link from "next/link";

export default function NotFound() {
  return (
    <div style={{ textAlign: "center", padding: "60px 20px" }}>
      <h1 style={{ fontSize: 48, marginBottom: 16 }}>404</h1>
      <p style={{ color: "#6b7280", marginBottom: 24 }}>
        Page not found
      </p>
      <Link
        href="/"
        style={{
          display: "inline-block",
          padding: "10px 20px",
          backgroundColor: "#3b82f6",
          color: "white",
          borderRadius: 4,
          textDecoration: "none",
        }}
      >
        Go Home
      </Link>
    </div>
  );
}
