import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "Creative Moments API",
  description: "Backend for the Creative Moments app.",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
