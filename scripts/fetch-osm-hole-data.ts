/**
 * Fetch detailed hole-by-hole data from OpenStreetMap for a specific golf course
 * This script queries OSM for golf course features including:
 * - Tee boxes (golf=tee)
 * - Greens (golf=green)
 * - Fairways (golf=fairway)
 * - Bunkers (golf=bunker)
 * - Water hazards (natural=water)
 * - Hole numbers and pars
 */

const OVERPASS_API = "https://overpass-api.de/api/interpreter";

interface OSMNode {
  type: "node";
  id: number;
  lat: number;
  lon: number;
  tags?: Record<string, string>;
}

interface OSMWay {
  type: "way";
  id: number;
  nodes: number[];
  tags?: Record<string, string>;
  geometry?: Array<{ lat: number; lon: number }>;
}

interface OSMRelation {
  type: "relation";
  id: number;
  members: Array<{ type: string; ref: number; role: string }>;
  tags?: Record<string, string>;
}

type OSMElement = OSMNode | OSMWay | OSMRelation;

interface HoleData {
  hole_number: number;
  par?: number;
  tee_locations: Array<{ tee: string; lat: number; lon: number }>;
  green_center?: { lat: number; lon: number };
  green?: Array<[number, number]>;
  fairway?: Array<[number, number]>;
  bunkers: Array<{ polygon: Array<[number, number]> }>;
  water_hazards: Array<{ polygon: Array<[number, number]> }>;
}

/**
 * Query OSM for golf course features near a specific location
 */
