/**
 * Query OSM for a sample golf course to see what data is actually available
 * This will show us what OSM contains vs what we need to add
 */

const OVERPASS_API = "https://overpass-api.de/api/interpreter";

async function querySampleCourse() {
  console.log("🔍 Querying OSM for a well-known golf course...\n");
  
  // Query for St Andrews (famous course, likely well-tagged in OSM)
  const query = `
    [out:json][timeout:25];
    (
      way["leisure"="golf_course"]["name"~"St Andrews",i];
      relation["leisure"="golf_course"]["name"~"St Andrews",i];
    );
    out center;
    out tags;
    (._;>;);
    out skel;
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
    const elements = data.elements || [];

    if (elements.length === 0) {
      console.log("❌ No courses found. Trying a different query...\n");
      
      // Try a broader query
      const broadQuery = `
        [out:json][timeout:25];
        (
          way["leisure"="golf_course"](around:50000,56.3398,-2.8081);
        );
        out center;
        out tags;
      `;
      
      const broadResponse = await fetch(OVERPASS_API, {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: `data=${encodeURIComponent(broadQuery)}`,
      });
      
      const broadData = await broadResponse.json();
      const broadElements = broadData.elements || [];
      
      if (broadElements.length > 0) {
        console.log(`✅ Found ${broadElements.length} courses near St Andrews\n`);
        displayCourse(broadElements[0]);
      } else {
        console.log("❌ Still no courses found");
      }
      return;
    }

    console.log(`✅ Found ${elements.length} course(s)\n`);
    
    // Find the main course (not a member of a relation)
    const mainCourse = elements.find((e: any) => 
      e.tags?.["leisure"] === "golf_course" && 
      e.type !== "node" // Prefer ways/relations over nodes
    ) || elements[0];

    displayCourse(mainCourse);
    
  } catch (error: any) {
    console.error("❌ Error:", error.message);
  }
}

function displayCourse(element: any) {
  console.log("=".repeat(60));
  console.log("📋 SAMPLE OSM GOLF COURSE DATA");
  console.log("=".repeat(60));
  console.log(`\nType: ${element.type}`);
  console.log(`OSM ID: ${element.id}`);
  
  const tags = element.tags || {};
  const center = element.center || {};
  const lat = element.lat || center.lat;
  const lon = element.lon || center.lon;
  
  console.log(`\n📍 COORDINATES:`);
  if (lat && lon) {
    console.log(`  Latitude: ${lat}`);
    console.log(`  Longitude: ${lon}`);
  } else {
    console.log(`  ⚠️  NO COORDINATES!`);
  }
  
  console.log(`\n📝 ALL TAGS (${Object.keys(tags).length} total):`);
  console.log("-".repeat(60));
  
  // Group tags by category
  const nameTags: Record<string, string> = {};
  const addressTags: Record<string, string> = {};
  const contactTags: Record<string, string> = {};
  const golfTags: Record<string, string> = {};
  const otherTags: Record<string, string> = {};
  
  for (const [key, value] of Object.entries(tags)) {
    if (key.startsWith("name")) {
      nameTags[key] = value as string;
    } else if (key.startsWith("addr:")) {
      addressTags[key] = value as string;
    } else if (key.startsWith("contact:") || key === "phone" || key === "website" || key === "email") {
      contactTags[key] = value as string;
    } else if (key.includes("golf") || key.includes("hole") || key.includes("par") || key.includes("tee") || key.includes("yard")) {
      golfTags[key] = value as string;
    } else {
      otherTags[key] = value as string;
    }
  }
  
  if (Object.keys(nameTags).length > 0) {
    console.log("\n🏷️  NAME TAGS:");
    for (const [key, value] of Object.entries(nameTags)) {
      console.log(`  ${key}: ${value}`);
    }
  }
  
  if (Object.keys(addressTags).length > 0) {
    console.log("\n📍 ADDRESS TAGS:");
    for (const [key, value] of Object.entries(addressTags)) {
      console.log(`  ${key}: ${value}`);
    }
  } else {
    console.log("\n📍 ADDRESS TAGS: ⚠️  NONE!");
  }
  
  if (Object.keys(contactTags).length > 0) {
    console.log("\n📞 CONTACT TAGS:");
    for (const [key, value] of Object.entries(contactTags)) {
      console.log(`  ${key}: ${value}`);
    }
  }
  
  if (Object.keys(golfTags).length > 0) {
    console.log("\n🏌️  GOLF-SPECIFIC TAGS:");
    for (const [key, value] of Object.entries(golfTags)) {
      console.log(`  ${key}: ${value}`);
    }
  } else {
    console.log("\n🏌️  GOLF-SPECIFIC TAGS: ⚠️  NONE!");
    console.log("   (No hole data, pars, tees, yardages, etc.)");
  }
  
  if (Object.keys(otherTags).length > 0) {
    console.log("\n📋 OTHER TAGS:");
    for (const [key, value] of Object.entries(otherTags)) {
      console.log(`  ${key}: ${value}`);
    }
  }
  
  console.log("\n" + "=".repeat(60));
  console.log("📊 SUMMARY:");
  console.log("=".repeat(60));
  console.log(`✅ Has coordinates: ${lat && lon ? "YES" : "NO"}`);
  console.log(`✅ Has name: ${tags.name ? "YES" : "NO"}`);
  console.log(`✅ Has country: ${tags["addr:country"] || tags["addr:country_code"] ? "YES" : "NO"}`);
  console.log(`✅ Has city: ${tags["addr:city"] ? "YES" : "NO"}`);
  console.log(`✅ Has address: ${tags["addr:street"] ? "YES" : "NO"}`);
  console.log(`✅ Has phone: ${tags.phone || tags["contact:phone"] ? "YES" : "NO"}`);
  console.log(`✅ Has website: ${tags.website || tags["contact:website"] ? "YES" : "NO"}`);
  console.log(`❌ Has hole data: ${Object.keys(golfTags).length > 0 ? "YES" : "NO"}`);
  console.log(`❌ Has PAR information: ${tags.par || tags.holes ? "YES" : "NO"}`);
  console.log(`❌ Has tee information: ${tags.tee || tags.tees ? "YES" : "NO"}`);
  console.log(`❌ Has yardage information: ${tags.yardage || tags.yardages ? "YES" : "NO"}`);
  
  console.log("\n💡 CONCLUSION:");
  console.log("   OSM contains basic location/address data only.");
  console.log("   Detailed golf course data (holes, pars, tees, yardages)");
  console.log("   must be added by users through the contribution system.");
  console.log("=".repeat(60));
}

querySampleCourse();
