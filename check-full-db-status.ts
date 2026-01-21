import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
import * as path from 'path';

dotenv.config({ path: path.join(process.cwd(), 'apps/web/.env.local') });

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL || 'https://kanvhqwrfkzqktuvpxnp.supabase.co';
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY || '';

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkFullStatus() {
  console.log('🔍 Checking FULL database status (all courses)...\n');

  // Get total count
  let allContribs: any[] = [];
  let offset = 0;
  const pageSize = 1000;
  let hasMore = true;

  while (hasMore) {
    const { data, error } = await supabase
      .from('course_contributions')
      .select('id, name, country, city, latitude, longitude, geocoded')
      .not('latitude', 'is', null)
      .not('longitude', 'is', null)
      .range(offset, offset + pageSize - 1);

    if (error) {
      console.error('Error:', error);
      break;
    }

    if (data && data.length > 0) {
      allContribs = allContribs.concat(data);
      offset += data.length;
      hasMore = data.length === pageSize;
      console.log(`  📥 Fetched ${allContribs.length} courses...`);
    } else {
      hasMore = false;
    }
  }

  const total = allContribs.length;
  const unknownCountry = allContribs.filter(c => !c.country || c.country === 'Unknown' || c.country.trim() === 'Unknown').length;
  const noCity = allContribs.filter(c => !c.city || c.city.trim() === '').length;
  const geocoded = allContribs.filter(c => c.geocoded === true).length;
  const unknownWithCoords = allContribs.filter(c => (!c.country || c.country === 'Unknown' || c.country.trim() === 'Unknown') && c.latitude && c.longitude).length;

  console.log('\n📊 FULL course_contributions table:');
  console.log(`   Total with coordinates: ${total.toLocaleString()}`);
  console.log(`   Geocoded flag set: ${geocoded.toLocaleString()} (${(geocoded/total*100).toFixed(1)}%)`);
  console.log(`   Unknown country: ${unknownCountry.toLocaleString()} (${(unknownCountry/total*100).toFixed(1)}%)`);
  console.log(`   No city: ${noCity.toLocaleString()} (${(noCity/total*100).toFixed(1)}%)`);
  console.log(`   Unknown country WITH coordinates: ${unknownWithCoords.toLocaleString()}`);
  console.log('');

  // Show breakdown of country values
  const countryCounts: Record<string, number> = {};
  allContribs.forEach(c => {
    const country = c.country || 'NULL';
    countryCounts[country] = (countryCounts[country] || 0) + 1;
  });

  console.log('📊 Top 10 country values:');
  Object.entries(countryCounts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10)
    .forEach(([country, count]) => {
      console.log(`   "${country}": ${count.toLocaleString()}`);
    });
}

checkFullStatus().catch(console.error);