async function queryGolfCourseFeatures(
  courseName: string,
  lat: number,
  lon: number,
  radius: number = 1000
): Promise<OSMElement[]> {
  console.log(`🔍 Querying OSM for ${courseName}...\n`);

  // Query for golf course features within radius
  const query = `
    [out:json][timeout:60];
    (
      // Golf course boundary
      way["leisure"="golf_course"](around:${radius},${lat},${lon});
      relation["leisure"="golf_course"](around:${radius},${lat},${lon});
      
      // Golf holes
      way["golf"="hole"](around:${radius},${lat},${lon});
      relation["golf"="hole"](around:${radius},${lat},${lon});
      
      // Tee boxes
      node["golf"="tee"](around:${radius},${lat},${lon});
      way["golf"="tee"](around:${radius},${lat},${lon});
      
      // Greens
      node["golf"="green"](around:${radius},${lat},${lon});
      way["golf"="green"](around:${radius},${lat},${lon});
      
      // Fairways
      way["golf"="fairway"](around:${radius},${lat},${lon});
      
      // Bunkers
      way["golf"="bunker"](around:${radius},${lat},${lon});
      way["golf"="sand_trap"](around:${radius},${lat},${lon});
      
      // Water hazards (near golf courses)
      way["natural"="water"](around:${radius},${lat},${lon});
      way["waterway"](around:${radius},${lat},${lon});
    );
    out geom;
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
      throw new Error(`HTTP ${response.status}: ${response.statusText}`);
    }

    const data = await response.json();
    return data.elements || [];
  } catch (error: any) {
    console.error(`❌ Error querying OSM:`, error.message);
    throw error;
  }
}

/**
 * Process OSM elements into structured hole data
 */
function processOSMData(elements: OSMElement[]): HoleData[] {
  const holes: Map<number, HoleData> = new Map();

  // First pass: find all holes and their basic info
  elements.forEach((element) => {
    if (element.type === "way" || element.type === "relation") {
      const tags = element.tags || {};
      const holeNum = tags["golf:hole"] || tags["hole"] || tags["ref"];

      if (holeNum && tags["golf"] === "hole") {
        const num = parseInt(holeNum);
        if (!isNaN(num) && !holes.has(num)) {
          holes.set(num, {
            hole_number: num,
            par: tags["par"] ? parseInt(tags["par"]) : undefined,
            tee_locations: [],
            bunkers: [],
            water_hazards: [],
          });
        }
      }
    }
  });

  // Second pass: collect features for each hole
  elements.forEach((element) => {
    const tags = element.tags || {};
    const holeNum = tags["golf:hole"] || tags["hole"] || tags["ref"];
    const num = holeNum ? parseInt(holeNum) : null;

    if (element.type === "node" && tags["golf"] === "tee") {
      // Tee box node
      const node = element as OSMNode;
      const teeColor = tags["golf:tee"] || tags["tee"] || "blue";
      const targetHole = num || 1; // Default to hole 1 if not specified

      if (!holes.has(targetHole)) {
        holes.set(targetHole, {
          hole_number: targetHole,
          tee_locations: [],
          bunkers: [],
          water_hazards: [],
        });
      }

      holes.get(targetHole)!.tee_locations.push({
        tee: teeColor,
        lat: node.lat,
        lon: node.lon,
      });
    } else if (element.type === "way" && "geometry" in element) {
      const way = element as OSMWay;
      const geometry = way.geometry || [];

      if (geometry.length === 0) return;

      // Convert geometry to polygon coordinates
      const polygon: Array<[number, number]> = geometry.map((g) => [g.lat, g.lon]);

      if (tags["golf"] === "green") {
        // Green polygon
        const targetHole = num || 1;
        if (!holes.has(targetHole)) {
          holes.set(targetHole, {
            hole_number: targetHole,
            tee_locations: [],
            bunkers: [],
            water_hazards: [],
          });
        }
        const hole = holes.get(targetHole)!;
        hole.green = polygon;

        // Calculate green center
        const centerLat = polygon.reduce((sum, [lat]) => sum + lat, 0) / polygon.length;
        const centerLon = polygon.reduce((sum, [, lon]) => sum + lon, 0) / polygon.length;
        hole.green_center = { lat: centerLat, lon: centerLon };
      } else if (tags["golf"] === "fairway") {
        // Fairway polygon
        const targetHole = num || 1;
        if (!holes.has(targetHole)) {
          holes.set(targetHole, {
            hole_number: targetHole,
            tee_locations: [],
            bunkers: [],
            water_hazards: [],
          });
        }
        holes.get(targetHole)!.fairway = polygon;
      } else if (tags["golf"] === "bunker" || tags["golf"] === "sand_trap") {
        // Bunker polygon
        const targetHole = num || 1;
        if (!holes.has(targetHole)) {
          holes.set(targetHole, {
            hole_number: targetHole,
            tee_locations: [],
            bunkers: [],
            water_hazards: [],
          });
        }
        holes.get(targetHole)!.bunkers.push({ polygon });
      } else if (tags["natural"] === "water" || tags["waterway"]) {
        // Water hazard - assign to nearest hole (simplified)
        // In a real implementation, you'd calculate which hole it's closest to
        const targetHole = num || 1;
        if (!holes.has(targetHole)) {
          holes.set(targetHole, {
            hole_number: targetHole,
            tee_locations: [],
            bunkers: [],
            water_hazards: [],
          });
        }
        holes.get(targetHole)!.water_hazards.push({ polygon });
      }
    }
  });

  // Sort by hole number
  return Array.from(holes.values()).sort((a, b) => a.hole_number - b.hole_number);
}

/**
 * Main function to fetch and process course data
 */
async function fetchCourseHoleData(
  courseName: string,
  lat: number,
  lon: number
): Promise<HoleData[]> {
  console.log(`\n${"=".repeat(60)}`);
  console.log(`🏌️  FETCHING HOLE DATA FOR: ${courseName}`);
  console.log(`📍 Location: ${lat}, ${lon}`);
  console.log("=".repeat(60) + "\n");

  try {
    // Query OSM
    const elements = await queryGolfCourseFeatures(courseName, lat, lon, 2000);

    console.log(`✅ Found ${elements.length} OSM elements\n`);

    if (elements.length === 0) {
      console.log("⚠️  No golf course features found in OSM for this location.");
      console.log("   This course may not be mapped in detail yet.\n");
      return [];
    }

    // Process into structured data
    const holeData = processOSMData(elements);

    console.log(`✅ Processed ${holeData.length} holes\n`);

    // Display summary
    console.log("📊 HOLE DATA SUMMARY:");
    console.log("-".repeat(60));
    holeData.forEach((hole) => {
      console.log(`\nHole ${hole.hole_number}${hole.par ? ` - Par ${hole.par}` : ""}:`);
      console.log(`  Tees: ${hole.tee_locations.length}`);
      console.log(`  Green: ${hole.green ? "✅" : "❌"}`);
      console.log(`  Fairway: ${hole.fairway ? "✅" : "❌"}`);
      console.log(`  Bunkers: ${hole.bunkers.length}`);
      console.log(`  Water hazards: ${hole.water_hazards.length}`);
    });

    return holeData;
  } catch (error: any) {
    console.error(`❌ Error:`, error.message);
    return [];
  }
}

/**
 * Convert hole data to JSON format for database insertion
 */
function formatForDatabase(holeData: HoleData[]): any[] {
  return holeData.map((hole) => ({
    hole_number: hole.hole_number,
    par: hole.par || 4, // Default par
    tee_locations: hole.tee_locations,
    green_center: hole.green_center,
    green: hole.green,
    fairway: hole.fairway,
    bunkers: hole.bunkers,
    water_hazards: hole.water_hazards,
  }));
}

// Example usage for famous courses
async function main() {
  const courses = [
    {
      name: "Pebble Beach Golf Links",
      lat: 36.5684,
      lon: -121.9511,
    },
    {
      name: "St Andrews - Old Course",
      lat: 56.3432,
      lon: -2.8024,
    },
    {
      name: "TPC Sawgrass (Stadium)",
      lat: 30.1977,
      lon: -81.3987,
    },
  ];

  for (const course of courses) {
    const holeData = await fetchCourseHoleData(course.name, course.lat, course.lon);

    if (holeData.length > 0) {
      const formatted = formatForDatabase(holeData);
      console.log("\n" + "=".repeat(60));
      console.log("📋 JSON FORMATTED DATA:");
      console.log("=".repeat(60));
      console.log(JSON.stringify(formatted, null, 2));
      console.log("\n");

      // Save to file
      const fs = await import("fs/promises");
      await fs.writeFile(
        `hole-data-${course.name.toLowerCase().replace(/\s+/g, "-")}.json`,
        JSON.stringify(formatted, null, 2)
      );
      console.log(`💾 Saved to hole-data-${course.name.toLowerCase().replace(/\s+/g, "-")}.json\n`);
    }

    // Wait between requests to be polite to OSM
    await new Promise((resolve) => setTimeout(resolve, 2000));
  }
}

// Run if called directly
if (require.main === module) {
  main().catch(console.error);
}

export { fetchCourseHoleData, formatForDatabase, type HoleData };
