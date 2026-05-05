#!/usr/bin/env python3
"""HeelKawn AI Observer — polls ai_state.json and sends diffs to Ollama for analysis.

Usage:
    python tools/ai_observer.py                          # default path
    python tools/ai_observer.py --path /path/to/exports  # custom path
    python tools/ai_observer.py --interval 5             # poll every 5s
    python tools/ai_observer.py --no-ollama              # heuristic mode only

The Godot side writes user://exports/ai_state.json on a tick cadence
(via ObservationAPI.export_ai_state). This script watches that file,
detects meaningful changes, and either:
  1. Sends the diff to a local Ollama model for narrative analysis
  2. Falls back to heuristic alerts if Ollama is unreachable

Output goes to stdout and to ai_reports/observer_log.txt.
"""

import argparse
import json
import os
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

try:
    import requests
    HAS_REQUESTS = True
except ImportError:
    HAS_REQUESTS = False

# ── Defaults ──────────────────────────────────────────────────────────

DEFAULT_GODOT_USERDATA = os.path.join(
    os.environ.get("APPDATA", ""),
    "Godot", "app_userdata", "HeelKawn"
)
DEFAULT_STATE_FILE = "exports/ai_state.json"
DEFAULT_REPORT_DIR = "ai_reports"
DEFAULT_REPORT_FILE = "observer_log.txt"
DEFAULT_OLLAMA_URL = "http://localhost:11434"
DEFAULT_OLLAMA_MODEL = "qwen2.5:7b"
DEFAULT_POLL_INTERVAL = 2  # seconds

# ── Heuristic alerts ─────────────────────────────────────────────────

def check_alerts(state: dict) -> list[str]:
    """Return a list of alert strings for critical conditions."""
    alerts = []
    colony = state.get("colony", {})
    food = colony.get("food_pressure", 0.0)
    housing = colony.get("housing_pressure", 0.0)
    materials = colony.get("materials_pressure", 0.0)

    if food >= 0.9:
        alerts.append(f"CRITICAL: food pressure {food:.0%} — famine imminent")
    elif food >= 0.7:
        alerts.append(f"WARNING: food pressure {food:.0%} — foraging priority")

    if housing >= 0.9:
        alerts.append(f"CRITICAL: housing pressure {housing:.0%} — no beds")
    elif housing >= 0.7:
        alerts.append(f"WARNING: housing pressure {housing:.0%} — shelter needed")

    if materials >= 0.8:
        alerts.append(f"WARNING: materials pressure {materials:.0%} — building stalled")

    settlements = state.get("settlements", [])
    for s in settlements:
        if s.get("state") == "abandoned":
            alerts.append(f"NOTICE: settlement at region {s.get('center_region', '?')} abandoned")
        elif s.get("state") == "permanently_abandoned":
            alerts.append(f"NOTICE: settlement at region {s.get('center_region', '?')} permanently lost")

    return alerts


# ── Diff detection ───────────────────────────────────────────────────

def compute_diff(prev: dict, curr: dict) -> dict | None:
    """Return a dict of changed fields, or None if nothing meaningful changed."""
    if prev is None:
        return {"type": "initial", "snapshot": curr}

    diff = {"type": "delta", "tick": curr.get("tick", 0)}

    # Tick and speed changes
    if prev.get("tick") != curr.get("tick"):
        diff["tick_delta"] = curr.get("tick", 0) - prev.get("tick", 0)
    if prev.get("speed") != curr.get("speed"):
        diff["speed_change"] = {"from": prev.get("speed"), "to": curr.get("speed")}
    if prev.get("paused") != curr.get("paused"):
        diff["paused_change"] = curr.get("paused")

    # Colony pressure changes (only report if >5% shift)
    for key in ("food_pressure", "housing_pressure", "materials_pressure", "haul_pressure"):
        p_val = prev.get("colony", {}).get(key, 0.0)
        c_val = curr.get("colony", {}).get(key, 0.0)
        if abs(c_val - p_val) > 0.05:
            diff.setdefault("colony_changes", {})[key] = {
                "from": round(p_val, 3),
                "to": round(c_val, 3),
            }

    # Settlement state changes
    prev_settlements = {s.get("center_region"): s for s in prev.get("settlements", [])}
    curr_settlements = {s.get("center_region"): s for s in curr.get("settlements", [])}
    for rk, s in curr_settlements.items():
        ps = prev_settlements.get(rk)
        if ps is None:
            diff.setdefault("settlement_changes", {})[rk] = {"event": "new_settlement"}
        elif ps.get("state") != s.get("state"):
            diff.setdefault("settlement_changes", {})[rk] = {
                "event": "state_change",
                "from": ps.get("state"),
                "to": s.get("state"),
            }
        elif ps.get("intent") != s.get("intent"):
            diff.setdefault("settlement_changes", {})[rk] = {
                "event": "intent_change",
                "from": ps.get("intent"),
                "to": s.get("intent"),
            }

    # Job count changes
    prev_jobs = prev.get("jobs", {}).get("open_count", 0)
    curr_jobs = curr.get("jobs", {}).get("open_count", 0)
    if abs(curr_jobs - prev_jobs) >= 3:
        diff["jobs_change"] = {"from": prev_jobs, "to": curr_jobs}

    # World event count
    prev_events = prev.get("world", {}).get("event_count", 0)
    curr_events = curr.get("world", {}).get("event_count", 0)
    if curr_events > prev_events:
        diff["new_events"] = curr_events - prev_events

    # If nothing meaningful changed, return None
    has_changes = any(
        k != "type" and k != "tick"
        for k in diff.keys()
    )
    return diff if has_changes else None


# ── Ollama integration ───────────────────────────────────────────────

