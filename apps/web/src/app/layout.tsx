import type { Metadata, Viewport } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import { RegisterServiceWorker } from "@/components/pwa/register-sw";
import "./globals.css";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "RoundCaddy - Strokes Gained Analytics",
  description: "Tour-level strokes gained analytics for every golfer. Track your rounds, analyze your game, and identify where to improve.",
  keywords: ["golf", "strokes gained", "round caddy", "golf analytics", "handicap", "golf tracking"],
  manifest: "/manifest.json",
  appleWebApp: {
    capable: true,
    statusBarStyle: "black-translucent",
    title: "RoundCaddy",
  },
  formatDetection: {
    telephone: false,
  },
  openGraph: {
    type: "website",
    siteName: "RoundCaddy",
    title: "RoundCaddy - Strokes Gained Analytics",
    description: "Tour-level strokes gained analytics for every golfer",
    url: "https://roundcaddy.com",
  },
  twitter: {
    card: "summary_large_image",
    title: "RoundCaddy - Strokes Gained Analytics",
    description: "Tour-level strokes gained analytics for every golfer",
  },
};

export const viewport: Viewport = {
  themeColor: "#10b981",
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
  userScalable: false,
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="dark">
      <head>
        <link rel="apple-touch-icon" sizes="180x180" href="/icons/apple-touch-icon.png" />
        <link rel="icon" type="image/png" sizes="32x32" href="/icons/icon-32x32.png" />
        <link rel="icon" type="image/png" sizes="16x16" href="/icons/icon-16x16.png" />
        <meta name="apple-mobile-web-app-capable" content="yes" />
        <meta name="mobile-web-app-capable" content="yes" />
      </head>
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased bg-background text-foreground min-h-screen`}
      >
        <RegisterServiceWorker />
        {children}
      </body>
    </html>
  );
}
