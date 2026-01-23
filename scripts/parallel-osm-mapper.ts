/**
 * Parallel OSM Mapper (TURBO VERSION)
 * 
 * Features:
 * - 3 Parallel Workers
 * - Server Rotation (4 global instances)
 * - Intelligent Rate Limiting & Error Handling
 * - ETA Tracking
 */

import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
import * as path from 'path';
import { fetchCourseHoleData, formatForDatabase } from './fetch-osm-hole-data';

// Load environment variables
const envPath = path.join(process.cwd(), '.env.local');
dotenv.config({ path: envPath });

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('❌ Missing Supabase credentials');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

// Global Overpass instances to rotate through
const SERVERS = [
  "https://overpass-api.de/api/interpreter",
  "https://lz4.overpass-api.de/api/interpreter",
  "https://z.overpass-api.de/api/interpreter",
  "https://overpass.kumi.systems/api/interpreter",
  "https://overpass.openstreetmap.ru/api/interpreter",
  "https://overpass.osm.ch/api/interpreter",
  "https://overpass.hotosm.org/api/interpreter"
];

let successCount = 0;
let emptyCount = 0;
let errorCount = 0;
let totalStarted = 0;

/**
 * Process a single course with retry logic using alternative servers
 */
async function processCourse(course: any, workerId: number, isMainTable: boolean) {
  const name = course.name || 'Unnamed Course';
  let retryCount = 0;
  let serverIndex = (workerId - 1 + totalStarted) % SERVERS.length;

  while (retryCount < SERVERS.length) {
    const server = SERVERS[serverIndex];
    try {
      const rawHoleData = await fetchCourseHoleData(
        name,
        course.latitude,
        course.longitude,
        server
      );

      const holeData = rawHoleData.length > 0 
        ? formatForDatabase(rawHoleData) 
        : [{ hole_number: 0, par: 0 }]; // Placeholder to mark as "checked"
      
      const { error: updateError } = await supabase
        .from(isMainTable ? 'courses' : 'course_contributions')
        .update({
          hole_data: holeData,
          updated_at: new Date().toISOString()
        })
        .eq('id', course.id);

      if (updateError) {
        throw new Error(`DB Update failed: ${updateError.message}`);
      }

      if (rawHoleData.length > 0) {
        successCount++;
        console.log(`[Worker ${workerId}] ✨ SUCCESS: Found ${rawHoleData.length} holes for ${name}`);
      } else {
        emptyCount++;
        console.log(`[Worker ${workerId}] ∅ EMPTY: No mapping found for ${name}`);
      }
      return true;

    } catch (e: any) {
      console.error(`[Worker ${workerId}] ⚠️ Server ${new URL(server).hostname} failed for ${name}: ${e.message}`);
      
      if (e.message.includes('429') || e.message.includes('504') || e.message.includes('Timeout') || e.message.includes('Non-JSON')) {
        retryCount++;
        serverIndex = (serverIndex + 1) % SERVERS.length;
        console.log(`[Worker ${workerId}] 🔄 Retrying with server: ${new URL(SERVERS[serverIndex]).hostname} (Retry ${retryCount}/${SERVERS.length})...`);
        await new Promise(r => setTimeout(r, 5000 * retryCount)); // Heavy backoff
      } else {
        errorCount++;
        return false;
      }
    }
  }

  console.error(`[Worker ${workerId}] ❌ Failed ${name} after ${retryCount} retries.`);
  console.log(`[Worker ${workerId}] 🛡️  Cooldown for 10 seconds...`);
  await new Promise(r => setTimeout(r, 10000));
  errorCount++;
  return false;
}

async function startTurboMapping() {
  console.log('='.repeat(60));
  console.log('🚀 STARTING TURBO MAPPER (Sequential Recovery Mode)');
  console.log(`🌍 Rotating through ${SERVERS.length} global Overpass servers`);
  console.log('🛡️  Safety: 10s cooldown if all servers fail');
  console.log('='.repeat(60) + '\n');

  const CONCURRENCY = 1; // Drop to sequential to avoid IP blocks
  let batchSize = 10;
  let startTime = Date.now();

  while (true) {
    // 1. Fetch batch from course_contributions first
    let { data: batch, error } = await supabase
      .from('course_contributions')
      .select('id, name, latitude, longitude')
      .not('latitude', 'is', null)
      .not('longitude', 'is', null)
      .or('hole_data.is.null,hole_data.eq.[]')
      .order('id', { ascending: true })
      .limit(batchSize);

    if (error) {
      console.error('❌ Error fetching contributions:', error.message);
      break;
    }

    let isMainTable = false;

    // 2. If no contributions, check main courses table
    if (!batch || batch.length === 0) {
      const { data: mainBatch, error: mainError } = await supabase
        .from('courses')
        .select('id, name, latitude, longitude')
        .not('latitude', 'is', null)
        .not('longitude', 'is', null)
        .or('hole_data.is.null,hole_data.eq.[]')
        .order('id', { ascending: true })
        .limit(batchSize);

      if (mainError) {
        console.error('❌ Error fetching main courses:', mainError.message);
        break;
      }
      batch = mainBatch;
      isMainTable = true;
    }

    if (!batch || batch.length === 0) {
      console.log('✅ No more courses needing mapping data found.');
      break;
    }

    console.log(`\n📦 Processing batch of ${batch.length} courses...`);

    // Process in parallel chunks of CONCURRENCY
    for (let i = 0; i < batch.length; i += CONCURRENCY) {
      const chunk = batch.slice(i, i + CONCURRENCY);
      totalStarted += chunk.length;
      
      await Promise.all(chunk.map((course, idx) => processCourse(course, idx + 1, isMainTable)));
      
      const elapsed = (Date.now() - startTime) / 1000;
      const rate = totalStarted / (elapsed / 60);
      console.log(`\n📊 PROGRESS: ${successCount} mapped | ${emptyCount} empty | ${errorCount} errors`);
      console.log(`⏱️  Speed: ${rate.toFixed(1)} courses/min | Elapsed: ${Math.floor(elapsed / 60)}m`);
      
      // Polite delay between parallel chunks
      await new Promise(r => setTimeout(r, 10000));
    }
  }

  console.log('\n' + '='.repeat(60));
  console.log('🏁 TURBO MAPPING COMPLETE');
  console.log(`✅ Detailed maps: ${successCount}`);
  console.log(`∅ Empty maps: ${emptyCount}`);
  console.log(`❌ Errors: ${errorCount}`);
  console.log('='.repeat(60));
}

startTurboMapping().catch(console.error);
