#!/bin/bash
# Find any file by name pattern
# Usage: bash tools/ai/find-file.sh Progression
PATTERN=${1:-.}
echo "=== FILES matching '$PATTERN' ==="
find . -name "*$PATTERN*" -type f 2>/dev/null | head -20