def query_ollama(diff: dict, state: dict, url: str, model: str) -> str | None:
    """Send diff to Ollama and return the analysis, or None on failure."""
    if not HAS_REQUESTS:
        return None

    prompt = (
        "You are observing a deterministic colony simulation called HeelKawn. "
        "You receive a diff of what changed since the last observation. "
        "Give a brief (2-3 sentence) narrative analysis of what is happening. "
        "Be specific about pressures, settlement states, and trends. "
        "Do not invent events not in the data.\n\n"
        f"Current tick: {state.get('tick', 0)}\n"
        f"Speed: {state.get('speed', 1.0)}x\n"
        f"Colony stance: {state.get('colony', {}).get('stance', 'unknown')}\n"
        f"Pressures: food={state.get('colony', {}).get('food_pressure', 0):.0%} "
        f"housing={state.get('colony', {}).get('housing_pressure', 0):.0%} "
        f"materials={state.get('colony', {}).get('materials_pressure', 0):.0%}\n"
        f"Settlements: {len(state.get('settlements', []))}\n"
        f"Open jobs: {state.get('jobs', {}).get('open_count', 0)}\n\n"
        f"Diff since last observation:\n{json.dumps(diff, indent=2, default=str)}"
    )

    try:
        resp = requests.post(
            f"{url}/api/generate",
            json={"model": model, "prompt": prompt, "stream": False},
            timeout=30,
        )
        resp.raise_for_status()
        return resp.json().get("response", "").strip()
    except Exception as e:
        return None


# ── Main loop ─────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="HeelKawn AI Observer")
    parser.add_argument(
        "--path",
        default=os.path.join(DEFAULT_GODOT_USERDATA, DEFAULT_STATE_FILE),
        help="Path to ai_state.json",
    )
    parser.add_argument(
        "--interval",
        type=float,
        default=DEFAULT_POLL_INTERVAL,
        help="Poll interval in seconds",
    )
    parser.add_argument(
        "--ollama-url",
        default=DEFAULT_OLLAMA_URL,
        help="Ollama API URL",
    )
    parser.add_argument(
        "--ollama-model",
        default=DEFAULT_OLLAMA_MODEL,
        help="Ollama model name",
    )
    parser.add_argument(
        "--no-ollama",
        action="store_true",
        help="Disable Ollama, use heuristic alerts only",
    )
    parser.add_argument(
        "--report-dir",
        default=DEFAULT_REPORT_DIR,
        help="Directory for observer log files",
    )
    args = parser.parse_args()

    state_path = Path(args.path)
    report_dir = Path(args.report_dir)
    report_dir.mkdir(parents=True, exist_ok=True)
    report_path = report_dir / DEFAULT_REPORT_FILE

    prev_state: dict | None = None
    ollama_available = not args.no_ollama
    last_ollama_check = 0.0

    print(f"[ai_observer] Watching: {state_path}")
    print(f"[ai_observer] Reports: {report_path}")
    print(f"[ai_observer] Ollama: {'disabled' if args.no_ollama else f'{args.ollama_url} ({args.ollama_model})'}")
    print(f"[ai_observer] Poll interval: {args.interval}s")
    print()

    with open(report_path, "a", encoding="utf-8") as report_file:
        report_file.write(f"\n=== AI Observer started {datetime.now(timezone.utc).isoformat()} ===\n")

        while True:
            try:
                if not state_path.exists():
                    time.sleep(args.interval)
                    continue

                with open(state_path, "r", encoding="utf-8") as f:
                    curr_state = json.load(f)
            except (json.JSONDecodeError, OSError):
                time.sleep(args.interval)
                continue

            diff = compute_diff(prev_state, curr_state)

            if diff is not None:
                ts = datetime.now(timezone.utc).isoformat()
                tick = curr_state.get("tick", 0)

                # Always check heuristic alerts
                alerts = check_alerts(curr_state)

                # Try Ollama if enabled
                ollama_analysis = None
                if ollama_available and HAS_REQUESTS:
                    now = time.monotonic()
                    # Re-check Ollama availability every 30s
                    if now - last_ollama_check > 30:
                        try:
                            requests.get(f"{args.ollama_url}/api/tags", timeout=3)
                            ollama_available = True
                        except Exception:
                            ollama_available = False
                        last_ollama_check = now

                    if ollama_available:
                        ollama_analysis = query_ollama(diff, curr_state, args.ollama_url, args.ollama_model)

                # Build output
                lines = [f"[{ts}] tick={tick}"]
                if diff.get("type") == "initial":
                    lines.append("  Initial snapshot loaded")
                else:
                    if "speed_change" in diff:
                        sc = diff["speed_change"]
                        lines.append(f"  Speed: {sc['from']}x → {sc['to']}x")
                    if "paused_change" in diff:
                        lines.append(f"  Paused: {diff['paused_change']}")
                    if "colony_changes" in diff:
                        for k, v in diff["colony_changes"].items():
                            lines.append(f"  {k}: {v['from']:.0%} → {v['to']:.0%}")
                    if "settlement_changes" in diff:
                        for rk, v in diff["settlement_changes"].items():
                            lines.append(f"  Settlement {rk}: {v}")
                    if "jobs_change" in diff:
                        jc = diff["jobs_change"]
                        lines.append(f"  Jobs: {jc['from']} → {jc['to']}")
                    if "new_events" in diff:
                        lines.append(f"  New events: {diff['new_events']}")

                for alert in alerts:
                    lines.append(f"  ⚠ {alert}")

                if ollama_analysis:
                    lines.append(f"  AI: {ollama_analysis}")

                output = "\n".join(lines)
                print(output)
                report_file.write(output + "\n")
                report_file.flush()

            prev_state = curr_state
            time.sleep(args.interval)


if __name__ == "__main__":
    main()
