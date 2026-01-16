#!/bin/bash
# Quick API test script
# Usage: ./test_api.sh

echo "Testing Gemini API integration..."
echo ""

# Try to find Godot
if command -v godot &> /dev/null; then
    GODOT_CMD="godot"
elif [ -f "/Applications/Godot.app/Contents/MacOS/Godot" ]; then
    GODOT_CMD="/Applications/Godot.app/Contents/MacOS/Godot"
elif [ -f "/usr/local/bin/godot" ]; then
    GODOT_CMD="/usr/local/bin/godot"
else
    echo "ERROR: Godot not found!"
    echo "Please install Godot or add it to your PATH"
    echo "Alternatively, open the project in Godot and press F5"
    exit 1
fi

echo "Using Godot: $GODOT_CMD"
echo ""
echo "Running API test..."
echo ""

cd "$(dirname "$0")"
$GODOT_CMD --headless --script scripts/test_api_standalone.gd
