#!/usr/bin/env tsx
/**
 * Export basic course data to JSON for iOS app bundle
 * This exports only essential fields (no hole_data) to keep size small
 */

import { createClient } from '@supabase/supabase-js';
import * as fs from 'fs';
import * as path from 'path';
import * as dotenv from 'dotenv';

// Load environment variables - try multiple locations
const envPaths = [
  path.join(process.cwd(), 'apps/web/.env.local'),
  path.join(process.cwd(), '.env.local'),
  path.join(process.cwd(), '.env'),
];

for (const envPath of envPaths) {
  if (fs.existsSync(envPath)) {
    dotenv.config({ path: envPath });
    console.log(`📝 Loaded env from: ${envPath}`);
    break;
  }
}

// Try to load from env, fallback to known values
const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL || 'https://kanvhqwrfkzqktuvpxnp.supabase.co';
const supabaseKey = process.env.SUPABASE_SERVICE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || process.env.SUPABASE_ANON_KEY;

if (!supabaseKey) {
  console.error('❌ Missing Supabase service key');
  console.error('Required: SUPABASE_SERVICE_KEY or SUPABASE_SERVICE_ROLE_KEY');
  console.error('\nPlease set one of these in your .env.local file:');
  console.error('  SUPABASE_SERVICE_KEY=your-service-key');
  console.error('  or');
  console.error('  SUPABASE_SERVICE_ROLE_KEY=your-service-key');
  process.exit(1);
}

console.log(`✅ Using Supabase URL: ${supabaseUrl}`);
console.log(`✅ Service key found: ${supabaseKey.substring(0, 20)}...`);

const supabase = createClient(supabaseUrl, supabaseKey);

interface CourseExport {
  id: string;
  name: string;
  city: string | null;
  state: string | null;
  country: string | null;
  address: string | null;
  phone: string | null;
  website: string | null;
  course_rating: number | null;
  slope_rating: number | null;
  par: number | null;
  holes: number | null;
  latitude: number | null;
  longitude: number | null;
  avg_rating: number | null;
  review_count: number | null;
  updated_at: string;
  created_at: string;
}

async function exportCourses() {
  console.log('📦 Exporting courses for iOS bundle...');
  
  try {
    // Fetch all courses from courses table
    const { data: coursesData, error: coursesError } = await supabase
      .from('courses')
      .select(`
        id,
        name,
        city,
        state,
        country,
        address,
        phone,
        website,
        course_rating,
        slope_rating,
        par,
        holes,
        latitude,
        longitude,
        avg_rating,
        review_count,
        updated_at,
        created_at
      `)
      .order('name', { ascending: true });

    if (coursesError) throw coursesError;

    // Also fetch course contributions (includes OSM imports) in batches
    // Include all statuses except 'rejected' - we want pending, approved, merged, and OSM imports
    let contributionsData: any[] = [];
    let hasMore = true;
    let offset = 0;
    const batchSize = 1000;
    
    while (hasMore) {
      const { data: batch, error: contributionsError } = await supabase
        .from('course_contributions')
        .select(`
          id,
          name,
          city,
          state,
          country,
          address,
          phone,
          website,
          course_rating,
          slope_rating,
          par,
          holes,
          latitude,
          longitude,
          updated_at,
          created_at,
          status,
          source
        `)
        .not('status', 'eq', 'rejected')  // Include all except rejected
        .not('latitude', 'is', null)      // Only courses with coordinates
        .not('longitude', 'is', null)
        .order('name', { ascending: true })
        .range(offset, offset + batchSize - 1);
      
      if (contributionsError) throw contributionsError;
      
      if (batch && batch.length > 0) {
        contributionsData = contributionsData.concat(batch);
        offset += batchSize;
        hasMore = batch.length === batchSize;
        console.log(`  📥 Fetched batch: ${batch.length} courses (total: ${contributionsData.length})`);
      } else {
        hasMore = false;
      }
    }

    // Combine both sources, prioritizing courses table entries
    const coursesMap = new Map();
    
    // Add courses from courses table
    if (coursesData) {
      for (const course of coursesData) {
        coursesMap.set(course.id, {
          ...course,
          avg_rating: course.avg_rating || null,
          review_count: course.review_count || 0,
        });
      }
    }

    // Add approved/merged contributions (these include OSM imports)
    if (contributionsData) {
      for (const contrib of contributionsData) {
        // Use contribution ID as key (OSM courses have unique IDs)
        const courseId = contrib.id;
        if (!coursesMap.has(courseId)) {
          coursesMap.set(courseId, {
            id: courseId,
            name: contrib.name,
            city: contrib.city,
            state: contrib.state,
            country: contrib.country,
            address: contrib.address,
            phone: contrib.phone,
            website: contrib.website,
            course_rating: contrib.course_rating,
            slope_rating: contrib.slope_rating,
            par: contrib.par,
            holes: contrib.holes,
            latitude: contrib.latitude,
            longitude: contrib.longitude,
            avg_rating: null,
            review_count: 0,
            updated_at: contrib.updated_at,
            created_at: contrib.created_at,
          });
        }
      }
    }

    const courses = Array.from(coursesMap.values());

    if (!courses || courses.length === 0) {
      console.log('⚠️  No courses found');
      return;
    }

    console.log(`📊 Found ${coursesData?.length || 0} courses from courses table`);
    console.log(`📊 Found ${contributionsData?.length || 0} approved/merged contributions`);
    console.log(`📊 Total unique courses: ${courses.length}`);

    // Calculate export size
    const jsonString = JSON.stringify(courses);
    const sizeInBytes = Buffer.byteLength(jsonString, 'utf8');
    const sizeInMB = (sizeInBytes / (1024 * 1024)).toFixed(2);

    console.log(`✅ Exported ${courses.length} courses`);
    console.log(`📊 Size: ${sizeInMB} MB (${sizeInBytes.toLocaleString()} bytes)`);

    // Create metadata
    const metadata = {
      export_date: new Date().toISOString(),
      total_courses: courses.length,
      version: 1,
    };

    const exportData = {
      metadata,
      courses: courses as CourseExport[],
    };

    // Write to iOS app resources directory
    const outputDir = path.join(process.cwd(), 'apps/ios/GolfStats/Resources');
    const outputPath = path.join(outputDir, 'courses-bundle.json');

    // Ensure directory exists
    if (!fs.existsSync(outputDir)) {
      fs.mkdirSync(outputDir, { recursive: true });
    }

    // Write file
    fs.writeFileSync(outputPath, JSON.stringify(exportData, null, 2), 'utf8');

    console.log(`💾 Saved to: ${outputPath}`);
    console.log(`\n✅ Export complete!`);
    console.log(`\n📝 Next steps:`);
    console.log(`   1. Add courses-bundle.json to Xcode project`);
    console.log(`   2. Ensure it's included in the app bundle`);
    console.log(`   3. Run this script periodically to update the bundle`);

    // Also create a compressed version for reference
    const compressedPath = path.join(outputDir, 'courses-bundle.json.gz');
    const zlib = require('zlib');
    const compressed = zlib.gzipSync(jsonString);
    fs.writeFileSync(compressedPath, compressed);
    const compressedSizeMB = (compressed.length / (1024 * 1024)).toFixed(2);
    console.log(`\n📦 Compressed size: ${compressedSizeMB} MB (for reference)`);

  } catch (error) {
    console.error('❌ Error exporting courses:', error);
    process.exit(1);
  }
}

exportCourses();
