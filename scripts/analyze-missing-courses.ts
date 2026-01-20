#!/usr/bin/env tsx
/**
 * Analyze missing OSM courses to see which ones could be imported as incomplete
 * and completed by users
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

interface OSMGolfCourse {
  id: number;
  type: string;
  tags: {
    name?: string;
    "addr:country"?: string;
    "addr:country_code"?: string;
    "addr:state"?: string;
    "addr:city"?: string;
    "addr:postcode"?: string;
    "addr:street"?: string;
    "addr:housenumber"?: string;
    website?: string;
    phone?: string;
    email?: string;
    operator?: string;
    leisure: string;
  };
  lat?: number;
  lon?: number;
  center?: {
    lat: number;
    lon: number;
  };
  geometry?: Array<{ lat: number; lon: number }>;
}

/**
 * Query a sample of OSM courses from a specific region to analyze what data they have
 */
async function querySampleCourses(bbox: [number, number, number, number] = [-180, -90, 180, 90]): Promise<OSMGolfCourse[]> {
  console.log(`Querying sample of OSM courses...`);
  
  const [minLon, minLat, maxLon, maxLat] = bbox;
  const query = `
    [out:json][timeout:60];
    (
      way["leisure"="golf_course"](${minLat},${minLon},${maxLat},${maxLon});
      relation["leisure"="golf_course"](${minLat},${minLon},${maxLat},${maxLon});
      node["leisure"="golf_course"](${minLat},${minLon},${maxLat},${maxLon});
    );
    out center meta;
    (._;>;);
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
    return (data.elements || []).map((element: any) => ({
      id: element.id,
      type: element.type,
      tags: element.tags || {},
      lat: element.lat || element.center?.lat,
      lon: element.lon || element.center?.lon,
      center: element.center,
      geometry: element.geometry?.map((point: any) => ({
        lat: point.lat,
        lon: point.lon,
      })),
    }));
  } catch (error) {
    console.error("Error fetching OSM courses:", error);
    throw error;
  }
}

/**
 * Check if a course is already imported
 */
async function isCourseImported(
  supabase: any,
  osmId: string,
  osmType: string
): Promise<boolean> {
  const { data } = await supabase
    .from("course_contributions")
    .select("id")
    .eq("osm_id", osmId)
    .eq("osm_type", osmType)
    .limit(1);
  
  return (data?.length || 0) > 0;
}

/**
 * Analyze course completeness
 */
function analyzeCourse(course: OSMGolfCourse) {
  const tags = course.tags;
  const lat = course.lat || course.center?.lat;
  const lon = course.lon || course.center?.lon;
  
  const hasCoordinates = lat && lon && !isNaN(lat) && !isNaN(lon);
  const hasName = !!tags.name;
  const hasAddress = !!(tags["addr:street"] || tags["addr:city"]);
  const hasCountry = !!(tags["addr:country"] || tags["addr:country_code"]);
  const hasContact = !!(tags.phone || tags.website || tags.email);
  const hasGeometry = !!(course.geometry && course.geometry.length > 0);
  
  // Calculate completeness score (0-100)
  let score = 0;
  if (hasCoordinates) score += 30; // Essential
  if (hasName) score += 20;
  if (hasAddress) score += 15;
  if (hasCountry) score += 10;
  if (hasContact) score += 15;
  if (hasGeometry) score += 10;
  
  return {
    hasCoordinates,
    hasName,
    hasAddress,
    hasCountry,
    hasContact,
    hasGeometry,
    completenessScore: score,
    missingFields: [
      !hasCoordinates && "coordinates",
      !hasName && "name",
      !hasAddress && "address",
      !hasCountry && "country",
      !hasContact && "contact_info",
      !hasGeometry && "geometry",
    ].filter(Boolean) as string[],
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
  console.log("Missing OSM Courses Analysis");
  console.log("=".repeat(70));
  console.log();

  // Get sample of OSM courses from multiple regions
  console.log("Step 1: Querying sample of OSM courses from various regions...");
  const regions = [
    { name: "Europe", bbox: [-15, 35, 40, 72] as [number, number, number, number] },
    { name: "North America", bbox: [-180, 25, -50, 70] as [number, number, number, number] },
    { name: "Asia", bbox: [60, -10, 180, 50] as [number, number, number, number] },
  ];
  
  let allSampleCourses: OSMGolfCourse[] = [];
  for (const region of regions) {
    console.log(`  Querying ${region.name}...`);
    try {
      const courses = await querySampleCourses(region.bbox);
      allSampleCourses = allSampleCourses.concat(courses);
      console.log(`  ✅ Found ${courses.length} courses in ${region.name}`);
      // Limit total to ~500 for analysis
      if (allSampleCourses.length >= 500) {
        allSampleCourses = allSampleCourses.slice(0, 500);
        break;
      }
      await new Promise(resolve => setTimeout(resolve, 2000)); // Rate limiting
    } catch (error: any) {
      console.log(`  ⚠️  Error querying ${region.name}: ${error.message}`);
    }
  }
  
  const sampleCourses = allSampleCourses;
  console.log(`✅ Retrieved ${sampleCourses.length} total sample courses\n`);

  // Check which are already imported
  console.log("Step 2: Checking which courses are already imported...");
  let importedCount = 0;
  let missingCount = 0;
  const missingCourses: OSMGolfCourse[] = [];

  for (const course of sampleCourses) {
    const isImported = await isCourseImported(supabase, course.id.toString(), course.type);
    if (isImported) {
      importedCount++;
    } else {
      missingCount++;
      missingCourses.push(course);
    }
  }

  console.log(`✅ Already imported: ${importedCount}`);
  console.log(`📋 Missing from database: ${missingCount}\n`);

  // Analyze missing courses
  console.log("Step 3: Analyzing missing courses...");
  const analyses = missingCourses.map(course => ({
    course,
    analysis: analyzeCourse(course),
  }));

  // Categorize by completeness
  const withCoordinates = analyses.filter(a => a.analysis.hasCoordinates);
  const withoutCoordinates = analyses.filter(a => !a.analysis.hasCoordinates);
  
  const nearlyComplete = analyses.filter(a => 
    a.analysis.completenessScore >= 50 && !a.analysis.hasCoordinates
  );
  
  const hasNameButNoCoords = analyses.filter(a => 
    a.analysis.hasName && !a.analysis.hasCoordinates
  );

  console.log("\n" + "=".repeat(70));
  console.log("Analysis Results");
  console.log("=".repeat(70));
  console.log();

  console.log(`📊 Missing Courses Breakdown (from ${missingCount} sample):`);
  console.log(`   ✅ With coordinates: ${withCoordinates.length}`);
  console.log(`   ❌ Without coordinates: ${withoutCoordinates.length}`);
  console.log(`   🎯 Nearly complete (score ≥50, no coords): ${nearlyComplete.length}`);
  console.log(`   📝 Has name but no coordinates: ${hasNameButNoCoords.length}`);
  console.log();

  // Show examples
  if (nearlyComplete.length > 0) {
    console.log("🎯 Examples of Nearly Complete Courses (could be imported as incomplete):");
    console.log("-".repeat(70));
    nearlyComplete.slice(0, 5).forEach((item, i) => {
      const { course, analysis } = item;
      console.log(`\n${i + 1}. ${course.tags.name || "Unnamed"}`);
      console.log(`   OSM ID: ${course.id} (${course.type})`);
      console.log(`   Completeness: ${analysis.completenessScore}%`);
      console.log(`   Has: ${[
        analysis.hasName && "name",
        analysis.hasAddress && "address",
        analysis.hasCountry && "country",
        analysis.hasContact && "contact",
        analysis.hasGeometry && "geometry",
      ].filter(Boolean).join(", ") || "none"}`);
      console.log(`   Missing: ${analysis.missingFields.join(", ")}`);
      if (course.tags["addr:city"]) console.log(`   Location hint: ${course.tags["addr:city"]}, ${course.tags["addr:country"] || course.tags["addr:country_code"] || "unknown"}`);
    });
    console.log();
  }

  if (hasNameButNoCoords.length > 0) {
    console.log("📝 Examples of Courses with Names but No Coordinates:");
    console.log("-".repeat(70));
    hasNameButNoCoords.slice(0, 5).forEach((item, i) => {
      const { course, analysis } = item;
      console.log(`\n${i + 1}. ${course.tags.name}`);
      console.log(`   OSM ID: ${course.id} (${course.type})`);
      console.log(`   Completeness: ${analysis.completenessScore}%`);
      if (course.tags["addr:city"]) console.log(`   Location: ${course.tags["addr:city"]}, ${course.tags["addr:country"] || course.tags["addr:country_code"] || "unknown"}`);
      if (course.tags.website) console.log(`   Website: ${course.tags.website}`);
    });
    console.log();
  }

  // Estimate total missing courses by category
  console.log("=".repeat(70));
  console.log("Estimated Totals (extrapolated from sample)");
  console.log("=".repeat(70));
  console.log();
  
  const totalMissing = 17087;
  const sampleSize = missingCount;
  const withCoordsPct = (withCoordinates.length / sampleSize) * 100;
  const withoutCoordsPct = (withoutCoordinates.length / sampleSize) * 100;
  const nearlyCompletePct = (nearlyComplete.length / sampleSize) * 100;
  const hasNamePct = (hasNameButNoCoords.length / sampleSize) * 100;

  console.log(`Estimated missing courses with coordinates: ~${Math.round(totalMissing * withCoordsPct / 100).toLocaleString()}`);
  console.log(`Estimated missing courses without coordinates: ~${Math.round(totalMissing * withoutCoordsPct / 100).toLocaleString()}`);
  console.log(`Estimated nearly complete (importable as incomplete): ~${Math.round(totalMissing * nearlyCompletePct / 100).toLocaleString()}`);
  console.log(`Estimated with names (could be geocoded): ~${Math.round(totalMissing * hasNamePct / 100).toLocaleString()}`);
  console.log();

  // Recommendations
  console.log("=".repeat(70));
  console.log("Recommendations");
  console.log("=".repeat(70));
  console.log();
  console.log("1. Import courses with names but no coordinates as 'incomplete'");
  console.log("   - Users can search for them by name");
  console.log("   - Users can add coordinates via map interface");
  console.log("   - Gamification: Badges for completing courses");
  console.log();
  console.log("2. Import courses with addresses but no coordinates");
  console.log("   - Use geocoding API to get approximate coordinates");
  console.log("   - Mark as 'needs_verification'");
  console.log("   - Users can verify and refine location");
  console.log();
  console.log("3. Create 'Course Completion' leaderboard");
  console.log("   - Track users who complete incomplete courses");
  console.log("   - Badges: 'Course Completer', 'Location Master', etc.");
  console.log("   - Competitions: 'Complete 10 courses this month'");
  console.log();
  console.log("4. Import strategy:");
  console.log("   - Status: 'incomplete' or 'needs_location'");
  console.log("   - Priority: Courses with names > courses with addresses");
  console.log("   - Exclude: Courses with no name and no address");
}

main().catch(console.error);
