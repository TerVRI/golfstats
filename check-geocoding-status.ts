import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
import * as path from 'path';

// Load environment variables
dotenv.config({ path: path.join(process.cwd(), 'apps/web/.env.local') });

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL || 'https://kanvhqwrfkzqktuvpxnp.supabase.co';
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY || '';

if (!supabaseKey) {
  console.error('❌ Missing Supabase credentials');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkStatus() {
  console.log('🔍 Checking geocoding status in database...\n');

  // Check course_contributions
  const { data: contribs, error: contribsError } = await supabase
    .from('course_contributions')
    .select('id, name, country, city, latitude, longitude, geocoded')
    .not('latitude', 'is', null)
    .not('longitude', 'is', null)
    .limit(50000);

  if (contribsError) {
    console.error('Error:', contribsError);
    return;
  }

  const total = contribs?.length || 0;
  const unknownCountry = contribs?.filter(c => !c.country || c.country === 'Unknown').length || 0;
  const noCity = contribs?.filter(c => !c.city).length || 0;
  const geocoded = contribs?.filter(c => c.geocoded === true).length || 0;
  const unknownWithCoords = contribs?.filter(c => (!c.country || c.country === 'Unknown') && c.latitude && c.longitude).length || 0;

  console.log('📊 course_contributions table:');
  console.log(`   Total with coordinates: ${total.toLocaleString()}`);
  console.log(`   Geocoded flag set: ${geocoded.toLocaleString()} (${(geocoded/total*100).toFixed(1)}%)`);
  console.log(`   Unknown country: ${unknownCountry.toLocaleString()} (${(unknownCountry/total*100).toFixed(1)}%)`);
  console.log(`   No city: ${noCity.toLocaleString()} (${(noCity/total*100).toFixed(1)}%)`);
  console.log(`   Unknown country WITH coordinates: ${unknownWithCoords.toLocaleString()}`);
  console.log('');

  // Sample a few courses to see what's happening
  const samples = contribs?.slice(0, 5).filter(c => (!c.country || c.country === 'Unknown') && c.latitude && c.longitude) || [];
  if (samples.length > 0) {
    console.log('📋 Sample courses with coordinates but Unknown country:');
    samples.forEach(c => {
      console.log(`   - ${c.name}: country="${c.country || 'NULL'}", city="${c.city || 'NULL'}", geocoded=${c.geocoded}`);
    });
  }
}

checkStatus().catch(console.error);
