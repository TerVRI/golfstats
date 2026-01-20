#!/usr/bin/env tsx
/**
 * Script to import all OpenStreetMap golf courses into the database
 * 
 * This script:
 * 1. Fetches golf courses from OSM by region
 * 2. Imports each region as it completes (incremental import)
 * 3. Skips regions that are already imported
 * 4. Supports test mode (--test) to import one course per region first
 * 
 * Usage: 
 *   npx tsx scripts/import-osm-courses.ts              # Full import
 *   npx tsx scripts/import-osm-courses.ts --test         # Test mode (1 course per region)
 * 
 * Environment variables:
 *   SUPABASE_URL or NEXT_PUBLIC_SUPABASE_URL - Your Supabase project URL
 *   SUPABASE_SERVICE_KEY - Your Supabase service role key (for admin access)
 * 
 * The script automatically loads .env.local if it exists.
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
  // .env.local doesn't exist or can't be read - that's okay
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
  geometry?: Array<{ lat: number; lon: number }>;
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
  status: "pending" | "approved" | "rejected";
  source: "osm";
  osm_id?: string;
  osm_type?: string;
}

interface Region {
  name: string;
  bbox: [number, number, number, number]; // [minLon, minLat, maxLon, maxLat]
}

// Primary Overpass API endpoint (this worked before)
const OVERPASS_API = "https://overpass-api.de/api/interpreter";

const TIMEOUT = 180;
const BATCH_SIZE = 100;
const RETRY_DELAY = 3000; // 3 seconds between retries

// Major regions to query (full regions)
// Note: Large regions like North America, Europe, and Asia are split to avoid OSM API timeouts
const REGIONS: Region[] = [
  // North America - split into regions
  { name: "North America (West)", bbox: [-180, 30, -100, 70] },
  { name: "North America (Central)", bbox: [-100, 25, -80, 50] },
  { name: "North America (East)", bbox: [-80, 25, -50, 50] },
  { name: "North America (Canada)", bbox: [-140, 50, -50, 85] },
  // Europe - split into regions
  { name: "Europe (West)", bbox: [-15, 35, 5, 60] },
  { name: "Europe (Central)", bbox: [5, 45, 25, 60] },
  { name: "Europe (East)", bbox: [25, 40, 40, 72] },
  { name: "Europe (South)", bbox: [-10, 35, 40, 50] },
  // Asia - split into regions
  { name: "Asia (West)", bbox: [60, 20, 100, 50] },
  { name: "Asia (Central)", bbox: [100, 20, 140, 50] },
  // Asia (East) - split into country-specific regions due to timeouts
  { name: "Japan (North)", bbox: [140, 38, 146, 45] },
  { name: "Japan (South)", bbox: [130, 31, 140, 38] },
  { name: "South Korea", bbox: [124, 33, 132, 39] },
  { name: "China (East Coast)", bbox: [115, 30, 125, 40] },
  // Asia (East - Other) split into smaller regions to avoid timeouts
  { name: "Philippines", bbox: [116, 4, 127, 21] },
  { name: "Indonesia (West)", bbox: [95, -11, 115, 6] },
  { name: "Indonesia (East)", bbox: [115, -11, 141, 6] },
  { name: "Malaysia & Singapore", bbox: [99, 0, 105, 8] },
  { name: "Thailand & Vietnam", bbox: [97, 5, 110, 21] },
  { name: "Pacific Islands (West)", bbox: [140, -10, 165, 20] },
  { name: "Pacific Islands (East)", bbox: [165, -10, 180, 20] },
  { name: "Asia (South)", bbox: [60, -10, 100, 30] },
  { name: "Asia (Southeast)", bbox: [100, -10, 140, 30] },
  // Other regions
  { name: "South America", bbox: [-90, -60, -30, 15] },
  { name: "North Africa", bbox: [-20, 20, 40, 38] },
  { name: "West Africa", bbox: [-20, 4, 20, 20] },
  { name: "East Africa", bbox: [20, -12, 55, 12] },
  { name: "Central Africa", bbox: [8, -12, 30, 8] },
  { name: "Southern Africa", bbox: [10, -35, 55, -10] },
  // Oceania - split into regions
  { name: "Oceania (Australia)", bbox: [110, -45, 155, -10] },
  { name: "Oceania (New Zealand)", bbox: [165, -50, 180, -34] },
  { name: "Oceania (Pacific)", bbox: [155, -50, 180, 0] },
  { name: "Middle East", bbox: [25, 12, 60, 40] },
  { name: "Caribbean", bbox: [-90, 10, -60, 28] },
  { name: "Central America", bbox: [-92, 7, -77, 20] },
];

// Test regions - one small area from each major continent to test all regions
const TEST_REGIONS: Region[] = [
  { name: "New York, USA (North America)", bbox: [-74.0, 40.7, -73.9, 40.8] },
  { name: "London, UK (Europe)", bbox: [-0.3, 51.4, -0.1, 51.5] },
  { name: "Tokyo, Japan (Asia)", bbox: [139.7, 35.6, 139.8, 35.7] },
  { name: "Sydney, Australia (Oceania)", bbox: [151.0, -33.9, 151.1, -33.8] },
  { name: "Cape Town, South Africa (Africa)", bbox: [18.4, -33.9, 18.5, -33.8] },
  { name: "São Paulo, Brazil (South America)", bbox: [-46.7, -23.6, -46.6, -23.5] },
  { name: "Dubai, UAE (Middle East)", bbox: [55.2, 25.1, 55.3, 25.2] },
];

/**
 * Check if a region is already imported by checking if courses exist in that bounding box
 */
