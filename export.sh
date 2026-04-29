#!/usr/bin/env bash
# HeelKawn - Export the game (Linux/macOS)

cd "$(dirname "$0")" || exit 1

if ! command -v godot &> /dev/null; then
  echo "[ERROR] Godot executable not found in PATH."
  ./check_godot_path.sh
  exit 1
fi

if [ ! -d "export" ]; then
  mkdir "export"
fi

# Detect platform for appropriate export preset
if [[ "$OSTYPE" == "darwin"* ]]; then
  PLATFORM="macOS"
  OUTPUT_FILE="export/HeelKawn.app"
else
  PLATFORM="Linux/X11"
  OUTPUT_FILE="export/HeelKawn.x86_64"
fi

echo "[INFO] Exporting HeelKawn executable for $PLATFORM..."
godot --headless --path "." --export-debug "$PLATFORM" "$OUTPUT_FILE"
if [ $? -ne 0 ]; then
  echo "[ERROR] Export failed."
  echo "[INFO] You may need to configure export presets in the Godot editor first."
  exit 1
fi

echo "[SUCCESS] Export complete: $(pwd)/$OUTPUT_FILE"
exit 0
