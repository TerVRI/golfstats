#!/usr/bin/env tsx
/**
 * Script to get statistics about golf courses in OpenStreetMap by country
 * 
 * Usage: npx tsx scripts/get-osm-golf-statistics.ts
 */

interface OSMCountryStats {
  country: string;
  countryCode?: string;
  count: number;
}

interface OSMGolfCourse {
  id: number;
  type: string;
  tags: {
    name?: string;
    "addr:country"?: string;
    "addr:country_code"?: string;
    "addr:state"?: string;
    "addr:city"?: string;
    leisure: string;
  };
  lat?: number;
  lon?: number;
  center?: {
    lat: number;
    lon: number;
  };
}

const OVERPASS_API = "https://overpass-api.de/api/interpreter";
const TIMEOUT = 180; // 3 minutes for global query

/**
 * Get all golf courses from OSM (this is a large query)
 */
async function getAllOSMGolfCourses(): Promise<OSMGolfCourse[]> {
  console.log("Querying OpenStreetMap for all golf courses...");
  console.log("This may take several minutes...");

  const query = `
    [out:json][timeout:${TIMEOUT}];
    (
      way["leisure"="golf_course"];
      relation["leisure"="golf_course"];
      node["leisure"="golf_course"];
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
    console.error("Error fetching OSM courses:", error);
    throw error;
  }
}

/**
 * Get statistics by country
 */
function getCountryStats(courses: OSMGolfCourse[]): OSMCountryStats[] {
  const countryMap = new Map<string, { count: number; code?: string }>();

  courses.forEach((course) => {
    const country = course.tags["addr:country"] || "Unknown";
    const countryCode = course.tags["addr:country_code"]?.toUpperCase();
    
    if (!countryMap.has(country)) {
      countryMap.set(country, { count: 0, code: countryCode });
    }
    
    const stats = countryMap.get(country)!;
    stats.count++;
    if (countryCode && !stats.code) {
      stats.code = countryCode;
    }
  });

  return Array.from(countryMap.entries())
    .map(([country, data]) => ({
      country,
      countryCode: data.code,
      count: data.count,
    }))
    .sort((a, b) => b.count - a.count);
}

/**
 * Get statistics by country code (ISO 3166-1 alpha-2)
 */
async function getCountryStatsByCode(): Promise<Map<string, number>> {
  console.log("Getting country statistics by country code...");
  
  // Query for each major country (to avoid timeout, we'll do this in batches)
  const majorCountries = [
    "US", "GB", "CA", "AU", "DE", "FR", "JP", "KR", "SE", "NO", "DK",
    "NL", "BE", "CH", "AT", "IT", "ES", "PT", "IE", "NZ", "ZA", "BR",
    "MX", "AR", "CL", "CO", "PE", "IN", "CN", "TH", "MY", "SG", "PH",
    "ID", "VN", "TW", "HK", "AE", "SA", "EG", "MA", "TR", "GR", "PL",
    "CZ", "HU", "RO", "BG", "HR", "RS", "SI", "SK", "FI", "IS", "EE",
    "LV", "LT", "RU", "UA", "BY", "KZ", "UZ", "IL", "JO", "LB", "IQ",
    "IR", "PK", "BD", "LK", "MM", "KH", "LA", "BN", "FJ", "PG", "NC",
    "PF", "GT", "BZ", "CR", "PA", "HN", "NI", "SV", "DO", "CU", "JM",
    "TT", "BB", "BS", "AG", "LC", "VC", "GD", "DM", "KN", "VE", "EC",
    "BO", "PY", "UY", "GY", "SR", "GF", "FK", "GS", "ZA", "ZW", "BW",
    "NA", "SZ", "LS", "MZ", "MW", "ZM", "TZ", "KE", "UG", "RW", "BI",
    "ET", "ER", "DJ", "SO", "SD", "SS", "TD", "NE", "ML", "BF", "SN",
    "GM", "GN", "SL", "LR", "CI", "GH", "TG", "BJ", "NG", "CM", "CF",
    "GQ", "GA", "CG", "CD", "AO", "ST", "CV", "MR", "MA", "DZ", "TN",
    "LY", "EG", "MA", "EH", "MU", "SC", "KM", "MG", "RE", "YT", "IO",
    "MV", "YE", "OM", "QA", "BH", "KW", "IQ", "IR", "AF", "TJ", "TM",
    "UZ", "KZ", "KG", "MN", "CN", "KP", "KR", "JP", "TW", "HK", "MO",
    "PH", "VN", "LA", "KH", "TH", "MY", "SG", "BN", "ID", "TL", "PG",
    "SB", "VU", "NC", "FJ", "PF", "CK", "NU", "TK", "TO", "WS", "AS",
    "GU", "MP", "PW", "FM", "MH", "KI", "TV", "NR", "NF", "CX", "CC",
    "AU", "NZ", "NC", "PF", "FJ", "PG", "SB", "VU", "NC", "FJ", "PF",
  ];

  const stats = new Map<string, number>();
  
  // Process in batches to avoid overwhelming the API
  const batchSize = 10;
  for (let i = 0; i < majorCountries.length; i += batchSize) {
    const batch = majorCountries.slice(i, i + batchSize);
    console.log(`Processing batch ${Math.floor(i / batchSize) + 1}...`);
    
    for (const countryCode of batch) {
      try {
        const query = `
          [out:json][timeout:60];
          (
            way["leisure"="golf_course"]["addr:country_code"="${countryCode}"];
            relation["leisure"="golf_course"]["addr:country_code"="${countryCode}"];
            node["leisure"="golf_course"]["addr:country_code"="${countryCode}"];
          );
          out count;
        `;

        const response = await fetch(OVERPASS_API, {
          method: "POST",
          headers: {
            "Content-Type": "application/x-www-form-urlencoded",
          },
          body: `data=${encodeURIComponent(query)}`,
        });

        if (response.ok) {
          const data = await response.json();
          const count = data.elements?.[0]?.tags?.total || 0;
          stats.set(countryCode, count);
          console.log(`  ${countryCode}: ${count} courses`);
        }
        
        // Rate limiting
        await new Promise(resolve => setTimeout(resolve, 1000));
      } catch (error) {
        console.error(`Error fetching ${countryCode}:`, error);
      }
    }
  }

  return stats;
}

async function main() {
  try {
    console.log("=".repeat(60));
    console.log("OpenStreetMap Golf Course Statistics");
    console.log("=".repeat(60));
    console.log();

    // Option 1: Get all courses (slow but comprehensive)
    console.log("Method 1: Fetching all courses (this will take a while)...");
    const allCourses = await getAllOSMGolfCourses();
    console.log(`Total courses found: ${allCourses.length}`);
    console.log();

    // Get country statistics
    const countryStats = getCountryStats(allCourses);
    
    console.log("=".repeat(60));
    console.log("Golf Courses by Country (from OSM tags)");
    console.log("=".repeat(60));
    console.log();
    
    console.log("Top 50 Countries:");
    console.log("-".repeat(60));
    console.log(
      `${"Country".padEnd(30)} ${"Code".padEnd(6)} ${"Count".padStart(10)}`
    );
    console.log("-".repeat(60));
    
    countryStats.slice(0, 50).forEach((stat) => {
      console.log(
        `${stat.country.padEnd(30)} ${(stat.countryCode || "").padEnd(6)} ${stat.count.toString().padStart(10)}`
      );
    });
    
    console.log();
    console.log("=".repeat(60));
    console.log("Summary");
    console.log("=".repeat(60));
    console.log(`Total courses: ${allCourses.length}`);
    console.log(`Countries with courses: ${countryStats.length}`);
    console.log(`Unknown country: ${countryStats.find(s => s.country === "Unknown")?.count || 0}`);
    console.log();

    // Option 2: Get stats by country code (faster but may miss some)
    console.log("Method 2: Getting statistics by country code...");
    console.log("(This queries major countries individually)");
    const countryCodeStats = await getCountryStatsByCode();
    
    console.log();
    console.log("=".repeat(60));
    console.log("Golf Courses by Country Code");
    console.log("=".repeat(60));
    const sortedByCode = Array.from(countryCodeStats.entries())
      .sort((a, b) => b[1] - a[1])
      .slice(0, 30);
    
    sortedByCode.forEach(([code, count]) => {
      console.log(`${code.padEnd(6)} ${count.toString().padStart(10)}`);
    });

    // Save results to file
    const fs = await import("fs/promises");
    const results = {
      total: allCourses.length,
      byCountry: countryStats,
      byCountryCode: Object.fromEntries(countryCodeStats),
      timestamp: new Date().toISOString(),
    };
    
    await fs.writeFile(
      "osm-golf-statistics.json",
      JSON.stringify(results, null, 2)
    );
    
    console.log();
    console.log("Results saved to: osm-golf-statistics.json");
    
  } catch (error) {
    console.error("Error:", error);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}