async function isRegionImported(
  supabase: any,
  region: Region,
  contributorId: string
): Promise<boolean> {
  try {
    const [minLon, minLat, maxLon, maxLat] = region.bbox;
    
    // Check if we have any OSM courses in this region
    const { data, error } = await supabase
      .from("course_contributions")
      .select("id")
      .eq("source", "osm")
      .eq("contributor_id", contributorId)
      .gte("latitude", minLat)
      .lte("latitude", maxLat)
      .gte("longitude", minLon)
      .lte("longitude", maxLon)
      .limit(1);
    
    if (error) {
      // If error, assume not imported (safer to re-import than skip)
      return false;
    }
    
    return (data?.length || 0) > 0;
  } catch (error) {
    return false;
  }
}

/**
 * Query a region with simple retry logic (like the original working version)
 */
async function queryRegionWithRetry(
  bbox: [number, number, number, number],
  regionName: string,
  maxRetries: number = 3
): Promise<OSMGolfCourse[]> {
  const [minLon, minLat, maxLon, maxLat] = bbox;
  
  // Use appropriate timeout: shorter for test, full timeout for production
  const queryTimeout = TIMEOUT; // Use full 180 second timeout for large regions
  const query = `
    [out:json][timeout:${queryTimeout}];
    (
      way["leisure"="golf_course"](${minLat},${minLon},${maxLat},${maxLon});
      relation["leisure"="golf_course"](${minLat},${minLon},${maxLat},${maxLon});
      node["leisure"="golf_course"](${minLat},${minLon},${maxLat},${maxLon});
    );
    out center meta;
  `;

  for (let attempt = 1; attempt <= maxRetries; attempt++) {
    try {
      console.log(`  🔄 Attempt ${attempt}/${maxRetries} (query timeout: ${queryTimeout}s)...`);
      const startTime = Date.now();
      
      const response = await fetch(OVERPASS_API, {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: `data=${encodeURIComponent(query)}`,
      });
      
      const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
      console.log(`  ⏱️  Request took ${elapsed}s`);

      if (!response.ok) {
        // Try to get error details
        let errorText = "";
        try {
          errorText = await response.text();
          console.log(`  ⚠️  Response status: ${response.status} ${response.statusText}`);
          console.log(`  ⚠️  Response preview: ${errorText.substring(0, 200)}`);
        } catch (e) {
          // Ignore
        }
        
        if (response.status === 504 || response.status === 502) {
          // Gateway timeout - retry with wait
          if (attempt < maxRetries) {
            console.log(`  ⚠️  Timeout on attempt ${attempt}, retrying in 5 seconds...`);
            await new Promise(resolve => setTimeout(resolve, 5000));
            continue;
          }
          throw new Error(`OSM API timeout after ${maxRetries} attempts`);
        }
        throw new Error(`OSM API error: ${response.statusText} (${response.status})`);
      }

      const data = await response.json();
      
      // Check for Overpass API errors in the response
      if (data.error) {
        console.log(`  ⚠️  Overpass API error: ${data.error}`);
        if (attempt < maxRetries) {
          console.log(`  ⚠️  Retrying in 5 seconds...`);
          await new Promise(resolve => setTimeout(resolve, 5000));
          continue;
        }
        throw new Error(`Overpass API error: ${data.error}`);
      }
      const elements = data.elements || [];
      
      const courses: OSMGolfCourse[] = elements
        .filter((element: any) => element.tags?.["leisure"] === "golf_course")
        .map((element: any) => ({
          id: element.id,
          type: element.type,
          tags: element.tags,
          lat: element.lat || element.center?.lat,
          lon: element.lon || element.center?.lon,
          center: element.center,
          geometry: element.geometry?.map((point: any) => ({
            lat: point.lat,
            lon: point.lon,
          })),
        }));
      
      return courses;
    } catch (error: any) {
      if (attempt === maxRetries) {
        throw error;
      }
      console.log(`  ⚠️  Attempt ${attempt} failed: ${error.message}, retrying...`);
      await new Promise(resolve => setTimeout(resolve, 3000 * attempt));
    }
  }
  
  throw new Error(`Failed to query ${regionName} after ${maxRetries} attempts`);
}

