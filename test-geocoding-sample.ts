import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
import * as path from 'path';

dotenv.config({ path: path.join(process.cwd(), 'apps/web/.env.local') });

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL || 'https://kanvhqwrfkzqktuvpxnp.supabase.co';
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY || '';

const supabase = createClient(supabaseUrl, supabaseKey);

async function testGeocoding() {
  // Get a sample course with "Unknown" country
  const { data: courses, error } = await supabase
    .from('course_contributions')
    .select('id, name, latitude, longitude, country, city, state')
    .eq('country', 'Unknown')
    .not('latitude', 'is', null)
    .not('longitude', 'is', null)
    .limit(3);

  if (error || !courses || courses.length === 0) {
    console.error('No courses found');
    return;
  }

  for (const course of courses) {
    console.log(`\n📍 Testing: ${course.name}`);
    console.log(`   Current: country="${course.country}", city="${course.city || 'NULL'}"`);
    console.log(`   Coordinates: ${course.latitude}, ${course.longitude}`);
    
    // Test geocoding
    const response = await fetch(
      `https://nominatim.openstreetmap.org/reverse?lat=${course.latitude}&lon=${course.longitude}&format=json&addressdetails=1`,
      {
        headers: {
          'User-Agent': 'RoundCaddy-GolfStats/1.0 (golf course geocoding)',
        },
      }
    );

    if (response.ok) {
      const data = await response.json();
      const addr = data.address || {};
      const country = data.country_code?.toUpperCase() || addr.country_code?.toUpperCase() || data.country || addr.country || null;
      const city = addr.city || addr.town || addr.village || null;
      const state = addr.state || addr.county || data.state || data.county || null;
      
      console.log(`   Geocoded: country="${country}", city="${city || 'NULL'}", state="${state || 'NULL'}"`);
      console.log(`   Full response:`, JSON.stringify(data, null, 2).substring(0, 500));
    } else {
      console.log(`   ❌ Geocoding failed: ${response.status}`);
    }
    
    await new Promise(resolve => setTimeout(resolve, 1100)); // Rate limit
  }
}

testGeocoding().catch(console.error);
