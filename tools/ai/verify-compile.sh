#!/bin/bash
# Quick Godot compile check
echo "=== Godot Compile Check ==="
godot --headless --script-check 2>&1 | head -30
echo "=== DONE ==="
