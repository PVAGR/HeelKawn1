#!/usr/bin/env bash
# HeelKawn - Launch with log capture (Linux/macOS)

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

if [ ! -d "logs" ]; then
  mkdir "logs"
fi

STAMP=$(date +"%Y-%m-%d_%H-%M-%S")
LOG_FILE="logs/playtest_${STAMP}.log"
LATEST_FILE="logs/playtest_latest.log"

echo "[INFO] Launching HeelKawn with capture..."
echo "[INFO] Log file: $LOG_FILE"
echo "[INFO] (Close game window to finish capture)"

godot --path "." "scenes/main/Main.tscn" > "$LOG_FILE" 2>&1
EXIT_CODE=$?

cp "$LOG_FILE" "$LATEST_FILE"

echo "[INFO] Game closed with exit code $EXIT_CODE."
echo "[INFO] Latest log: $LATEST_FILE"
echo "[INFO] Timestamped log: $LOG_FILE"
exit $EXIT_CODE
