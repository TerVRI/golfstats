import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
import * as path from 'path';

dotenv.config({ path: path.join(process.cwd(), 'apps/web/.env.local') });

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL || 'https://kanvhqwrfkzqktuvpxnp.supabase.co';
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY || '';

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkUpdate() {
  // Get a course that was just processed
  const { data: courses, error } = await supabase
    .from('course_contributions')
    .select('id, name, latitude, longitude, country, city, state, geocoded, geocoded_at')
    .eq('country', 'Unknown')
    .not('latitude', 'is', null)
    .not('longitude', 'is', null)
    .order('geocoded_at', { ascending: false, nullsFirst: false })
    .limit(5);

  if (error || !courses) {
    console.error('Error:', error);
    return;
  }

  console.log('📊 Courses with "Unknown" country (recently geocoded):\n');
  courses.forEach(c => {
    console.log(`   ${c.name}`);
    console.log(`      Country: "${c.country}"`);
    console.log(`      City: "${c.city || 'NULL'}"`);
    console.log(`      Geocoded: ${c.geocoded}`);
    console.log(`      Geocoded at: ${c.geocoded_at || 'NULL'}`);
    console.log('');
  });

  // Check if any were actually updated
  const updated = courses.filter(c => c.geocoded === true && c.country !== 'Unknown');
  console.log(`✅ Courses actually updated: ${updated.length}/${courses.length}`);
}

checkUpdate().catch(console.error);
