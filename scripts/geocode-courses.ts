/**
 * Geocode courses with coordinates but missing location data
 * Uses Nominatim (OSM's geocoding service) to reverse geocode coordinates
 * and fill in missing country, city, and state information
 */

import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
import * as path from 'path';

// Load environment variables - try multiple locations
const envPaths = [
  path.join(process.cwd(), 'apps/web/.env.local'),
  path.join(process.cwd(), '.env.local'),
  path.join(process.cwd(), '.env'),
];

for (const envPath of envPaths) {
  if (require('fs').existsSync(envPath)) {
    dotenv.config({ path: envPath });
    console.log(`📁 Loaded env from: ${envPath}`);
    break;
  }
}

// Try multiple possible env variable names
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || 
                     process.env.SUPABASE_URL ||
                     process.env.VITE_SUPABASE_URL ||
                     'https://kanvhqwrfkzqktuvpxnp.supabase.co'; // Fallback to known URL
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY;

console.log('🔍 Checking environment variables...');
console.log(`   SUPABASE_URL: ${supabaseUrl ? '✅ Found' : '❌ Missing'}`);
console.log(`   SUPABASE_KEY: ${supabaseKey ? '✅ Found' : '❌ Missing'}`);

if (!supabaseUrl || !supabaseKey) {
  console.error('\n❌ Missing Supabase credentials');
  console.error('   Required: NEXT_PUBLIC_SUPABASE_URL (or SUPABASE_URL)');
  console.error('   Required: SUPABASE_SERVICE_ROLE_KEY (or SUPABASE_SERVICE_KEY)');
  console.error(`   Env file loaded from: ${path.join(process.cwd(), 'apps/web/.env.local')}`);
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

// Nominatim API (OSM's free geocoding service)
const NOMINATIM_API = 'https://nominatim.openstreetmap.org/reverse';

interface GeocodeResult {
  country?: string;
  country_code?: string;
  city?: string;
  state?: string;
  county?: string;
  postcode?: string;
  address?: {
    country?: string;
    country_code?: string;
    city?: string;
    town?: string;
    village?: string;
    state?: string;
    county?: string;
    postcode?: string;
  };
}

interface Course {
  id: string;
  name: string;
  latitude: number;
  longitude: number;
  country: string | null;
  city: string | null;
  state: string | null;
  address: string | null;
  phone: string | null;
  website: string | null;
  osm_id: string | null;
  source: string | null;
  geocoded?: boolean | null;
}

/**
 * Reverse geocode coordinates to get location data
 */
async function reverseGeocode(lat: number, lon: number): Promise<GeocodeResult | null> {
  try {
    // Nominatim requires a User-Agent header
    const response = await fetch(
      `${NOMINATIM_API}?lat=${lat}&lon=${lon}&format=json&addressdetails=1`,
      {
        headers: {
          'User-Agent': 'RoundCaddy-GolfStats/1.0 (golf course geocoding)',
        },
      }
    );

    if (!response.ok) {
      console.error(`  ⚠️  Geocoding failed: ${response.status} ${response.statusText}`);
      return null;
    }

    const data = await response.json();
    
    // Rate limiting: Nominatim allows 1 request per second
    await new Promise(resolve => setTimeout(resolve, 1100));
    
    return data;
  } catch (error: any) {
    console.error(`  ⚠️  Geocoding error: ${error.message}`);
    return null;
  }
}

/**
 * Extract location data from geocoding result
 */
function extractLocationData(geocodeResult: GeocodeResult): {
  country: string | null;
  city: string | null;
  state: string | null;
} {
  const addr = geocodeResult.address || {};
  
  // Country: prefer country_code (ISO code) over full name
  const country = geocodeResult.country_code?.toUpperCase() || 
                  addr.country_code?.toUpperCase() || 
                  geocodeResult.country || 
                  addr.country || 
                  null;

  // City: try city, town, or village
  const city = addr.city || addr.town || addr.village || null;

  // State: try state or county
  const state = addr.state || addr.county || geocodeResult.state || geocodeResult.county || null;

  return { country, city, state };
}

/**
 * Fetch courses that need geocoding
 */
async function getCoursesNeedingGeocoding(limit: number = 10000): Promise<Course[]> {
  console.log('📋 Fetching courses that need geocoding...\n');

  // Fetch all courses with coordinates but missing country or city
  // Use pagination to get all courses, not just first 100
  let allCourses: Course[] = [];
  let offset = 0;
  const pageSize = 1000;
  let hasMore = true;

  // Fetch from course_contributions
  // Get ALL courses with coordinates, then filter for those needing geocoding
  while (hasMore && allCourses.length < limit) {
    const { data: courses, error } = await supabase
      .from('course_contributions')
      .select('id, name, latitude, longitude, country, city, state, address, phone, website, osm_id, source, geocoded')
      .not('latitude', 'is', null)
      .not('longitude', 'is', null)
      .eq('source', 'osm')
      // Resume support: don't refetch rows we've already processed
      .or('geocoded.is.null,geocoded.eq.false')
      .range(offset, offset + pageSize - 1);

    if (error) {
      throw error;
    }

    if (courses && courses.length > 0) {
      // Filter to only courses that need geocoding
      const needsGeocoding = courses.filter(c => {
        // Extra safety: if a row is already marked geocoded, skip it.
        if ((c as any).geocoded === true) return false;
        const country = c.country?.trim();
        const city = c.city?.trim();
        // Need geocoding if: no country, country is "Unknown", or no city
        return !country || country === 'Unknown' || !city;
      });
      
      allCourses = allCourses.concat(needsGeocoding.map(c => ({ ...c, osm_id: c.osm_id, source: c.source || 'osm' })));
      offset += courses.length;
      hasMore = courses.length === pageSize;
      console.log(`  📥 Fetched ${allCourses.length} courses needing geocoding from course_contributions...`);
    } else {
      hasMore = false;
    }
  }

  // Also check courses table (but limit to avoid duplicates)
  offset = 0;
  hasMore = true;
  const existingIds = new Set(allCourses.map(c => c.id));

  while (hasMore && allCourses.length < limit) {
    const { data: coursesData, error: coursesError } = await supabase
      .from('courses')
      .select('id, name, latitude, longitude, country, city, state, address, phone, website')
      .not('latitude', 'is', null)
      .not('longitude', 'is', null)
      .range(offset, offset + pageSize - 1);

    if (coursesError) {
      console.warn('⚠️  Error fetching from courses table:', coursesError.message);
      hasMore = false;
      break;
    }

    if (coursesData && coursesData.length > 0) {
      // Filter to only courses that need geocoding and not already in our list
      const needsGeocoding = coursesData.filter(c => {
        if (existingIds.has(c.id)) return false;
        const country = c.country?.trim();
        const city = c.city?.trim();
        // Need geocoding if: no country, country is "Unknown", or no city
        return !country || country === 'Unknown' || !city;
      });
      
      const newCourses = needsGeocoding.map(c => ({ ...c, osm_id: null, source: null }));
      
      allCourses = allCourses.concat(newCourses);
      offset += coursesData.length;
      hasMore = coursesData.length === pageSize;
      console.log(`  📥 Fetched ${newCourses.length} new courses needing geocoding from courses table (total: ${allCourses.length})...`);
    } else {
      hasMore = false;
    }
  }

  // Deduplicate by coordinates (within 0.001 degrees ≈ 100m)
  const uniqueCourses: Course[] = [];
  const seen = new Set<string>();

  for (const course of allCourses) {
    const key = `${course.latitude?.toFixed(3)},${course.longitude?.toFixed(3)}`;
    if (!seen.has(key)) {
      seen.add(key);
      uniqueCourses.push(course as Course);
    }
  }

  return uniqueCourses;
}

/**
 * Update course with geocoded data
 */
async function updateCourse(
  courseId: string,
  updates: {
    country?: string | null;
    city?: string | null;
    state?: string | null;
    geocoded?: boolean;
    geocoded_at?: string;
  },
  table: 'course_contributions' | 'courses'
): Promise<boolean> {
  try {
    const { error } = await supabase
      .from(table)
      .update(updates)
      .eq('id', courseId);

    if (error) {
      console.error(`  ❌ Update error: ${error.message}`);
      return false;
    }

    return true;
  } catch (error: any) {
    console.error(`  ❌ Update error: ${error.message}`);
    return false;
  }
}

/**
 * Main geocoding function
 */
async function geocodeCourses() {
  console.log('🌍 Starting geocoding process...\n');
  console.log('📝 Note: Using Nominatim (OSM geocoding service)');
  console.log('   Rate limit: 1 request per second\n');

  // Get courses needing geocoding (no limit - get all)
  const courses = await getCoursesNeedingGeocoding(50000); // Process up to 50k courses

  if (courses.length === 0) {
    console.log('✅ No courses need geocoding!');
    return;
  }

  // Remove duplicates by ID (in case we have same course from both tables)
  const uniqueCourses = Array.from(
    new Map(courses.map(c => [c.id, c])).values()
  );
  
  console.log(`📊 Found ${courses.length} courses needing geocoding`);
  console.log(`📊 After deduplication: ${uniqueCourses.length} unique courses\n`);

  let successCount = 0;
  let errorCount = 0;
  let skippedCount = 0;

  for (let i = 0; i < uniqueCourses.length; i++) {
    const course = uniqueCourses[i];
    const progress = `[${i + 1}/${uniqueCourses.length}]`;

    console.log(`${progress} Processing: ${course.name}`);

    // Check if we already have complete location data
    const currentCountry = course.country?.trim();
    const currentCity = course.city?.trim();
    if (currentCountry && 
        currentCountry !== 'Unknown' && 
        currentCity) {
      console.log(`  ⏭️  Skipping - already has location data (${currentCountry}, ${currentCity})`);
      skippedCount++;
      continue;
    }

    if (!course.latitude || !course.longitude) {
      console.log(`  ⏭️  Skipping - no coordinates`);
      skippedCount++;
      continue;
    }

    // Geocode
    const geocodeResult = await reverseGeocode(course.latitude, course.longitude);

    if (!geocodeResult) {
      console.log(`  ❌ Geocoding failed`);
      errorCount++;
      continue;
    }

    const { country: geocodedCountry, city: geocodedCity, state: geocodedState } = extractLocationData(geocodeResult);

    // Prepare updates
    const updates: any = {
      geocoded: true,
      geocoded_at: new Date().toISOString(),
    };

    // Only update if we got better data
    if (geocodedCountry && (!currentCountry || currentCountry === 'Unknown')) {
      updates.country = geocodedCountry;
    }
    if (geocodedCity && !currentCity) {
      updates.city = geocodedCity;
    }
    if (geocodedState && !course.state?.trim()) {
      updates.state = geocodedState;
    }

    // Determine which table to update
    const table = course.osm_id ? 'course_contributions' : 'courses';

    // Update database
    const updated = await updateCourse(course.id, updates, table);

    if (updated) {
      const updatesList = Object.keys(updates).filter(k => k !== 'geocoded' && k !== 'geocoded_at');
      if (updatesList.length > 0) {
        console.log(`  ✅ Updated: ${updatesList.join(', ')}`);
        if (geocodedCountry) console.log(`     Country: ${geocodedCountry}`);
        if (geocodedCity) console.log(`     City: ${geocodedCity}`);
        if (geocodedState) console.log(`     State: ${geocodedState}`);
      } else {
        console.log(`  ℹ️  No new data to update`);
      }
      successCount++;
    } else {
      errorCount++;
    }

    // Progress update every 10 courses
    if ((i + 1) % 10 === 0) {
      console.log(`\n📊 Progress: ${successCount} updated, ${errorCount} errors, ${skippedCount} skipped\n`);
    }
  }

  console.log('\n' + '='.repeat(60));
  console.log('📊 GEOCODING SUMMARY');
  console.log('='.repeat(60));
  console.log(`Total processed: ${uniqueCourses.length}`);
  console.log(`✅ Successfully updated: ${successCount}`);
  console.log(`❌ Errors: ${errorCount}`);
  console.log(`⏭️  Skipped: ${skippedCount}`);
  console.log('='.repeat(60));

  if (successCount > 0) {
    console.log('\n💡 Next steps:');
    console.log('   1. Re-export courses bundle: npx tsx scripts/export-courses-for-bundle.ts');
    console.log('   2. Rebuild iOS app to see updated location data');
  }
}

// Check for website and phone data
async function checkContactData() {
  console.log('\n📞 Checking website and phone data...\n');

  const { data: courses, error } = await supabase
    .from('course_contributions')
    .select('id, name, phone, website, source')
    .eq('source', 'osm')
    .limit(100);

  if (error) {
    console.error('❌ Error:', error.message);
    return;
  }

  const withPhone = courses?.filter(c => c.phone).length || 0;
  const withWebsite = courses?.filter(c => c.website).length || 0;
  const withBoth = courses?.filter(c => c.phone && c.website).length || 0;

  console.log(`📊 Sample of 100 OSM courses:`);
  console.log(`   With phone: ${withPhone}%`);
  console.log(`   With website: ${withWebsite}%`);
  console.log(`   With both: ${withBoth}%`);

  if (withPhone > 0 || withWebsite > 0) {
    console.log(`\n✅ Contact data is being stored!`);
    console.log(`   Sample courses with contact info:`);
    courses?.slice(0, 5).forEach(c => {
      if (c.phone || c.website) {
        console.log(`   - ${c.name}`);
        if (c.phone) console.log(`     Phone: ${c.phone}`);
        if (c.website) console.log(`     Website: ${c.website}`);
      }
    });
  } else {
    console.log(`\n⚠️  No contact data found in sample`);
    console.log(`   This means OSM entries don't have phone/website tags`);
  }
}

// Run both
async function main() {
  await checkContactData();
  await geocodeCourses();
}

main().catch(console.error);
