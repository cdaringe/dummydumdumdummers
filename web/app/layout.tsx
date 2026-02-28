import type { Metadata } from "next";
import "./globals.css";
import { LayoutWrapper } from "@/app/layout-wrapper";

export const metadata: Metadata = {
  title: "Thingfactory",
  description: "CI/CD Pipeline Dashboard",
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>
        <LayoutWrapper>{children}</LayoutWrapper>
      </body>
    </html>
  );
}
