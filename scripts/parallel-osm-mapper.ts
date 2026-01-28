/**
 * Parallel OSM Mapper - FIXED VERSION
 * Each worker gets a dedicated server to avoid rate limits
 */

import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
import * as path from 'path';
import { fetchCourseHoleData, formatForDatabase } from './fetch-osm-hole-data';

const envPath = path.join(process.cwd(), '.env.local');
dotenv.config({ path: envPath });

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_KEY;

if (!supabaseUrl || !supabaseKey) {
  console.error('❌ Missing Supabase credentials');
  process.exit(1);
}

const supabase = createClient(supabaseUrl, supabaseKey);

// All public Overpass API servers
const SERVERS = [
  "https://overpass-api.de/api/interpreter",
  "https://lz4.overpass-api.de/api/interpreter",
  "https://z.overpass-api.de/api/interpreter",
  "https://overpass.kumi.systems/api/interpreter",
  "https://overpass.osm.ch/api/interpreter",
  "https://overpass.openstreetmap.fr/api/interpreter",
  "https://overpass.nchc.org.tw/api/interpreter",
  "https://maps.mail.ru/osm/tools/overpass/api/interpreter",
];

let successCount = 0;
let emptyCount = 0;
let errorCount = 0;
const startTime = Date.now();

// Shared queue with mutex
let courseQueue: Array<{ id: string; name: string; latitude: number; longitude: number; isMainTable: boolean }> = [];
let queueLock = false;

async function refillQueueSafe() {
  if (queueLock || courseQueue.length > 30) return;
  queueLock = true;
  
  try {
    const { data: batch } = await supabase
      .from('course_contributions')
      .select('id, name, latitude, longitude')
      .not('latitude', 'is', null)
      .not('longitude', 'is', null)
      .is('hole_data', null)
      .limit(50);
    
    if (batch && batch.length > 0) {
      const ids = batch.map(b => b.id);
      await supabase.from('course_contributions')
        .update({ hole_data: [{ hole_number: -2 }] })
        .in('id', ids);
      batch.forEach(b => courseQueue.push({ ...b, isMainTable: false }));
    }
    
    const { data: mainBatch } = await supabase
      .from('courses')
      .select('id, name, latitude, longitude')
      .not('latitude', 'is', null)
      .not('longitude', 'is', null)
      .is('hole_data', null)
      .limit(20);
    
    if (mainBatch && mainBatch.length > 0) {
      const ids = mainBatch.map(b => b.id);
      await supabase.from('courses')
        .update({ hole_data: [{ hole_number: -2 }] })
        .in('id', ids);
      mainBatch.forEach(b => courseQueue.push({ ...b, isMainTable: true }));
    }
  } catch (e) {
    // Ignore refill errors
  } finally {
    queueLock = false;
  }
}

async function getNextCourseSafe() {
  if (courseQueue.length < 10) {
    await refillQueueSafe();
  }
  return courseQueue.shift() || null;
}

async function releaseCourse(course: { id: string; isMainTable: boolean }) {
  try {
    await supabase
      .from(course.isMainTable ? 'courses' : 'course_contributions')
      .update({ hole_data: null })
      .eq('id', course.id);
  } catch (e) {
    // Ignore
  }
}

function printProgress() {
  const elapsed = (Date.now() - startTime) / 1000;
  const total = successCount + emptyCount;
  const rate = total / (elapsed / 60);
  process.stdout.write(`\r📊 ${successCount} mapped | ${emptyCount} empty | ${errorCount} err | ${rate.toFixed(0)}/min | Q:${courseQueue.length}    `);
}

async function worker(workerId: number, server: string) {
  const serverName = new URL(server).hostname;
  console.log(`[W${workerId}] 🚀 Using ${serverName}`);
  
  let idleCount = 0;
  let cooldownUntil = 0;
  
  while (true) {
    // Check cooldown
    if (Date.now() < cooldownUntil) {
      const wait = Math.ceil((cooldownUntil - Date.now()) / 1000);
      if (wait > 60) {
        console.log(`[W${workerId}] 💤 Cooldown ${wait}s, shutting down`);
        break;
      }
      await new Promise(r => setTimeout(r, 5000));
      continue;
    }
    
    const course = await getNextCourseSafe();
    
    if (!course) {
      idleCount++;
      if (idleCount > 5) {
        console.log(`[W${workerId}] ✅ Done`);
        break;
      }
      await new Promise(r => setTimeout(r, 3000));
      continue;
    }
    
    idleCount = 0;
    
    try {
      const rawHoleData = await fetchCourseHoleData(
        course.name || 'Unknown',
        course.latitude,
        course.longitude,
        server
      );
      
      const holeData = rawHoleData.length > 0 
        ? formatForDatabase(rawHoleData) 
        : [{ hole_number: 0, par: 0 }];
      
      await supabase
        .from(course.isMainTable ? 'courses' : 'course_contributions')
        .update({ hole_data: holeData, updated_at: new Date().toISOString() })
        .eq('id', course.id);
      
      if (rawHoleData.length > 0) {
        successCount++;
        console.log(`[W${workerId}] ✨ ${course.name}: ${rawHoleData.length} holes`);
      } else {
        emptyCount++;
      }
      
      printProgress();
      
    } catch (e: any) {
      const msg = e.message || '';
      
      if (msg.includes('429')) {
        console.log(`[W${workerId}] ⏳ Rate limited, cooling 2min`);
        cooldownUntil = Date.now() + 120000;
      } else if (msg.includes('403')) {
        console.log(`[W${workerId}] 🚫 Forbidden, cooling 5min`);
        cooldownUntil = Date.now() + 300000;
      } else if (msg.includes('504') || msg.includes('Timeout')) {
        console.log(`[W${workerId}] ⏰ Timeout, cooling 1min`);
        cooldownUntil = Date.now() + 60000;
      }
      
      await releaseCourse(course);
      errorCount++;
    }
    
    // Delay between requests - 3 seconds per worker
    await new Promise(r => setTimeout(r, 3000));
  }
}

async function main() {
  console.log('='.repeat(60));
  console.log('🚀 PARALLEL OSM MAPPER - DEDICATED SERVER MODE');
  console.log(`🌍 ${SERVERS.length} servers available`);
  console.log('='.repeat(60));
  
  // Initial fill
  await refillQueueSafe();
  console.log(`📦 Queue: ${courseQueue.length} courses\n`);
  
  if (courseQueue.length === 0) {
    console.log('❌ No courses to process!');
    return;
  }
  
  // One worker per server
  const workers = SERVERS.map((server, i) => worker(i + 1, server));
  await Promise.all(workers);
  
  console.log('\n' + '='.repeat(60));
  console.log('🏁 COMPLETE');
  console.log(`📊 ${successCount} mapped | ${emptyCount} empty | ${errorCount} errors`);
  console.log('='.repeat(60));
}

main().catch(console.error);
