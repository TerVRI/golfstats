#!/usr/bin/env tsx
/**
 * Import incomplete OSM courses (courses with data but missing coordinates)
 * These will be imported with status='incomplete' for users to complete
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
  console.log("✅ Loaded environment variables from .env.local");
} catch (error) {
  // .env.local doesn't exist - that's okay
}

import { createClient } from "@supabase/supabase-js";

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
}

interface CourseContribution {
  contributor_id: string;
  name: string;
  city: string | null;
  state: string | null;
  country: string;
  address: string | null;
  phone: string | null;
  website: string | null;
  latitude: number | null;
  longitude: number | null;
  hole_data: any[];
  geojson_data: any | null;
  photo_urls: string[];
  photos: Array<{ url: string; uploaded_at: string }>;
  status: "incomplete" | "needs_location";
  source: "osm";
  osm_id?: string;
  osm_type?: string;
  completion_priority: number;
  missing_fields: string[];
  geocoded: boolean;
}

const OVERPASS_API = "https://overpass-api.de/api/interpreter";
const BATCH_SIZE = 50;

/**
 * Determine if a course should be imported as incomplete
 */
function shouldImportAsIncomplete(course: OSMGolfCourse): {
  import: boolean;
  priority: number;
  missingFields: string[];
} {
  const tags = course.tags;
  const lat = course.lat || course.center?.lat;
  const lon = course.lon || course.center?.lon;
  
  const hasCoordinates = lat && lon && !isNaN(lat) && !isNaN(lon);
  const hasName = !!tags.name;
  const hasAddress = !!(tags["addr:street"] || tags["addr:city"]);
  const hasCountry = !!(tags["addr:country"] || tags["addr:country_code"]);
  const hasContact = !!(tags.phone || tags.website || tags.email);
  
  // Don't import if it has coordinates (should be in regular import)
  if (hasCoordinates) {
    return { import: false, priority: 0, missingFields: [] };
  }
  
  // Import if it has useful data but no coordinates
  const missingFields: string[] = [];
  if (!hasCoordinates) missingFields.push("latitude", "longitude");
  if (!hasName) missingFields.push("name");
  if (!hasAddress) missingFields.push("address");
  if (!hasContact) missingFields.push("contact_info");
  
  let priority = 0;
  if (hasName && hasAddress) {
    priority = 10; // Highest - can be geocoded
  } else if (hasName) {
    priority = 7; // Users can search
  } else if (hasAddress) {
    priority = 5; // Can be geocoded
  } else if (hasCountry || hasContact) {
    priority = 3; // Some data available
  }
  
  // Only import if we have at least name or address
  const importIt = (hasName || hasAddress) && priority >= 3;
  
  return { import: importIt, priority, missingFields };
}

/**
 * Convert OSM course to incomplete contribution
 */
function convertToIncompleteContribution(
  osmCourse: OSMGolfCourse,
  contributorId: string,
  analysis: { priority: number; missingFields: string[] }
): CourseContribution {
  const tags = osmCourse.tags;
  
  const addressParts = [
    tags["addr:housenumber"],
    tags["addr:street"],
  ].filter(Boolean);
  const address = addressParts.length > 0 ? addressParts.join(" ") : null;

  return {
    contributor_id: contributorId,
    name: tags.name || "Unnamed Golf Course",
    city: tags["addr:city"] || null,
    state: tags["addr:state"] || null,
    country: tags["addr:country"] || tags["addr:country_code"] || "Unknown",
    address: address,
    phone: tags.phone || null,
    website: tags.website || null,
    latitude: null, // Missing - to be added by user
    longitude: null, // Missing - to be added by user
    hole_data: [],
    geojson_data: null,
    photo_urls: [],
    photos: [],
    status: analysis.priority >= 7 ? "incomplete" : "needs_location",
    source: "osm",
    osm_id: osmCourse.id.toString(),
    osm_type: osmCourse.type,
    completion_priority: analysis.priority,
    missing_fields: analysis.missingFields,
    geocoded: false,
  };
}

/**
 * Query OSM for courses in a region
 */
