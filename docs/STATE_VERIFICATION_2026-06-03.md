# State Verification 2026-06-03

## What Changed

- `autoloads/JobManager.gd` (L133-134, L461-464, L512-527): replaced 2-arg `Object.get` calls on `HeelKawnianData` with direct property access, corrected `likes`/`dislikes` shape check from `Array` to `Dictionary`, and added the missing `complete(job)` method.
- `scripts/jobs/Job.gd` (L283-302): added `complete(_pawn = null)` compatibility wrapper that delegates to `/root/JobManager.complete(self)`. Idempotent via state guard + JobManager guard.
- `tools/year1_visible_growth_smoke.gd` (L381): replaced 2-arg `Object.get("last_claim_failure_reason", "")` on `HeelKawnianData` with direct property access.

## What Was Verified

- `tools/ai/verify-compile.ps1` (Godot 4.6.2 `--headless --script-check`) ran clean for all changed files. No new "Invalid call" or parse errors.
- All 2-arg `.get(key, default)` call sites across the repo were classified. The three fixes above are the only "definitely wrong" cases. Remaining 2-arg call sites all operate on real `Dictionary` receivers (settlement dict, event dict, NPC dict, consciousness dict, structure record, etc.) and are correct.
- `JobManager.complete(job)` is the canonical completion path; the new `Job.complete(pawn)` wrapper is a pure passthrough guarded against double-completion by three layers (Job state guard, JobManager state guard, state mutation inside JobManager only).
- Property `last_claim_failure_reason: String` confirmed present on `HeelKawnianData.gd:497`.

## What Remains Unverified / Risky

- Runtime behavior (year1 smoke, settlement lifecycle, 1x/100x performance) was not executed end-to-end in this round; only the headless compile/script-check gate was run. Live smoke harness should be re-exercised before claiming "stable at 100x" or "settlement public state smoke" green.
- `scripts/ui/PawnMoodUI.gd` uses 1-arg `.get("thoughts")`/`.get("wounds")`/`.get("body_wounds")`/`.get("diseases")`/`.get("social")`/`.get("comfort")`/`.get("safety")` on `HeelKawnianData` for properties that don't exist. These return `null` silently. UI is silently broken; not patched in this crash-prevention-only round.
- Pre-existing repo warnings unchanged: `Rect2i size is negative` (large volume), `AgeMemory` singleton missing, `AISettlementManager.gd` missing, `WorldRNG.gd` `unit` nonexistent function, `add_child()` race during scene setup.
- Three `WorldMemory.gd` files exist (autoload + kernel shim + unverified scripts/persistence copy); two `ChronicleExport.gd` files exist (autoload + narrative scripts/system). Out of scope.

---

## PawnMoodUI truth repair (later this session)

### What changed

- `scripts/ui/PawnMoodUI.gd`: every 1-arg `.get("...")` against HeelKawnianData replaced with a real source.
  - `display_name` → direct property.
  - `mood` → direct property.
  - Needs: `hunger`/`rest` direct; `social` → `need_satisfaction.belonging`; `safety` → `need_satisfaction.safety`; `comfort` → `clampf(100 - pain, 0, 100)` (derived from real `pain` field, no fake field invented).
  - `thoughts` (does not exist on data) → `mood_events: Array[MoodEvent]`, display `mood_event.description`.
  - `traits` was reading Object metadata (`has_meta`/`get_meta`) which was never set, so the chips were always empty → now reads the real `traits: Array[Trait]` and displays each `Trait.display_name`.
  - `wounds` (does not exist) → `injuries: Dictionary`, `injuries.size()`.
  - `health` → direct property.
  - Also tightened the typed local from `Node` to `HeelKawnianData` so future silent-null regressions are caught at parse time.
- New file: `tools/test_pawn_mood_ui_smoke.gd`. New doc: this section.

### What was verified

- `tools/ai/verify-compile.ps1` (Godot 4.6.2 `--headless --script-check`) ran clean. Autoloads registered, no new parse errors related to PawnMoodUI. Pre-existing `AISettlementManager.gd` warning unchanged.
- `tools/test_pawn_mood_ui_smoke.gd` ran with exit 0 and reported `[PMUI_SMOKE] PASS`. The smoke instantiates a HeelKawnianData with realistic non-default values (typed Trait, typed MoodEvent, injuries, need_satisfaction), wires it into a freshly-instantiated PawnMoodUI, calls each update method, and asserts label text and progress-bar values match the real data. All 19 expectations passed. No `Invalid call` errors during the run.

### What remains unverified / risky

- The smoke exercises the update methods directly. The scene-tree path (`_update_display` → `main.get_pawn_spawner` → `pawn_data_for_id`) is not exercised because it requires the full Main scene to be loaded and the same `Array[HeelKawnian]` typing issue seen in `SettlementMemory.gd:2197` to clear. The `set_pawn(pawn_id)` path remains unverified in this round.
- `MoodEvent.description` is set inside `_set_description()`; an externally constructed `MoodEvent` that bypasses `_init` would produce an empty description. This isn't done in the codebase, but it is a brittle assumption.
- `Trait.display_name` is set inside `_init_from_type()`; same caveat. The pre-existing `active_traits: Array` (untyped) on HeelKawnianData accepts arbitrary `Resource`s that might not be Traits. If a non-Trait resource is in `active_traits`, the `for t in _pawn_data.traits` loop would still show the chip but with an empty text. This is silent in the current code; not patched.
- The "social" / "comfort" / "safety" mapping is a UI-level translation, not a real pawn-data field. If the kernel eventually introduces native `social`/`comfort`/`safety` needs, the UI should be updated to read those directly.
