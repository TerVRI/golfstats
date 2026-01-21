import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
import * as path from 'path';

dotenv.config({ path: path.join(process.cwd(), 'apps/web/.env.local') });

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL || 'https://kanvhqwrfkzqktuvpxnp.supabase.co';
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY || '';

const supabase = createClient(supabaseUrl, supabaseKey);

async function verifyUpdates() {
  console.log('🔍 Verifying if geocoding updates are being saved...\n');

  // Check courses that have been geocoded (geocoded flag = true)
  const { data: geocoded, error: geocodedError } = await supabase
    .from('course_contributions')
    .select('id, name, country, city, geocoded, geocoded_at')
    .eq('geocoded', true)
    .not('geocoded_at', 'is', null)
    .order('geocoded_at', { ascending: false })
    .limit(10);

  if (geocodedError) {
    console.error('Error:', geocodedError);
    return;
  }

  console.log(`📊 Courses with geocoded flag = true: ${geocoded?.length || 0}\n`);
  
  if (geocoded && geocoded.length > 0) {
    console.log('Sample geocoded courses:');
    geocoded.forEach(c => {
      console.log(`   ${c.name}: country="${c.country}", city="${c.city || 'NULL'}", geocoded_at=${c.geocoded_at}`);
    });
  } else {
    console.log('⚠️  No courses have been geocoded yet!');
    console.log('   This means the updates are not being saved to the database.');
  }

  // Check if any courses changed from "Unknown" to something else recently
  const { data: updated, error: updatedError } = await supabase
    .from('course_contributions')
    .select('id, name, country, city, geocoded, geocoded_at')
    .neq('country', 'Unknown')
    .not('country', 'is', null)
    .not('geocoded_at', 'is', null)
    .order('geocoded_at', { ascending: false })
    .limit(10);

  console.log(`\n📊 Courses with non-Unknown country and geocoded_at: ${updated?.length || 0}`);
  if (updated && updated.length > 0) {
    console.log('Sample updated courses:');
    updated.slice(0, 3).forEach(c => {
      console.log(`   ${c.name}: country="${c.country}", city="${c.city || 'NULL'}"`);
    });
  }
}

verifyUpdates().catch(console.error);