/**
 * Convert OSM course to our contribution format
 */
function convertOSMCourseToContribution(
  osmCourse: OSMGolfCourse,
  contributorId: string
): CourseContribution {
  const tags = osmCourse.tags;
  const lat = osmCourse.lat || osmCourse.center?.lat;
  const lon = osmCourse.lon || osmCourse.center?.lon;

  const addressParts = [
    tags["addr:housenumber"],
    tags["addr:street"],
  ].filter(Boolean);
  const address = addressParts.length > 0 ? addressParts.join(" ") : null;

  let geojsonData: any = null;
  if (osmCourse.geometry && osmCourse.geometry.length > 0) {
    geojsonData = {
      type: "Polygon",
      coordinates: [
        osmCourse.geometry.map((p) => [p.lon, p.lat]),
        [osmCourse.geometry[0].lon, osmCourse.geometry[0].lat],
      ],
    };
  }

  return {
    contributor_id: contributorId,
    name: tags.name || "Unnamed Golf Course",
    city: tags["addr:city"] || null,
    state: tags["addr:state"] || null,
    country: tags["addr:country"] || tags["addr:country_code"] || "Unknown",
    address: address,
    phone: tags.phone || null,
    website: tags.website || null,
    latitude: lat || null,
    longitude: lon || null,
    hole_data: [],
    geojson_data: geojsonData,
    photo_urls: [],
    photos: [],
    status: "pending",
    source: "osm",
    osm_id: osmCourse.id.toString(),
    osm_type: osmCourse.type,
  };
}

/**
 * Import courses into Supabase (incremental, per region)
 */
