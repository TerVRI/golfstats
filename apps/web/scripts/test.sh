#!/bin/bash

# Script to run web tests
# Usage: ./scripts/test.sh [watch|run|coverage]

set -e

MODE="${1:-run}"

echo "🧪 Running Web Tests..."
echo ""

case "$MODE" in
    watch)
        echo "👀 Running in watch mode..."
        npm test
        ;;
    run)
        echo "🚀 Running tests once..."
        npm run test:run
        ;;
    coverage)
        echo "📊 Running with coverage..."
        npm run test:run -- --coverage
        ;;
    *)
        echo "Usage: ./scripts/test.sh [watch|run|coverage]"
        exit 1
        ;;
esac
