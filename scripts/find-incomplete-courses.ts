#!/usr/bin/env tsx
/**
 * Find OSM courses that don't have coordinates but have other useful data
 * These can be imported as "incomplete" for users to complete
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

const OVERPASS_API = "https://overpass-api.de/api/interpreter";

/**
 * Query OSM for courses with names but potentially missing coordinates
 * We'll query by country to get manageable results
 */
async function queryCoursesByCountry(countryCode: string): Promise<any[]> {
  const query = `
    [out:json][timeout:60];
    (
      way["leisure"="golf_course"]["addr:country_code"="${countryCode}"];
      relation["leisure"="golf_course"]["addr:country_code"="${countryCode}"];
      node["leisure"="golf_course"]["addr:country_code"="${countryCode}"];
    );
    out center meta;
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
      throw new Error(`OSM API error: ${response.statusText}`);
    }

    const data = await response.json();
    return data.elements || [];
  } catch (error) {
    console.error(`Error querying ${countryCode}:`, error);
    return [];
  }
}

/**
 * Analyze course and determine if it's importable as incomplete
 */
function isImportableAsIncomplete(element: any): {
  importable: boolean;
  reason: string;
  hasName: boolean;
  hasAddress: boolean;
  hasContact: boolean;
  hasCoordinates: boolean;
  completenessScore: number;
} {
  const tags = element.tags || {};
  const lat = element.lat || element.center?.lat;
  const lon = element.lon || element.center?.lon;
  
  const hasCoordinates = lat && lon && !isNaN(lat) && !isNaN(lon);
  const hasName = !!tags.name;
  const hasAddress = !!(tags["addr:street"] || tags["addr:city"] || tags["addr:postcode"]);
  const hasContact = !!(tags.phone || tags.website || tags.email);
  
  // Calculate completeness score
  let score = 0;
  if (hasName) score += 40;
  if (hasAddress) score += 30;
  if (hasContact) score += 20;
  if (hasCoordinates) score += 10;
  
  // Importable if it has useful data but is missing coordinates
  const importable = !hasCoordinates && (hasName || hasAddress);
  
  let reason = "";
  if (hasCoordinates) {
    reason = "Has coordinates - should be in regular import";
  } else if (hasName && hasAddress) {
    reason = "Has name and address - can be geocoded";
  } else if (hasName) {
    reason = "Has name - users can search and add location";
  } else if (hasAddress) {
    reason = "Has address - can be geocoded";
  } else {
    reason = "No useful data - skip";
  }
  
  return {
    importable,
    reason,
    hasName,
    hasAddress,
    hasContact,
    hasCoordinates,
    completenessScore: score,
  };
}

async function main() {
  const supabaseUrl = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseKey = process.env.SUPABASE_SERVICE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!supabaseUrl || !supabaseKey) {
    console.error("Error: SUPABASE_URL and SUPABASE_SERVICE_KEY must be set");
    process.exit(1);
  }

  const supabase = createClient(supabaseUrl, supabaseKey);

  console.log("=".repeat(70));
  console.log("Finding Incomplete OSM Courses");
  console.log("=".repeat(70));
  console.log();

  // Check what we already have
  const { count: totalImported } = await supabase
    .from("course_contributions")
    .select("*", { count: "exact", head: true })
    .eq("source", "osm");

  console.log(`📊 Currently imported: ${totalImported || 0} courses`);
  console.log();

  // Query a few countries to find examples
  const testCountries = ["US", "GB", "DE", "FR", "CA"];
  let totalFound = 0;
  let importableCount = 0;
  const importableCourses: any[] = [];

  console.log("Querying sample countries for courses...\n");

  for (const countryCode of testCountries) {
    console.log(`Querying ${countryCode}...`);
    const courses = await queryCoursesByCountry(countryCode);
    totalFound += courses.length;
    
    console.log(`  Found ${courses.length} courses`);
    
    // Check which are already imported
    const osmIds = courses.map((c: any) => c.id.toString());
    const { data: existing } = await supabase
      .from("course_contributions")
      .select("osm_id")
      .in("osm_id", osmIds)
      .eq("source", "osm");
    
    const existingIds = new Set((existing || []).map((e: any) => e.osm_id));
    const notImported = courses.filter((c: any) => !existingIds.has(c.id.toString()));
    
    console.log(`  Already imported: ${existingIds.size}`);
    console.log(`  Not imported: ${notImported.length}`);
    
    // Analyze which could be imported as incomplete
    for (const course of notImported) {
      const analysis = isImportableAsIncomplete(course);
      if (analysis.importable) {
        importableCount++;
        importableCourses.push({ course, analysis });
      }
    }
    
    await new Promise(resolve => setTimeout(resolve, 2000)); // Rate limiting
  }

  console.log("\n" + "=".repeat(70));
  console.log("Results");
  console.log("=".repeat(70));
  console.log();
  console.log(`Total courses found: ${totalFound}`);
  console.log(`Importable as incomplete: ${importableCount}`);
  console.log();

  if (importableCourses.length > 0) {
    console.log("Examples of importable incomplete courses:");
    console.log("-".repeat(70));
    importableCourses.slice(0, 10).forEach((item, i) => {
      const { course, analysis } = item;
      const tags = course.tags || {};
      console.log(`\n${i + 1}. ${tags.name || "Unnamed"}`);
      console.log(`   OSM ID: ${course.id} (${course.type})`);
      console.log(`   Completeness: ${analysis.completenessScore}%`);
      console.log(`   Reason: ${analysis.reason}`);
      if (tags["addr:city"]) console.log(`   City: ${tags["addr:city"]}`);
      if (tags["addr:country"]) console.log(`   Country: ${tags["addr:country"]}`);
      if (tags.website) console.log(`   Website: ${tags.website}`);
      if (tags.phone) console.log(`   Phone: ${tags.phone}`);
    });
  } else {
    console.log("⚠️  No incomplete courses found in sample.");
    console.log("This suggests most OSM courses have coordinates.");
    console.log("The missing 17,087 courses are likely:");
    console.log("  - In regions that failed to import");
    console.log("  - Outside our defined bounding boxes");
    console.log("  - Filtered out for other reasons");
  }

  console.log("\n" + "=".repeat(70));
  console.log("Recommendation");
  console.log("=".repeat(70));
  console.log();
  console.log("Based on the analysis, here's what we should do:");
  console.log();
  console.log("1. The missing courses likely HAVE coordinates but weren't imported");
  console.log("   - They're probably in regions that timed out");
  console.log("   - Or outside our bounding boxes");
  console.log();
  console.log("2. For courses WITHOUT coordinates (if any exist):");
  console.log("   - Import them with status='incomplete' or 'needs_location'");
  console.log("   - Allow users to add coordinates via map interface");
  console.log("   - Use geocoding for courses with addresses");
  console.log();
  console.log("3. Gamification opportunities:");
  console.log("   - Badge: 'Course Completer' - complete 10 incomplete courses");
  console.log("   - Badge: 'Location Master' - add coordinates to 5 courses");
  console.log("   - Leaderboard: Top course completers this month");
  console.log("   - Competition: 'Complete the Map' - complete all courses in your country");
}

main().catch(console.error);
