#!/bin/bash
# Monitor geocoding progress

LOG_FILE="geocoding-progress.log"

if [ ! -f "$LOG_FILE" ]; then
  echo "❌ Log file not found: $LOG_FILE"
  echo "   The geocoding script may not be running."
  exit 1
fi

echo "📊 Geocoding Progress Monitor"
echo "=============================="
echo ""

# Count processed courses
PROCESSED=$(grep -c "Processing:" "$LOG_FILE" 2>/dev/null || echo "0")
UPDATED=$(grep -c "✅ Updated:" "$LOG_FILE" 2>/dev/null || echo "0")
ERRORS=$(grep -c "❌" "$LOG_FILE" 2>/dev/null || echo "0")
SKIPPED=$(grep -c "⏭️  Skipping" "$LOG_FILE" 2>/dev/null || echo "0")

echo "📈 Statistics:"
echo "   Processed: $PROCESSED"
echo "   Updated: $UPDATED"
echo "   Errors: $ERRORS"
echo "   Skipped: $SKIPPED"
echo ""

# Get last 5 lines
echo "📋 Last 5 log entries:"
tail -5 "$LOG_FILE"
echo ""

# Check if process is still running
if pgrep -f "geocode-courses" > /dev/null; then
  echo "✅ Geocoding script is running"
else
  echo "⚠️  Geocoding script is NOT running"
  echo ""
  echo "📊 Final summary (if completed):"
  tail -20 "$LOG_FILE" | grep -A 10 "GEOCODING SUMMARY" || echo "   (No summary found yet)"
fi