async function importCourses(
  supabase: any,
  courses: CourseContribution[],
  regionName: string
): Promise<{ imported: number; skipped: number; errors: number }> {
  if (courses.length === 0) {
    return { imported: 0, skipped: 0, errors: 0 };
  }
  
  let imported = 0;
  let skipped = 0;
  let errors = 0;

  // Process in batches
  for (let i = 0; i < courses.length; i += BATCH_SIZE) {
    const batch = courses.slice(i, i + BATCH_SIZE);
    const batchNum = Math.floor(i / BATCH_SIZE) + 1;
    const totalBatches = Math.ceil(courses.length / BATCH_SIZE);
    
    if (totalBatches > 1) {
      console.log(`  Processing batch ${batchNum}/${totalBatches}...`);
    }

    try {
      // Check for existing courses by osm_id
      const osmIds = batch.map(c => c.osm_id).filter(Boolean);
      if (osmIds.length > 0) {
        try {
          const { data: existing, error: checkError } = await supabase
            .from("course_contributions")
            .select("osm_id")
            .in("osm_id", osmIds);
          
          if (checkError && checkError.message?.includes("osm_id")) {
            // Column doesn't exist, skip duplicate check
          } else if (existing) {
            const existingIds = new Set(existing.map((e: any) => e.osm_id) || []);
            const newBatch = batch.filter(c => !existingIds.has(c.osm_id));
            
            if (newBatch.length === 0) {
              skipped += batch.length;
              continue;
            }
            
            skipped += batch.length - newBatch.length;
            // Use filtered batch
            const batchToInsert = newBatch.map(({ osm_id, osm_type, ...rest }) => {
              const item: any = { ...rest };
              if (osm_id) item.osm_id = osm_id;
              if (osm_type) item.osm_type = osm_type;
              return item;
            });

            const { data, error } = await supabase
              .from("course_contributions")
              .insert(batchToInsert)
              .select();

            if (error) {
              console.error(`  ❌ Error inserting batch ${batchNum}:`, error.message);
              errors += newBatch.length;
            } else {
              imported += data?.length || 0;
            }
            continue;
          }
        } catch (err: any) {
          // Continue without duplicate check
        }
      }

      // Insert batch
      const batchToInsert = batch.map(({ osm_id, osm_type, ...rest }) => {
        const item: any = { ...rest };
        if (osm_id) item.osm_id = osm_id;
        if (osm_type) item.osm_type = osm_type;
        return item;
      });

      const { data, error } = await supabase
        .from("course_contributions")
        .insert(batchToInsert)
        .select();

      if (error) {
        // Check for database function errors (array_length, etc.)
        const errorMsg = error.message || String(error);
        const errorCode = error.code || '';
        const errorDetails = error.details || '';
        
        if (
          errorMsg.includes("array_length") || 
          errorMsg.includes("function") && errorMsg.includes("does not exist") ||
          errorCode === '42883' || // Function does not exist
          errorDetails.includes("array_length")
        ) {
          console.error(`\n  ❌ CRITICAL DATABASE ERROR:`);
          console.error(`  ${errorMsg}`);
          console.error(`\n  ⚠️  You must fix the database function first!`);
          console.error(`  Run this SQL in Supabase SQL Editor:`);
          console.error(`  → fix-array-length-error.sql\n`);
          throw new Error(`Database function error: ${errorMsg}. Please run fix-array-length-error.sql first.`);
        }
        console.error(`  ❌ Error inserting batch ${batchNum}:`, errorMsg);
        errors += batch.length;
      } else {
        imported += data?.length || 0;
      }
    } catch (error: any) {
      const errorMsg = error.message || String(error);
      if (
        errorMsg.includes("array_length") || 
        (errorMsg.includes("function") && errorMsg.includes("does not exist")) ||
        errorMsg.includes("Database function error")
      ) {
        throw error; // Re-throw database errors
      }
      console.error(`  ❌ Error processing batch ${batchNum}:`, errorMsg);
      errors += batch.length;
    }

    // Rate limiting
    await new Promise(resolve => setTimeout(resolve, 500));
  }

  return { imported, skipped, errors };
}

