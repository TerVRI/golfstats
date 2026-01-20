/**
 * Check which courses have hole_data for visualization
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
  console.log('✅ Loaded environment variables from .env.local');
} catch (error) {
  // .env.local doesn't exist or can't be read - that's okay
}

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('❌ Missing Supabase credentials');
  console.error('Please set NEXT_PUBLIC_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkCoursesWithVisualization() {
  console.log('🔍 Checking courses with hole_data...\n');

  try {
    // Get all courses with hole_data
    const { data: courses, error } = await supabase
      .from('courses')
      .select('id, name, city, state, country, hole_data')
      .not('hole_data', 'is', null)
      .order('name', { ascending: true });

    if (error) throw error;

    if (!courses || courses.length === 0) {
      console.log('❌ No courses found with hole_data');
      console.log('\n💡 To add demo data, run:');
      console.log('   npx tsx scripts/add-demo-hole-data.ts\n');
      return;
    }

    console.log(`✅ Found ${courses.length} course(s) with hole_data:\n`);

    courses.forEach((course, index) => {
      const holeData = course.hole_data;
      const holeCount = Array.isArray(holeData) ? holeData.length : 0;
      const hasPolygons = Array.isArray(holeData) && holeData.some((hole: any) => 
        hole.fairway || hole.green || hole.bunkers || hole.water_hazards
      );

      console.log(`${index + 1}. ${course.name}`);
      console.log(`   Location: ${course.city || 'N/A'}, ${course.state || course.country || 'N/A'}`);
      console.log(`   Holes: ${holeCount}`);
      console.log(`   Has polygons: ${hasPolygons ? '✅' : '❌ (points only)'}`);
      console.log(`   Course ID: ${course.id}`);
      console.log('');
    });

    console.log('\n📝 To view a course:');
    console.log(`   Web: /courses/${courses[0]?.id}`);
    console.log(`   Or search for: "${courses[0]?.name}"\n`);

    // Check for courses that might need data
    const { data: popularCourses } = await supabase
      .from('courses')
      .select('id, name, city, state')
      .or('name.ilike.%Pebble Beach%,name.ilike.%Augusta%,name.ilike.%St Andrews%,name.ilike.%TPC Sawgrass%')
      .is('hole_data', null)
      .limit(10);

    if (popularCourses && popularCourses.length > 0) {
      console.log('💡 Popular courses without hole_data:');
      popularCourses.forEach(course => {
        console.log(`   - ${course.name} (${course.city || 'N/A'})`);
      });
      console.log('\n   Run: npx tsx scripts/add-demo-hole-data.ts to add data\n');
    }

  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

checkCoursesWithVisualization();
