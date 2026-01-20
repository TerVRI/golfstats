#!/usr/bin/env tsx
/**
 * Check which regions might be missing courses
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

// Same regions as import script
const REGIONS = [
  { name: "North America (West)", bbox: [-180, 30, -100, 70] },
  { name: "North America (Central)", bbox: [-100, 25, -80, 50] },
  { name: "North America (East)", bbox: [-80, 25, -50, 50] },
  { name: "North America (Canada)", bbox: [-140, 50, -50, 85] },
  { name: "Europe (West)", bbox: [-15, 35, 5, 60] },
  { name: "Europe (Central)", bbox: [5, 45, 25, 60] },
  { name: "Europe (East)", bbox: [25, 40, 40, 72] },
  { name: "Europe (South)", bbox: [-10, 35, 40, 50] },
  { name: "Asia (West)", bbox: [60, 20, 100, 50] },
  { name: "Asia (Central)", bbox: [100, 20, 140, 50] },
  { name: "Japan (North)", bbox: [140, 38, 146, 45] },
  { name: "Japan (South)", bbox: [130, 31, 140, 38] },
  { name: "South Korea", bbox: [124, 33, 132, 39] },
  { name: "China (East Coast)", bbox: [115, 30, 125, 40] },
  { name: "Asia (East - Other)", bbox: [140, 20, 180, 35] },
  { name: "Asia (South)", bbox: [60, -10, 100, 30] },
  { name: "Asia (Southeast)", bbox: [100, -10, 140, 30] },
  { name: "South America", bbox: [-90, -60, -30, 15] },
  { name: "North Africa", bbox: [-20, 20, 40, 38] },
  { name: "West Africa", bbox: [-20, 4, 20, 20] },
  { name: "East Africa", bbox: [20, -12, 55, 12] },
  { name: "Central Africa", bbox: [8, -12, 30, 8] },
  { name: "Southern Africa", bbox: [10, -35, 55, -10] },
  { name: "Oceania (Australia)", bbox: [110, -45, 155, -10] },
  { name: "Oceania (New Zealand)", bbox: [165, -50, 180, -34] },
  { name: "Oceania (Pacific)", bbox: [155, -50, 180, 0] },
  { name: "Middle East", bbox: [25, 12, 60, 40] },
  { name: "Caribbean", bbox: [-90, 10, -60, 28] },
  { name: "Central America", bbox: [-92, 7, -77, 20] },
];

async function main() {
  const supabaseUrl = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseKey = process.env.SUPABASE_SERVICE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!supabaseUrl || !supabaseKey) {
    console.error("Error: SUPABASE_URL and SUPABASE_SERVICE_KEY must be set");
    process.exit(1);
  }

  const supabase = createClient(supabaseUrl, supabaseKey);

  console.log("=".repeat(70));
  console.log("Region Import Status Check");
  console.log("=".repeat(70));
  console.log();

  // Get system contributor ID
  const { data: systemUser } = await supabase
    .from("profiles")
    .select("id")
    .eq("name", "RoundCaddy")
    .eq("email", "roundcaddy@roundcaddy.com")
    .single();

  if (!systemUser) {
    console.error("❌ System user 'RoundCaddy' not found");
    process.exit(1);
  }

  const contributorId = systemUser.id;

  console.log("Checking courses per region...\n");

  const regionCounts: Array<{ name: string; count: number; bbox: number[] }> = [];

  for (const region of REGIONS) {
    const [minLon, minLat, maxLon, maxLat] = region.bbox;
    
    const { count } = await supabase
      .from("course_contributions")
      .select("*", { count: "exact", head: true })
      .eq("source", "osm")
      .eq("contributor_id", contributorId)
      .gte("latitude", minLat)
      .lte("latitude", maxLat)
      .gte("longitude", minLon)
      .lte("longitude", maxLon);

    regionCounts.push({
      name: region.name,
      count: count || 0,
      bbox: region.bbox,
    });
  }

  // Sort by count
  regionCounts.sort((a, b) => a.count - b.count);

  console.log("Regions by Course Count:");
  console.log("-".repeat(70));
  console.log(`${"Region".padEnd(35)} ${"Courses".padStart(10)}`);
  console.log("-".repeat(70));

  let totalInRegions = 0;
  regionCounts.forEach((r) => {
    const indicator = r.count === 0 ? "⚠️ " : r.count < 10 ? "🔸 " : "✅ ";
    console.log(`${indicator}${r.name.padEnd(33)} ${r.count.toString().padStart(10)}`);
    totalInRegions += r.count;
  });

  console.log("-".repeat(70));
  console.log(`${"Total in defined regions".padEnd(35)} ${totalInRegions.toString().padStart(10)}`);
  console.log();

  // Check for courses outside all regions
  const { count: outsideCount } = await supabase
    .from("course_contributions")
    .select("*", { count: "exact", head: true })
    .eq("source", "osm")
    .eq("contributor_id", contributorId);

  const outsideRegions = (outsideCount || 0) - totalInRegions;
  console.log(`📊 Total OSM courses in database: ${outsideCount || 0}`);
  console.log(`📍 Courses in defined regions: ${totalInRegions}`);
  console.log(`🌍 Courses outside defined regions: ${outsideRegions}`);
  console.log();

  // Identify regions with 0 courses (likely failed)
  const failedRegions = regionCounts.filter((r) => r.count === 0);
  if (failedRegions.length > 0) {
    console.log("⚠️  Regions with 0 courses (likely failed to import):");
    failedRegions.forEach((r) => {
      console.log(`   - ${r.name}`);
    });
    console.log();
  }

  // Identify regions with very few courses (might be incomplete)
  const sparseRegions = regionCounts.filter((r) => r.count > 0 && r.count < 10);
  if (sparseRegions.length > 0) {
    console.log("🔸 Regions with < 10 courses (might be incomplete):");
    sparseRegions.forEach((r) => {
      console.log(`   - ${r.name}: ${r.count} courses`);
    });
    console.log();
  }

  console.log("=".repeat(70));
  console.log("Summary");
  console.log("=".repeat(70));
  console.log();
  console.log("The discrepancy between OSM statistics (40,491) and imported");
  console.log("courses (22,837) is likely due to:");
  console.log();
  console.log("1. Regional bounding boxes may not cover all courses");
  console.log("2. Some regions failed to import due to timeouts");
  console.log("3. Courses without valid coordinates are filtered out");
  console.log("4. The original OSM query counted ALL courses globally,");
  console.log("   while import uses regional queries");
  console.log();
  console.log("Next steps:");
  console.log("- Re-run import script to retry failed regions");
  console.log("- Check if bounding boxes need adjustment");
  console.log("- Verify if original OSM statistics included courses without coordinates");
}

main().catch(console.error);
