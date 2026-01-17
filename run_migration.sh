#!/bin/bash
# Migration Runner Script
# This script will apply the enhanced course features migration

echo "🚀 Running Supabase Migration..."
echo ""
echo "This will apply: 20260118000000_enhanced_course_features.sql"
echo ""

# Check if Supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI not found. Please install it first:"
    echo "   https://supabase.com/docs/guides/cli/getting-started"
    exit 1
fi

# Check if linked to project
echo "📋 Checking project status..."
supabase projects list | grep -q "golfstats.*●" || {
    echo "⚠️  Project not linked. Linking now..."
    supabase link --project-ref kanvhqwrfkzqktuvpxnp
}

echo ""
echo "📦 Pushing migrations to remote database..."
echo "   (This may take 30-60 seconds)"
echo ""

# Push with include-all to handle any missing migrations
if supabase db push --include-all; then
    echo ""
    echo "✅ Migration completed successfully!"
    echo ""
    echo "Next steps:"
    echo "1. Create storage bucket 'course-photos' in Supabase Dashboard"
    echo "2. Test the new features in your app"
    echo ""
else
    echo ""
    echo "❌ Migration failed. Check the error above."
    echo ""
    echo "You can also run it manually via Supabase Dashboard SQL Editor:"
    echo "   See docs/MIGRATION_INSTRUCTIONS.md for manual instructions"
    exit 1
fi
