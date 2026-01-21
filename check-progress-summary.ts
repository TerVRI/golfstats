import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
import * as path from 'path';

dotenv.config({ path: path.join(process.cwd(), 'apps/web/.env.local') });

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL || 'https://kanvhqwrfkzqktuvpxnp.supabase.co';
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY || '';

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkProgress() {
  // Get total courses with coordinates
  const { count: totalCount } = await supabase
    .from('course_contributions')
    .select('*', { count: 'exact', head: true })
    .not('latitude', 'is', null)
    .not('longitude', 'is', null);

  // Get courses still with "Unknown"
  const { count: unknownCount } = await supabase
    .from('course_contributions')
    .select('*', { count: 'exact', head: true })
    .eq('country', 'Unknown')
    .not('latitude', 'is', null)
    .not('longitude', 'is', null);

  // Get courses that have been geocoded
  const { count: geocodedCount } = await supabase
    .from('course_contributions')
    .select('*', { count: 'exact', head: true })
    .eq('geocoded', true)
    .not('geocoded_at', 'is', null);

  const total = totalCount || 0;
  const unknown = unknownCount || 0;
  const geocoded = geocodedCount || 0;
  const updated = total - unknown;
  const progress = total > 0 ? ((geocoded / total) * 100).toFixed(1) : '0';

  console.log('📊 Geocoding Progress Summary');
  console.log('==============================');
  console.log(`Total courses with coordinates: ${total.toLocaleString()}`);
  console.log(`✅ Geocoded (flag set): ${geocoded.toLocaleString()} (${progress}%)`);
  console.log(`✅ Updated (non-Unknown): ${updated.toLocaleString()}`);
  console.log(`⚠️  Still "Unknown": ${unknown.toLocaleString()}`);
  console.log('');
  console.log(`📈 Progress: ${progress}% complete`);
  console.log(`⏱️  Estimated time remaining: ~${Math.ceil((unknown / 1) / 3600)} hours (at 1 req/sec)`);
}

checkProgress().catch(console.error);
