/**
 * Script to analyze course data quality issues:
 * - Bad course names (numbers, quotes, too short)
 * - Missing location data (country, city)
 * - Courses that need geocoding
 */

import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
import * as path from 'path';

// Load environment variables
dotenv.config({ path: path.join(process.cwd(), 'apps/web/.env.local') });

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('❌ Missing Supabase credentials');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

interface Course {
  id: string;
  name: string;
  city: string | null;
  state: string | null;
  country: string | null;
  latitude: number | null;
  longitude: number | null;
  address: string | null;
}

function isBadName(name: string): { isBad: boolean; reason?: string } {
  const trimmed = name.trim();
  
  if (!trimmed || trimmed.length === 0) {
    return { isBad: true, reason: 'empty' };
  }
  
  // Just numbers
  if (/^\d+$/.test(trimmed)) {
    return { isBad: true, reason: 'number_only' };
  }
  
  // Too short (less than 3 chars, excluding common abbreviations)
  if (trimmed.length < 3 && !['GC', 'CC', 'GC'].includes(trimmed.toUpperCase())) {
    return { isBad: true, reason: 'too_short' };
  }
  
  // Mostly quotes or special characters
  const alphanumericCount = trimmed.split('').filter(c => /[a-zA-Z0-9]/.test(c)).length;
  if (alphanumericCount / trimmed.length < 0.5) {
    return { isBad: true, reason: 'mostly_special_chars' };
  }
  
  // Starts or ends with quotes
  if (trimmed.startsWith('"') || trimmed.startsWith("'") || trimmed.endsWith('"') || trimmed.endsWith("'")) {
    return { isBad: true, reason: 'has_quotes' };
  }
  
  return { isBad: false };
}

async function analyzeCourses() {
  console.log('📊 Analyzing course data quality...\n');
  
  // Fetch all courses from both tables
  const { data: coursesData, error: coursesError } = await supabase
    .from('courses')
    .select('id, name, city, state, country, latitude, longitude, address');
  
  if (coursesError) throw coursesError;
  
  const { data: contributionsData, error: contribError } = await supabase
    .from('course_contributions')
    .select('id, name, city, state, country, latitude, longitude, address')
    .in('status', ['approved', 'merged']);
  
  if (contribError) throw contribError;
  
  const allCourses: Course[] = [
    ...(coursesData || []),
    ...(contributionsData || []).filter(c => !coursesData?.some(cc => cc.id === c.id))
  ];
  
  console.log(`📋 Total courses: ${allCourses.length}\n`);
  
  // Analyze bad names
  const badNames: Array<{ course: Course; reason: string }> = [];
  for (const course of allCourses) {
    const result = isBadName(course.name);
    if (result.isBad) {
      badNames.push({ course, reason: result.reason! });
    }
  }
  
  console.log(`❌ Bad course names: ${badNames.length}`);
  const badNameReasons = badNames.reduce((acc, item) => {
    acc[item.reason] = (acc[item.reason] || 0) + 1;
    return acc;
  }, {} as Record<string, number>);
  
  for (const [reason, count] of Object.entries(badNameReasons)) {
    console.log(`   ${reason}: ${count}`);
  }
  
  console.log(`\n📋 Sample bad names:`);
  for (const { course, reason } of badNames.slice(0, 20)) {
    console.log(`   [${reason}] "${course.name}"`);
  }
  
  // Analyze location data
  const locationIssues = {
    noCountry: 0,
    unknownCountry: 0,
    noCity: 0,
    noCoordinates: 0,
    partialLocation: 0,
  };
  
  for (const course of allCourses) {
    if (!course.country || course.country === 'Unknown') {
      locationIssues.unknownCountry++;
    }
    if (!course.city) {
      locationIssues.noCity++;
    }
    if (!course.latitude || !course.longitude) {
      locationIssues.noCoordinates++;
    }
    if (course.city && (!course.country || course.country === 'Unknown')) {
      locationIssues.partialLocation++;
    }
  }
  
  console.log(`\n🌍 Location data issues:`);
  console.log(`   Unknown/missing country: ${locationIssues.unknownCountry}`);
  console.log(`   Missing city: ${locationIssues.noCity}`);
  console.log(`   Missing coordinates: ${locationIssues.noCoordinates}`);
  console.log(`   Partial location (city but no country): ${locationIssues.partialLocation}`);
  
  // Courses that need geocoding
  const needsGeocoding = allCourses.filter(c => 
    (!c.latitude || !c.longitude) && 
    (c.city || c.address || c.country)
  );
  
  console.log(`\n📍 Courses needing geocoding: ${needsGeocoding.length}`);
  console.log(`   (Have location text but no coordinates)`);
  
  // Summary
  console.log(`\n📊 Summary:`);
  console.log(`   Total courses: ${allCourses.length}`);
  console.log(`   Bad names: ${badNames.length} (${(badNames.length / allCourses.length * 100).toFixed(1)}%)`);
  console.log(`   Unknown country: ${locationIssues.unknownCountry} (${(locationIssues.unknownCountry / allCourses.length * 100).toFixed(1)}%)`);
  console.log(`   Missing coordinates: ${locationIssues.noCoordinates} (${(locationIssues.noCoordinates / allCourses.length * 100).toFixed(1)}%)`);
  console.log(`   Needs geocoding: ${needsGeocoding.length} (${(needsGeocoding.length / allCourses.length * 100).toFixed(1)}%)`);
  
  console.log(`\n💡 Recommendations:`);
  console.log(`   1. Filter out courses with bad names in the app`);
  console.log(`   2. Use reverse geocoding for courses with coordinates but no country`);
  console.log(`   3. Use forward geocoding for courses with location text but no coordinates`);
  console.log(`   4. Consider marking courses with bad data as 'incomplete' status`);
}

analyzeCourses().catch(console.error);
