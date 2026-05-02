#!/bin/bash
# Show recent commits with changes
# Usage: bash tools/ai/commit-log.sh [count]
COUNT=${1:-10}
echo "=== Last $COUNT commits ==="
git log --oneline -$COUNT
for sha in $(git log --oneline -$COUNT | cut -d' ' -f1); do
    echo "--- $sha ---"
    git show --stat --oneline $sha | head -5
done
