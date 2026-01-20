/**
 * Find course IDs for Pebble Beach and St Andrews
 */

import { createClient } from '@supabase/supabase-js';
import { readFileSync } from 'fs';
import { join } from 'path';

// Load .env.local if it exists
try {
  const envPath = join(process.cwd(), '.env.local');
  const envFile = readFileSync(envPath, 'utf-8');
  envFile.split('\n').forEach((line) => {
    const trimmed = line.trim();
    if (trimmed && !trimmed.startsWith('#') && trimmed.includes('=')) {
      const [key, ...valueParts] = trimmed.split('=');
      const value = valueParts.join('=').trim();
      if (key && value && !process.env[key]) {
        process.env[key] = value;
      }
    }
  });
} catch (error) {
  // .env.local doesn't exist or can't be read - that's okay
}

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('❌ Missing Supabase credentials');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function findCourses() {
  console.log('🔍 Searching for Pebble Beach and St Andrews...\n');

  try {
    // Search for Pebble Beach
    const { data: pebbleBeach, error: pbError } = await supabase
      .from('courses')
      .select('id, name, city, state, country, hole_data')
      .or('name.ilike.%Pebble Beach%,name.ilike.%Pebble%')
      .limit(5);

    if (pbError) throw pbError;

    console.log('🏌️ Pebble Beach courses:');
    if (pebbleBeach && pebbleBeach.length > 0) {
      pebbleBeach.forEach(course => {
        const hasHoleData = course.hole_data && Array.isArray(course.hole_data) && course.hole_data.length > 0;
        console.log(`   ✅ ${course.name}`);
        console.log(`      ID: ${course.id}`);
        console.log(`      Location: ${course.city || 'N/A'}, ${course.state || course.country || 'N/A'}`);
        console.log(`      Has hole_data: ${hasHoleData ? '✅' : '❌'}`);
        console.log(`      Web URL: /courses/${course.id}`);
        console.log('');
      });
    } else {
      console.log('   ❌ No Pebble Beach courses found\n');
    }

    // Search for St Andrews
    const { data: stAndrews, error: saError } = await supabase
      .from('courses')
      .select('id, name, city, state, country, hole_data')
      .or('name.ilike.%St Andrews%,name.ilike.%St. Andrews%')
      .limit(5);

    if (saError) throw saError;

    console.log('🏌️ St Andrews courses:');
    if (stAndrews && stAndrews.length > 0) {
      stAndrews.forEach(course => {
        const hasHoleData = course.hole_data && Array.isArray(course.hole_data) && course.hole_data.length > 0;
        console.log(`   ✅ ${course.name}`);
        console.log(`      ID: ${course.id}`);
        console.log(`      Location: ${course.city || 'N/A'}, ${course.state || course.country || 'N/A'}`);
        console.log(`      Has hole_data: ${hasHoleData ? '✅' : '❌'}`);
        console.log(`      Web URL: /courses/${course.id}`);
        console.log('');
      });
    } else {
      console.log('   ❌ No St Andrews courses found\n');
    }

    // Summary
    const allCourses = [...(pebbleBeach || []), ...(stAndrews || [])];
    const coursesWithData = allCourses.filter(c => c.hole_data && Array.isArray(c.hole_data) && c.hole_data.length > 0);
    
    console.log('📊 Summary:');
    console.log(`   Total found: ${allCourses.length}`);
    console.log(`   With hole_data: ${coursesWithData.length}`);
    
    if (coursesWithData.length === 0) {
      console.log('\n💡 To add hole_data, run:');
      console.log('   npx tsx scripts/add-demo-hole-data.ts\n');
    }

  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

findCourses();
