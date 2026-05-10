import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "LAP Fitness — Your Complete Fitness Companion",
  description:
    "Track workouts, meals, and hydration. Connect with friends. LAP Fitness is the all-in-one fitness app built to keep you moving. Join the waitlist for early access.",
  openGraph: {
    title: "LAP Fitness — Your Complete Fitness Companion",
    description:
      "Track workouts, meals, and hydration. Connect with friends. Join the waitlist.",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: "LAP Fitness — Your Complete Fitness Companion",
    description: "Track workouts, meals, and hydration. Join the waitlist.",
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
