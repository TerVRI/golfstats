#!/usr/bin/env tsx
/**
 * Analyze the discrepancy between OSM statistics and imported courses
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

  console.log("=".repeat(70));
  console.log("OSM Import Discrepancy Analysis");
  console.log("=".repeat(70));
  console.log();

  // Read original statistics
  let originalStats: any = null;
  try {
    const statsFile = readFileSync("osm-golf-statistics.json", "utf-8");
    originalStats = JSON.parse(statsFile);
    console.log(`📊 Original OSM Statistics: ${originalStats.total.toLocaleString()} courses`);
  } catch (error) {
    console.log("⚠️  Could not read osm-golf-statistics.json");
  }

  // Current database count
  const { count: totalCount } = await supabase
    .from("course_contributions")
    .select("*", { count: "exact", head: true })
    .eq("source", "osm");

  console.log(`📥 Currently Imported: ${(totalCount || 0).toLocaleString()} courses`);
  console.log();

  if (originalStats) {
    const missing = originalStats.total - (totalCount || 0);
    const percentage = ((totalCount || 0) / originalStats.total * 100).toFixed(1);
    console.log(`📉 Missing: ${missing.toLocaleString()} courses (${(100 - parseFloat(percentage)).toFixed(1)}%)`);
    console.log(`✅ Coverage: ${percentage}%`);
    console.log();
  }

  // Check for courses without coordinates (shouldn't exist, but let's verify)
  const { count: noCoords } = await supabase
    .from("course_contributions")
    .select("*", { count: "exact", head: true })
    .eq("source", "osm")
    .or("latitude.is.null,longitude.is.null");

  console.log(`📍 Courses without coordinates: ${noCoords || 0}`);
  console.log();

  // Check for duplicates by osm_id
  const { data: duplicates } = await supabase
    .from("course_contributions")
    .select("osm_id")
    .eq("source", "osm")
    .not("osm_id", "is", null);

  if (duplicates) {
    const osmIdCounts: Record<string, number> = {};
    duplicates.forEach((c: any) => {
      if (c.osm_id) {
        osmIdCounts[c.osm_id] = (osmIdCounts[c.osm_id] || 0) + 1;
      }
    });

    const actualDuplicates = Object.entries(osmIdCounts).filter(([, count]) => count > 1);
    console.log(`🔄 Duplicate OSM IDs: ${actualDuplicates.length}`);
    if (actualDuplicates.length > 0) {
      console.log(`   (Total duplicate entries: ${actualDuplicates.reduce((sum, [, count]) => sum + count - 1, 0)})`);
      console.log(`   Top 10 duplicates:`);
      actualDuplicates
        .sort(([, a], [, b]) => b - a)
        .slice(0, 10)
        .forEach(([id, count]) => {
          console.log(`     OSM ID ${id}: ${count} entries`);
        });
    }
    console.log();
  }

  // Check by region (based on country distribution)
  console.log("🌍 Top 20 Countries (Imported):");
  console.log("-".repeat(70));
  const { data: countryData } = await supabase
    .from("course_contributions")
    .select("country")
    .eq("source", "osm");

  const countryCounts: Record<string, number> = {};
  countryData?.forEach((c: any) => {
    countryCounts[c.country] = (countryCounts[c.country] || 0) + 1;
  });

  const topCountries = Object.entries(countryCounts)
    .sort(([, a], [, b]) => b - a)
    .slice(0, 20);

  topCountries.forEach(([country, count], index) => {
    const originalCount = originalStats?.byCountry?.find((c: any) => 
      c.country === country || 
      c.countryCode === country
    )?.count || 0;
    const diff = originalCount > 0 ? originalCount - count : 0;
    const indicator = diff > 0 ? "⚠️" : "✅";
    console.log(
      `${(index + 1).toString().padStart(2)}. ${country.padEnd(15)} ${count.toString().padStart(6)} ` +
      (originalCount > 0 ? `(OSM: ${originalCount.toString().padStart(6)}, diff: ${diff > 0 ? `-${diff}` : "0"})` : "")
    );
  });
  console.log();

  // Summary
  console.log("=".repeat(70));
  console.log("Summary");
  console.log("=".repeat(70));
  console.log();
  console.log("Possible reasons for missing courses:");
  console.log("1. Courses without valid coordinates (filtered out during import)");
  console.log("2. Regions that failed to import due to timeouts");
  console.log("3. Courses that were skipped as duplicates");
  console.log("4. OSM statistics may include courses without coordinates");
  console.log();
  console.log("Next steps:");
  console.log("- Check import logs for failed regions");
  console.log("- Re-run import script to retry failed regions");
  console.log("- Verify OSM statistics query includes only courses with coordinates");
}

main().catch(console.error);
