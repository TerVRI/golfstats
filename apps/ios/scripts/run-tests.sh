#!/bin/bash

# Script to run iOS tests
# Usage: ./scripts/run-tests.sh [simulator-name]

set -e

SIMULATOR_NAME="${1:-iPhone 15 Pro}"
PROJECT_NAME="RoundCaddy.xcodeproj"
SCHEME="GolfStats"

echo "🧪 Running iOS Tests..."
echo "📱 Simulator: $SIMULATOR_NAME"
echo ""

# Check if xcodegen needs to be run
if [ ! -f "$PROJECT_NAME/project.pbxproj" ] || [ "project.yml" -nt "$PROJECT_NAME/project.pbxproj" ]; then
    echo "📦 Regenerating Xcode project..."
    xcodegen generate
fi

# Run tests
echo "🚀 Starting test run..."
xcodebuild test \
    -project "$PROJECT_NAME" \
    -scheme "$SCHEME" \
    -destination "platform=iOS Simulator,name=$SIMULATOR_NAME" \
    -only-testing:GolfStatsTests \
    | xcpretty

TEST_EXIT_CODE=${PIPESTATUS[0]}

if [ $TEST_EXIT_CODE -eq 0 ]; then
    echo ""
    echo "✅ All tests passed!"
else
    echo ""
    echo "❌ Some tests failed. Exit code: $TEST_EXIT_CODE"
    exit $TEST_EXIT_CODE
fi
