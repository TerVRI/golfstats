#!/usr/bin/env tsx
/**
 * Quick script to check OSM import status
 */

// Load .env.local if it exists
import { readFileSync } from "fs";
import { join } from "path";

try {
  const envPath = join(process.cwd(), ".env.local");
  const envFile = readFileSync(envPath, "utf-8");
  envFile.split("\n").forEach((line) => {
    const trimmed = line.trim();
    if (trimmed && !trimmed.startsWith("#") && trimmed.includes("=")) {
      const [key, ...valueParts] = trimmed.split("=");
      const value = valueParts.join("=").trim();
      if (key && value && !process.env[key]) {
        process.env[key] = value;
      }
    }
  });
} catch (error) {
  // .env.local doesn't exist - that's okay
}

import { createClient } from "@supabase/supabase-js";

async function main() {
  const supabaseUrl = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseKey = process.env.SUPABASE_SERVICE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!supabaseUrl || !supabaseKey) {
    console.error("Error: SUPABASE_URL and SUPABASE_SERVICE_KEY must be set");
    process.exit(1);
  }

  const supabase = createClient(supabaseUrl, supabaseKey);

  console.log("Checking OSM import status...\n");

  // Total count
  const { count: totalCount } = await supabase
    .from("course_contributions")
    .select("*", { count: "exact", head: true })
    .eq("source", "osm");

  console.log(`✅ Total OSM courses: ${totalCount || 0}`);

  // By status
  const { data: statusData } = await supabase
    .from("course_contributions")
    .select("status")
    .eq("source", "osm");

  const statusCounts: Record<string, number> = {};
  statusData?.forEach((c: any) => {
    statusCounts[c.status] = (statusCounts[c.status] || 0) + 1;
  });

  console.log("\nBy Status:");
  Object.entries(statusCounts).forEach(([status, count]) => {
    console.log(`  ${status}: ${count}`);
  });

  // Top countries
  const { data: countryData } = await supabase
    .from("course_contributions")
    .select("country")
    .eq("source", "osm")
    .not("country", "is", null);

  const countryCounts: Record<string, number> = {};
  countryData?.forEach((c: any) => {
    countryCounts[c.country] = (countryCounts[c.country] || 0) + 1;
  });

  const topCountries = Object.entries(countryCounts)
    .sort(([, a], [, b]) => b - a)
    .slice(0, 10);

  console.log("\nTop 10 Countries:");
  topCountries.forEach(([country, count]) => {
    console.log(`  ${country}: ${count}`);
  });
}

main().catch(console.error);