async function main() {
  const isTestMode = process.argv.includes("--test");
  
  const supabaseUrl = process.env.SUPABASE_URL || process.env.NEXT_PUBLIC_SUPABASE_URL;
  const supabaseKey = process.env.SUPABASE_SERVICE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

  if (!supabaseUrl) {
    console.error("Error: SUPABASE_URL or NEXT_PUBLIC_SUPABASE_URL must be set");
    process.exit(1);
  }

  if (!supabaseKey) {
    console.error("Error: SUPABASE_SERVICE_KEY must be set");
    process.exit(1);
  }

  const supabase = createClient(supabaseUrl, supabaseKey);

  // Get or find the RoundCaddy user
  let contributorId = process.env.SYSTEM_CONTRIBUTOR_ID;
  
  if (!contributorId) {
    console.log("Looking for RoundCaddy (OSM import user)...");
    
    const { data: roundCaddy, error: rcError } = await supabase
      .from("profiles")
      .select("id, name")
      .eq("email", "roundcaddy@roundcaddy.com")
      .single();
    
    if (!rcError && roundCaddy) {
      contributorId = roundCaddy.id;
      console.log(`✅ Found RoundCaddy: ${roundCaddy.name} (${contributorId})`);
    } else {
      const { data: existingUsers, error: userError } = await supabase
        .from("profiles")
        .select("id, name")
        .limit(1);
      
      if (userError || !existingUsers || existingUsers.length === 0) {
        console.error("\n❌ No users found in database!");
        console.error("Please run create-system-user.sql in Supabase SQL Editor");
        process.exit(1);
      }
      
      contributorId = existingUsers[0].id;
      console.log(`⚠️  Using existing user: ${existingUsers[0].name || existingUsers[0].id}`);
    }
  }

  // Ensure contributorId is set (TypeScript check)
  if (!contributorId) {
    console.error("\n❌ Contributor ID not found!");
    process.exit(1);
  }

  try {
    console.log("=".repeat(60));
    console.log("OpenStreetMap Golf Course Import");
    if (isTestMode) {
      console.log("TEST MODE: Using city-level regions (1 course per city)");
    }
    console.log("=".repeat(60));
    console.log();

    let totalImported = 0;
    let totalSkipped = 0;
    let totalErrors = 0;
    const failedRegions: string[] = [];

    // Use test regions in test mode, full regions otherwise
    const regionsToProcess = isTestMode ? TEST_REGIONS : REGIONS;

    console.log(`Processing ${regionsToProcess.length} region(s)...\n`);

    // Process each region incrementally
    for (const region of regionsToProcess) {
      console.log(`\n📍 Processing ${region.name}...`);
      
      // Check if region is already imported (skip check in test mode)
      // Note: For failed regions, we want to retry them, so we'll check but allow retry
      if (!isTestMode) {
        const alreadyImported = await isRegionImported(supabase, region, contributorId);
        if (alreadyImported) {
          // Check if we have a reasonable number of courses (more than just test data)
          const { count } = await supabase
            .from("course_contributions")
            .select("*", { count: "exact", head: true })
            .eq("source", "osm")
            .eq("contributor_id", contributorId)
            .gte("latitude", region.bbox[1])
            .lte("latitude", region.bbox[3])
            .gte("longitude", region.bbox[0])
            .lte("longitude", region.bbox[2]);
          
          // If we have less than 10 courses, it might be test data - retry
          if ((count || 0) < 10) {
            console.log(`  ⚠️  ${region.name} has only ${count} courses, retrying to get full import...`);
          } else {
            console.log(`  ⏭️  ${region.name} already imported (${count} courses), skipping...`);
            continue;
          }
        }
      }

      try {
        // Query region
        console.log(`  Querying OSM for ${region.name}...`);
        let courses = await queryRegionWithRetry(region.bbox, region.name);
        
        if (courses.length === 0) {
          console.log(`  ℹ️  No courses found in ${region.name}`);
          continue;
        }

        // Test mode: only import first course
        if (isTestMode) {
          courses = courses.slice(0, 1);
          console.log(`  🧪 TEST MODE: Importing 1 course from ${region.name}`);
        }

        // Filter courses with valid coordinates
        const validCourses = courses.filter(course => {
          const lat = course.lat || course.center?.lat;
          const lon = course.lon || course.center?.lon;
          return lat && lon && !isNaN(lat) && !isNaN(lon);
        });

        if (validCourses.length === 0) {
          console.log(`  ⚠️  No valid courses (with coordinates) in ${region.name}`);
          continue;
        }

        // Convert to contributions
        const contributions = validCourses.map(course => 
          convertOSMCourseToContribution(course, contributorId)
        );

        console.log(`  📥 Importing ${contributions.length} courses from ${region.name}...`);
        
        // Import immediately (incremental)
        const result = await importCourses(supabase, contributions, region.name);
        
        totalImported += result.imported;
        totalSkipped += result.skipped;
        totalErrors += result.errors;
        
        console.log(`  ✅ ${region.name}: ${result.imported} imported, ${result.skipped} skipped, ${result.errors} errors`);
        
        // Small delay between regions (1 second - just to be polite to the API)
        await new Promise(resolve => setTimeout(resolve, 1000));
        
      } catch (error: any) {
        console.error(`  ❌ Error processing ${region.name}:`, error.message);
        failedRegions.push(region.name);
        totalErrors += 1;
        
        // If it's a database error (array_length), stop everything
        if (error.message?.includes("array_length") || error.message?.includes("function")) {
          console.error("\n❌ CRITICAL: Database function error detected!");
          console.error("Please run fix-array-length-error.sql in Supabase SQL Editor");
          console.error("Then re-run this script.");
          process.exit(1);
        }
      }
    }

    // Summary
    console.log("\n" + "=".repeat(60));
    console.log("Import Summary");
    console.log("=".repeat(60));
    console.log(`Total imported: ${totalImported}`);
    console.log(`Total skipped (already exist): ${totalSkipped}`);
    console.log(`Total errors: ${totalErrors}`);
    if (failedRegions.length > 0) {
      console.log(`\nFailed regions: ${failedRegions.join(", ")}`);
      console.log("You can re-run this script to retry failed regions.");
    }
    console.log("\n✅ Import complete!");
    
  } catch (error: any) {
    console.error("\n❌ Fatal error:", error.message);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}
