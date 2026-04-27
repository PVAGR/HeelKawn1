# HEELKAWN — AUTHORITATIVE PROJECT STATE

This is the only canonical live-state file for HeelKawn.

Any conflicting status in `README.md`, `HEELKAWN.txt`, `docs/SESSION_LOG.md`, or snapshot files is non-authoritative.

## Canonical Project Identity

- Deterministic Godot 4.6 world simulation.
- Player role is observer/chronicler, not commander.
- Canonical architecture flow: `WorldMemory -> WorldMeaning -> WorldPersistence -> Culture -> Behavior`.
- Stable truth belongs in repo files, not chat memory.

## Canonical Runtime Surface (autoload map)

Active runtime autoload systems:
- `WorldMemory`
- `WorldMeaning`
- `WorldPersistence`
- `CulturalMemory`
- `SettlementMemory`
- `IntentMemory`
- `AgeMemory`
- `SettlementPlanner`
- `SettlementRebirth`
- `TradePlanner`
- `TradeMemory`
- `RemnantMemory`
- `MythMemory`
- `RoadMemory`
- `SacredMemory`
- `ChronicleLog`
- `WorldClock`
- `WorldEvents`

Core runtime support autoloads:
- `GameManager`
- `JobManager`
- `StockpileManager`
- `ColonySimServices`

## Canonical Determinism Rules (Non-Negotiable)

- No RNG in world history decisions.
- No frame-time authority over simulation truth.
- No per-tick unbounded O(N) recompute loops in world-critical systems.
- Derived layers do not overwrite memory facts.
- History must remain explainable after the fact.
- Autoload scripts must not use `class_name`.

## Current Phase / Active Lane (Locked)

**Phase 8 - Resource Truth / Settlement Economy (active lane).**

Historical phase labels in `docs/SESSION_LOG.md` are continuity records only and do not override this live-state lock.

## Validation Milestone Lock (Canonical Runtime, 2026-04-26)

- Phase 7 canonical validation proof is confirmed.
- Validation harness arming is confirmed in debug runtime (`VALIDATION_SESSION_ENABLED` path).
- Clean-economy event suppression proof is confirmed (`[VALIDATION_EVENT_ROLL_PROOF]` first-roll proof + suppressed contaminated event path during validation runs).
- Settlement-truth verification is confirmed live (`[SETTLEMENT_VERIFY]` with `center_region` continuity key and hysteresis behavior).
- Specialization validation logs are confirmed live (`[SPECIALIZATION_VALIDATE]` on coarse cadence).
- Specialization identity remains proxy/job-pressure derived, not stock scarcity truth.
- Phase 8 stock-truth observational layer exists in runtime (`[RESOURCE_TRUTH]` / proof bundle surfaces).
- First runtime proof pass for stock-truth overlap safety has been achieved.

Validation locks that must not change without explicit approval:
- Proxy specialization identity contract.
- Settlement-truth verify log semantics and continuity keying (`center_region` / hysteresis key behavior).
- Clean validation harness behavior in debug sessions.
- Specialization interpretation rule: proxy/job-pressure based, not stock-scarcity truth.

## Settlement / Ecology Canon (Shipped Truth)

Settlements:
- Build autonomously.
- Diverge culturally (`open`, `cautious`, `defensive`).
- Use deterministic revival/abandonment states:
  - `active`
  - `revivable`
  - `recovering`
  - `abandoned`
  - `permanently_abandoned`
- Rebirth is peace-gated and blocked by hard conflict/scar conditions.
- Regional meaning remains player-readable as quiet/scarred/bloodied/grave.

Ecology:
- Wildlife is deterministic and ongoing.
- Populations can decline, recover, and go locally extinct.

## Active vs Inactive Module Clarity

Active canonical runtime is defined by `project.godot` autoloads and current `Main` wiring.

Not part of canonical autoload runtime surface (treat as non-authoritative unless explicitly promoted):
- `autoloads/FragmentationManager.gd`
- `autoloads/SchismManager.gd`
- `scripts/kernel/settlement_persistence.gd`

## Canon / Historical / Exploratory Classification

### CANON
- Observer/chronicler player role.
- Deterministic world-history principle.
- Memory/meaning/persistence layering and consequence model.
- Settlement abandonment/revival/permanence model as currently shipped.
- Trade/age/myth/remnant/road/sacred systems listed in active autoload runtime surface.
- `center_region` is the continuity key for settlement-truth tracking and diagnostics.

### HISTORICAL REFERENCE ONLY
- `docs/SESSION_LOG.md` (append-only continuity log).
- `HEELKAWN.txt` (short handoff pointer file, not canonical state).
- `HEELKAWN_KERNEL.md` (legacy kernel notes).
- `docs/HEELKAWN_SNAPSHOT.md` (snapshot handoff aid).

### EXPLORATORY / NOT CANON-LOCKED
- Long-horizon platform/community/streaming integrations and product expansion ideas.
- Experimental notes not promoted into this file.

## Next Target (Locked)

- Cached per-settlement surplus/deficit interpretation layered on top of proven stock truth.

## Determinism Scope Honesty

- HeelKawn is a deterministic world-simulation project by design and validation lane.
- Canonical validation/proof lanes above are locked and proven in debug runtime.
- Known randomness risks still exist in other non-locked runtime subsystems and remain separate cleanup work; do not overclaim full-repo determinism completion.

## Required Read Order for Humans and AIs

1. `docs/HEELKAWN_STATE.md` (this file)
2. `docs/LLM_ONBOARDING.md`
3. `README.md`
4. `docs/SESSION_LOG.md` (history/continuity only)
