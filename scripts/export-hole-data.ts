/**
 * Export all hole data from the database to a local JSON file
 * This creates a backup/reference so we don't have to re-download from OSM
 */

import { createClient } from "@supabase/supabase-js";
import * as dotenv from "dotenv";
import * as fs from "fs";
import * as path from "path";

dotenv.config({ path: ".env.local" });

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL!;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY!;
const supabase = createClient(supabaseUrl, supabaseKey);

interface CourseHoleExport {
  course_id: string;
  course_name: string;
  lat: number;
  lon: number;
  country: string;
  state: string;
  city: string;
  hole_data: any[];
  exported_at: string;
}

async function exportHoleData() {
  console.log("=".repeat(60));
  console.log("📦 EXPORTING HOLE DATA TO JSON");
  console.log("=".repeat(60));

  const outputPath = path.join(process.cwd(), "data", "hole-data-export.json");
  const outputDir = path.dirname(outputPath);

  // Create data directory if it doesn't exist
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  // Fetch all courses with hole_data from both tables
  const tables = ["courses", "course_contributions"];
  const allCourses: CourseHoleExport[] = [];
  const seenIds = new Set<string>();

  for (const table of tables) {
    console.log(`\n📥 Fetching from ${table}...`);

    let offset = 0;
    const limit = 1000;
    let hasMore = true;

    while (hasMore) {
      const { data, error } = await supabase
        .from(table)
        .select("id, name, latitude, longitude, country, state, city, hole_data")
        .not("hole_data", "is", null)
        .range(offset, offset + limit - 1);

      if (error) {
        console.error(`Error fetching from ${table}:`, error);
        break;
      }

      if (!data || data.length === 0) {
        hasMore = false;
        break;
      }

      for (const course of data) {
        // Skip if we've already seen this course
        if (seenIds.has(course.id)) continue;

        // Skip placeholder data
        const holeData = course.hole_data;
        if (!holeData || !Array.isArray(holeData) || holeData.length === 0) continue;
        if (holeData.length === 1 && holeData[0].hole_number <= 0) continue;

        // Check if there's any real data (at least one green or bunker)
        const hasRealData = holeData.some(
          (h: any) =>
            h.hole_number > 0 ||
            (h.hole_number === 0 && (h.bunkers?.length > 0 || h.water_hazards?.length > 0))
        );

        if (!hasRealData) continue;

        seenIds.add(course.id);
        allCourses.push({
          course_id: course.id,
          course_name: course.name,
          lat: course.latitude,
          lon: course.longitude,
          country: course.country || "Unknown",
          state: course.state || "",
          city: course.city || "",
          hole_data: holeData,
          exported_at: new Date().toISOString(),
        });
      }

      console.log(`  Processed ${offset + data.length} records...`);
      offset += limit;
      hasMore = data.length === limit;
    }
  }

  console.log(`\n✅ Found ${allCourses.length} courses with hole data`);

  // Calculate statistics
  let totalHoles = 0;
  let totalGreens = 0;
  let totalBunkers = 0;
  let totalWater = 0;

  for (const course of allCourses) {
    for (const hole of course.hole_data) {
      if (hole.hole_number > 0) {
        totalHoles++;
        if (hole.green) totalGreens++;
      }
      if (hole.hole_number === 0) {
        totalBunkers += hole.bunkers?.length || 0;
        totalWater += hole.water_hazards?.length || 0;
      }
    }
  }

  // Write metadata
  const metadataPath = path.join(outputDir, "hole-data-metadata.json");
  const metadata = {
    exported_at: new Date().toISOString(),
    total_courses: allCourses.length,
    total_holes: totalHoles,
    total_greens: totalGreens,
    total_bunkers: totalBunkers,
    total_water_hazards: totalWater,
  };
  fs.writeFileSync(metadataPath, JSON.stringify(metadata, null, 2));

  // Write courses in chunks to avoid memory issues
  console.log("\n📝 Writing data to files...");
  const chunkSize = 1000;
  let totalSize = 0;

  for (let i = 0; i < allCourses.length; i += chunkSize) {
    const chunk = allCourses.slice(i, i + chunkSize);
    const chunkPath = path.join(outputDir, `hole-data-chunk-${Math.floor(i / chunkSize) + 1}.json`);
    const chunkData = JSON.stringify(chunk, null, 2);
    fs.writeFileSync(chunkPath, chunkData);
    totalSize += chunkData.length;
    console.log(`  Written chunk ${Math.floor(i / chunkSize) + 1} (${chunk.length} courses)`);
  }

  const fileSizeMB = (totalSize / (1024 * 1024)).toFixed(2);

  console.log("\n" + "=".repeat(60));
  console.log("📊 EXPORT SUMMARY");
  console.log("=".repeat(60));
  console.log(`📁 Output directory: ${outputDir}`);
  console.log(`📦 Total size: ${fileSizeMB} MB`);
  console.log(`📄 Files: ${Math.ceil(allCourses.length / chunkSize)} chunks + metadata`);
  console.log(`🏌️ Courses: ${allCourses.length}`);
  console.log(`🕳️ Holes: ${totalHoles}`);
  console.log(`🟢 Greens: ${totalGreens}`);
  console.log(`🟡 Bunkers: ${totalBunkers}`);
  console.log(`🔵 Water hazards: ${totalWater}`);
  console.log("=".repeat(60));
}

exportHoleData().catch(console.error);
