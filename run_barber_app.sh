#!/bin/bash

# Barber App Launcher Script
# This script kills any existing Flutter processes, clears locks, and runs the barber app

echo "🔧 Cleaning up Flutter processes and locks..."

# Kill any existing Flutter/Dart processes
killall -9 dart 2>/dev/null || true
killall -9 flutter 2>/dev/null || true

# Remove lock files
rm -f /opt/homebrew/share/flutter/bin/cache/lockfile 2>/dev/null || true
rm -rf ~/.dart_tool/flutter_lock 2>/dev/null || true

echo "✅ Cleanup complete!"
echo ""
echo "🚀 Starting Barber App..."
echo ""

# Navigate to barber app directory
cd "$(dirname "$0")"

# Run the app
flutter run -d emulator-5554
