# HeelKawn — shared context snapshot (copy-paste to any AI)

HISTORICAL SNAPSHOT AID ONLY.

This file is a handoff helper and may be stale.
It is not a canonical state source.
Canonical state lives in `docs/HEELKAWN_STATE.md`.
Any live phase/next-target wording in this file is historical snapshot content only.

**Purpose:** One screen so **ChatGPT, DeepSeek, Cursor**, and the **Creator** stay aligned when context windows reset. (No separate **Copilot** role — **Cursor** holds implementation/integration.)  
**Update:** Revise this file (or the block Cursor emits) when build status, task, or decisions change. **Snapshot-first in substantive replies is mandatory** (see `.cursor/rules/heelkawn-handoff.mdc`).

```text
[HEELKAWN SNAPSHOT]
UPDATED: <YYYY-MM-DD> (or session id)

BUILD STATUS:
- <Godot 4.6; playable Main scene; kernel systems per docs/HEELKAWN_STATE.md>
- <recent features: e.g. throttled sim, context log, etc.>

CURSOR / REPO CURRENT TASK:
- <what implementation is in flight>

LAST CONFIRMED DECISION:
- <do not change without creator / explicit spec>

OPEN QUESTIONS:
- <undecided or blocking>

IMMEDIATE NEXT ACTION:
- <next concrete step>
```

## Current snapshot (living)

[HEELKAWN SNAPSHOT]  
UPDATED: 2026-04-25

**BUILD STATUS:**  
- Godot 4.6; `Main.tscn` is the run scene. Playable: world gen, pawns, jobs, settlements (derived from scars/deaths), animals, trade/roads/remnants, Intent/Sacred/Myth/Cultural/WorldMemory stack.  
- Social systems: `FragmentationManager` / `SchismManager` (pawn relocation, not forked settlement lists); throttled `IntentMemory` / `SettlementMemory` / `PathFinder` path weights; `WorldClock` keyboard hooks; `HEELKAWN CONTEXT LOG` + optional `HEELKAWN CANON_LOG` in `docs/`.  
- Performance: large grid work throttled; partial path refresh near settlement centers between full passes.  
- **Option B (Player exposure slice):** `ColonyHUD` shows world snapshot (settlements, sacred count, social frag/schism from `WorldMemory`, effective global pressure, intent G/H/A + dominant) plus on-screen time controls (Pause, 1x–12x) and a **session-only** `IntentMemory` global pressure nudge (±, reset) affecting the next throttled recompute; keyboard speed/pause unchanged.  
- **Option B1 (Interpretability, read-only):** `settlement_intent_changed` + `intent_recompute_finished` signals on `IntentMemory`; HUD shows a **temporary** batched “Intent change” strip (region key + G/H/A flip) and **factual** lines from the last recompute (`get_intent_explain_bbcode_lines`: global pressure terms, max term, per-settlement driver hit counts). No new player authority, no world writes.

**CURSOR / REPO CURRENT TASK:**  
- None active; Option B + B1 in `ColonyHUD` / `IntentMemory` (signals, `_last_explain` snapshot, aggregated term tallies inside existing recompute).

**LAST CONFIRMED DECISION:**  
- **Snapshot-first workflow is mandatory** for substantive Cursor replies; template + living copy: this file, `docs/HEELKAWN_STATE.md` authoritative.  
- **Cursor replaces the former “Copilot” role** (single in-repo implementer/integrator; no parallel Copilot handoff).  
- Cursor is **lore-aware** but does **not** invent lore; narrative canon from Creator / Lore Authority via `[HEELKAWN CONTEXT LOG]`.  
- Design rules: no RNG in world history; no new per-tick O(N) recompute; explainable history.

**OPEN QUESTIONS:**  
- None blocking in this doc; product tuning (abandonment, architecture styles, player-readable meaning) remain **NEXT INTENT** in HEELKAWN_STATE.

**IMMEDIATE NEXT ACTION:**  
- Run `Main.tscn`, use HUD world line and sim controls; next work from `docs/HEELKAWN_STATE.md` **NEXT INTENT** unless the user steers.
