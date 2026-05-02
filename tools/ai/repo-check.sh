#!/bin/bash
# Quick repo state check - run this before any work
echo "=== HEELKAWN REPO STATE ==="
echo "Last 5 commits:"
git log --oneline -5
echo ""
echo "Files in autoloads: $(ls autoloads/*.gd 2>/dev/null | wc -l)"
echo "ProgressionSystem: $(ls autoloads/ProgressionSystem.gd 2>/dev/null && echo 'EXISTS' || echo 'MISSING')"
echo "In project.godot: $(grep ProgressionSystem project.godot 2>/dev/null && echo 'YES' || echo 'NO')"
echo "Uncommitted: $(git status -s 2>/dev/null | wc -l)"
echo "=== DONE ==="