async function queryRegion(
  bbox: [number, number, number, number],
  regionName: string
): Promise<OSMGolfCourse[]> {
  const [minLon, minLat, maxLon, maxLat] = bbox;
  
  const query = `
    [out:json][timeout:60];
    (
      way["leisure"="golf_course"](${minLat},${minLon},${maxLat},${maxLon});
      relation["leisure"="golf_course"](${minLat},${minLon},${maxLat},${maxLon});
      node["leisure"="golf_course"](${minLat},${minLon},${maxLat},${maxLon});
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
    return (data.elements || []).map((element: any) => ({
      id: element.id,
      type: element.type,
      tags: element.tags || {},
      lat: element.lat || element.center?.lat,
      lon: element.lon || element.center?.lon,
      center: element.center,
    }));
  } catch (error) {
    console.error(`Error querying ${regionName}:`, error);
    return [];
  }
}

async function main() {
  const supabaseUrl = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseKey = process.env.SUPABASE_SERVICE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!supabaseUrl || !supabaseKey) {
    console.error("Error: SUPABASE_URL and SUPABASE_SERVICE_KEY must be set");
    process.exit(1);
  }

  const supabase = createClient(supabaseUrl, supabaseKey);

  // Find system user
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

  console.log("=".repeat(70));
  console.log("Import Incomplete OSM Courses");
  console.log("=".repeat(70));
  console.log();
  console.log("This script finds OSM courses with data but missing coordinates");
  console.log("and imports them as 'incomplete' for users to complete.");
  console.log();

  // For now, we'll query a few test regions
  // In production, you'd want to query all regions systematically
  const testRegions = [
    { name: "Europe (Sample)", bbox: [-5, 50, 10, 60] as [number, number, number, number] },
    { name: "North America (Sample)", bbox: [-100, 35, -80, 45] as [number, number, number, number] },
  ];

  let totalFound = 0;
  let totalImported = 0;
  let totalSkipped = 0;

  for (const region of testRegions) {
    console.log(`\n📍 Processing ${region.name}...`);
    
    const courses = await queryRegion(region.bbox, region.name);
    console.log(`  Found ${courses.length} courses`);
    
    // Filter to incomplete courses
    const incompleteCourses: Array<{ course: OSMGolfCourse; analysis: any }> = [];
    
    for (const course of courses) {
      // Check if already imported
      const { data: existing } = await supabase
        .from("course_contributions")
        .select("id")
        .eq("osm_id", course.id.toString())
        .eq("osm_type", course.type)
        .limit(1);
      
      if (existing && existing.length > 0) {
        totalSkipped++;
        continue;
      }
      
      const analysis = shouldImportAsIncomplete(course);
      if (analysis.import) {
        incompleteCourses.push({ course, analysis });
        totalFound++;
      }
    }
    
    console.log(`  Incomplete courses found: ${incompleteCourses.length}`);
    
    // Import in batches
    for (let i = 0; i < incompleteCourses.length; i += BATCH_SIZE) {
      const batch = incompleteCourses.slice(i, i + BATCH_SIZE);
      const contributions = batch.map(({ course, analysis }) =>
        convertToIncompleteContribution(course, contributorId, analysis)
      );
      
      const { error } = await supabase
        .from("course_contributions")
        .insert(contributions);
      
      if (error) {
        console.error(`  ❌ Error importing batch:`, error.message);
      } else {
        totalImported += contributions.length;
        console.log(`  ✅ Imported ${contributions.length} incomplete courses`);
      }
      
      await new Promise(resolve => setTimeout(resolve, 500)); // Rate limiting
    }
    
    await new Promise(resolve => setTimeout(resolve, 2000)); // Between regions
  }

  console.log("\n" + "=".repeat(70));
  console.log("Import Summary");
  console.log("=".repeat(70));
  console.log(`Total incomplete courses found: ${totalFound}`);
  console.log(`Total imported: ${totalImported}`);
  console.log(`Total skipped (already exist): ${totalSkipped}`);
  console.log();
  console.log("✅ Import complete!");
  console.log();
  console.log("Note: This is a sample import. To import all incomplete courses,");
  console.log("you would need to query all regions systematically.");
}

main().catch(console.error);
