#!/bin/bash
# Helper script to load .env.local and run the OSM import

# Load .env.local if it exists
if [ -f .env.local ]; then
  export $(cat .env.local | grep -v '^#' | xargs)
fi

# Run the import script
npx tsx scripts/import-osm-courses.ts
