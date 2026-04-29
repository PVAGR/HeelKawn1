#!/usr/bin/env bash
# HeelKawn - Launch the game (Linux/macOS)

cd "$(dirname "$0")" || exit 1

if ! command -v godot &> /dev/null; then
  echo "[ERROR] Godot executable not found in PATH."
  ./check_godot_path.sh
  exit 1
fi

if [ ! -d ".godot" ]; then
  echo "[INFO] Initializing Godot project cache (.godot)..."
  godot --headless --path "." --quit
  if [ $? -ne 0 ]; then
    echo "[ERROR] Failed to initialize project cache."
    exit 1
  fi
fi

echo "[INFO] Launching HeelKawn..."
godot --path "." "scenes/main/Main.tscn"
EXIT_CODE=$?
echo "[INFO] Game closed with exit code $EXIT_CODE."
exit $EXIT_CODE
