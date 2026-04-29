#!/usr/bin/env bash
# HeelKawn - Check Godot PATH (Linux/macOS)

if command -v godot &> /dev/null; then
  echo "[OK] Godot found in PATH."
  echo "  - $(command -v godot)"
  exit 0
fi

echo "[ERROR] Godot was not found in your system PATH."
echo ""
echo "Add Godot 4 to PATH (Linux/macOS):"
echo "1. Locate your Godot executable, e.g.:"
echo "   /usr/local/bin/godot"
echo "   /opt/godot/godot"
echo "   ~/Applications/Godot.app/Contents/MacOS/Godot (macOS)"
echo "2. Add to your shell profile (~/.bashrc, ~/.zshrc, etc.):"
echo "   export PATH=\"\$PATH:/path/to/godot/folder\""
echo "3. Or create a symlink:"
echo "   sudo ln -s /path/to/Godot /usr/local/bin/godot"
echo "4. Reload your shell:"
echo "   source ~/.bashrc  # or source ~/.zshrc"
echo "5. Re-run:"
echo "   ./play.sh"
echo ""
exit 1
