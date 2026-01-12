import { clsx, type ClassValue } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

export function formatNumber(num: number, decimals: number = 1): string {
  return num.toFixed(decimals);
}

export function formatSG(value: number): string {
  const prefix = value >= 0 ? "+" : "";
  return `${prefix}${value.toFixed(2)}`;
}

export function formatDate(date: Date | string): string {
  const d = typeof date === "string" ? new Date(date) : date;
  return d.toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
    year: "numeric",
  });
}

export function formatDateShort(date: Date | string): string {
  const d = typeof date === "string" ? new Date(date) : date;
  return d.toLocaleDateString("en-US", {
    month: "short",
    day: "numeric",
  });
}

export function calculateScoreToPar(score: number, par: number): string {
  const diff = score - par;
  if (diff === 0) return "E";
  return diff > 0 ? `+${diff}` : `${diff}`;
}

export function getScoreColor(score: number, par: number): string {
  const diff = score - par;
  if (diff <= -2) return "text-amber-400"; // Eagle or better
  if (diff === -1) return "text-accent-green"; // Birdie
  if (diff === 0) return "text-foreground"; // Par
  if (diff === 1) return "text-accent-red-light"; // Bogey
  return "text-accent-red"; // Double+
}

export function getSGColor(value: number): string {
  if (value >= 0.5) return "text-accent-green";
  if (value >= 0) return "text-accent-green-light";
  if (value >= -0.5) return "text-accent-red-light";
  return "text-accent-red";
}

export function getSGBgColor(value: number): string {
  if (value >= 0.5) return "bg-accent-green/20";
  if (value >= 0) return "bg-accent-green/10";
  if (value >= -0.5) return "bg-accent-red/10";
  return "bg-accent-red/20";
}

