#!/usr/bin/env tsx
/**
 * Script to query specific regions that may have been missed
 * This helps identify missing courses from regions that timed out
 */

const OVERPASS_API = "https://overpass-api.de/api/interpreter";
const TIMEOUT = 180;

interface Region {
  name: string;
  bbox: [number, number, number, number]; // [minLon, minLat, maxLon, maxLat]
}

// More granular regions to catch missing courses
const detailedRegions: Region[] = [
  // Africa - broken into smaller chunks
  { name: "North Africa", bbox: [-20, 20, 40, 38] },
  { name: "West Africa", bbox: [-20, 4, 20, 20] },
  { name: "East Africa", bbox: [20, -12, 55, 12] },
  { name: "Central Africa", bbox: [8, -12, 30, 8] },
  { name: "Southern Africa", bbox: [10, -35, 55, -10] },
  
  // Asia - additional regions
  { name: "Middle East", bbox: [25, 12, 60, 40] },
  { name: "Central Asia", bbox: [40, 20, 100, 55] },
  { name: "Southeast Asia", bbox: [90, -11, 141, 30] },
  
  // Other regions that might have been missed
  { name: "Caribbean", bbox: [-90, 10, -60, 28] },
  { name: "Central America", bbox: [-92, 7, -77, 20] },
  { name: "Northern Europe", bbox: [-15, 55, 40, 72] },
  { name: "Eastern Europe", bbox: [15, 40, 50, 70] },
];

async function queryRegion(region: Region): Promise<number> {
  const [minLon, minLat, maxLon, maxLat] = region.bbox;
  
  const query = `
    [out:json][timeout:${TIMEOUT}];
    (
      way["leisure"="golf_course"](${minLat},${minLon},${maxLat},${maxLon});
      relation["leisure"="golf_course"](${minLat},${minLon},${maxLat},${maxLon});
      node["leisure"="golf_course"](${minLat},${minLon},${maxLat},${maxLon});
    );
    out count;
  `;

  try {
    const response = await fetch(OVERPASS_API, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: `data=${encodeURIComponent(query)}`,
    });

    if (!response.ok) {
      if (response.status === 504 || response.status === 502) {
        return -1; // Timeout
      }
      throw new Error(`OSM API error: ${response.statusText}`);
    }

    const data = await response.json();
    const elements = data.elements || [];
    
    // Count golf courses
    const count = elements.filter((e: any) => e.tags?.["leisure"] === "golf_course").length;
    return count;
  } catch (error: any) {
    console.error(`  Error: ${error.message}`);
    return -1;
  }
}

async function main() {
  console.log("=".repeat(60));
  console.log("Querying Missing Regions for Golf Courses");
  console.log("=".repeat(60));
  console.log();

  const results: Array<{ region: string; count: number; status: string }> = [];

  for (const region of detailedRegions) {
    console.log(`Querying ${region.name}...`);
    const count = await queryRegion(region);
    
    if (count === -1) {
      results.push({ region: region.name, count: 0, status: "TIMEOUT" });
      console.log(`  ⚠️  Timeout`);
    } else {
      results.push({ region: region.name, count, status: "SUCCESS" });
      console.log(`  ✅ Found ${count} courses`);
    }
    
    // Rate limiting
    await new Promise(resolve => setTimeout(resolve, 2000));
  }

  console.log("\n" + "=".repeat(60));
  console.log("Results Summary");
  console.log("=".repeat(60));
  console.log();

  const total = results.reduce((sum, r) => sum + (r.count > 0 ? r.count : 0), 0);
  const timeouts = results.filter(r => r.status === "TIMEOUT").length;

  console.log(`Total courses found: ${total}`);
  console.log(`Regions with timeouts: ${timeouts}`);
  console.log();

  console.log("Breakdown by region:");
  console.log("-".repeat(60));
  results.forEach(({ region, count, status }) => {
    const statusIcon = status === "TIMEOUT" ? "⚠️" : "✅";
    console.log(`${statusIcon} ${region.padEnd(25)} ${count.toString().padStart(6)} courses`);
  });

  if (timeouts > 0) {
    console.log("\n⚠️  Some regions timed out. These may need to be queried in smaller chunks.");
  }
}

if (require.main === module) {
  main();
}
