#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

echo "=== HEELKAWN SIM QUALITY GATE ==="

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

warn() {
  echo "[WARN] $1"
}

require_file() {
  local f="$1"
  [[ -f "$f" ]] || fail "Missing required file: $f"
}

require_file "project.godot"
require_file "docs/AI_RUNTIME_MANDATE.md"
require_file "docs/HEELKAWN_STATE.md"

echo "[1/4] Determinism guard scan (critical systems)..."
if rg -nP '(?<!\.)\b(?:randf|randi|rand_range|randf_range|randi_range)\(' \
  autoloads/DisasterSystem.gd \
  scripts/world/CataclysmSystem.gd \
  autoloads/KnowledgeSystem.gd >/tmp/hk_rng_guard.txt 2>/dev/null; then
  cat /tmp/hk_rng_guard.txt
  fail "Global RNG detected in critical deterministic systems."
fi

echo "[2/4] World pathing sanity scan..."
if rg -n 'map_width|map_height' autoloads/DisasterSystem.gd autoloads/WildlifePopulation.gd autoloads/FarmingSystem.gd >/tmp/hk_world_guard.txt 2>/dev/null; then
  cat /tmp/hk_world_guard.txt
  fail "Legacy world dimension fields detected in active systems."
fi

echo "[3/4] Project scene sanity..."
if ! rg -n '^run/main_scene=' project.godot >/tmp/hk_scene_guard.txt 2>/dev/null; then
  fail "Main scene is not configured in project.godot."
fi
cat /tmp/hk_scene_guard.txt

echo "[4/4] Runtime smoke (optional if Godot installed)..."
GODOT_BIN=""
if command -v godot >/dev/null 2>&1; then
  GODOT_BIN="godot"
elif command -v godot4 >/dev/null 2>&1; then
  GODOT_BIN="godot4"
fi

if [[ -z "$GODOT_BIN" ]]; then
  warn "Godot binary not found. Skipping headless smoke in this environment."
else
  "$GODOT_BIN" --headless --path . --script tools/sim_boot_smoke.gd >/tmp/hk_smoke_boot.txt 2>&1 || {
    cat /tmp/hk_smoke_boot.txt
    fail "Boot smoke failed."
  }
  "$GODOT_BIN" --headless --path . --script tools/sim_settlement_public_state_smoke.gd >/tmp/hk_smoke_settlement.txt 2>&1 || {
    cat /tmp/hk_smoke_settlement.txt
    fail "Settlement smoke failed."
  }
  "$GODOT_BIN" --headless --path . --script tools/sim_worldmeaning_region_tags_smoke.gd >/tmp/hk_smoke_meaning.txt 2>&1 || {
    cat /tmp/hk_smoke_meaning.txt
    fail "WorldMeaning smoke failed."
  }
  "$GODOT_BIN" --headless --path . --script tools/sim_performance_smoothness_smoke.gd >/tmp/hk_smoke_perf.txt 2>&1 || {
    cat /tmp/hk_smoke_perf.txt
    fail "Performance smoothness smoke failed."
  }
  if rg -n '\[PERF_SMOOTHNESS_FAIL\]' /tmp/hk_smoke_perf.txt >/tmp/hk_smoke_perf_fail.txt 2>/dev/null; then
    cat /tmp/hk_smoke_perf_fail.txt
    fail "Performance smoothness smoke reported explicit failure."
  fi
  if ! rg -q '\[PERF_SMOOTHNESS_PASS\]' /tmp/hk_smoke_perf.txt; then
    cat /tmp/hk_smoke_perf.txt
    fail "Performance smoothness smoke did not report pass marker."
  fi
  if ! rg -q 'consistency=ok' /tmp/hk_smoke_perf.txt; then
    cat /tmp/hk_smoke_perf.txt
    fail "Performance smoothness smoke reported world/tick consistency mismatch."
  fi
  echo "[OK] Headless smoke scripts passed."
fi

echo "[OK] Sim quality gate passed."
