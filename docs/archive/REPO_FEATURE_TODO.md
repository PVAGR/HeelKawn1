# HeelKawn — Feature & Implementation TODO

This file is an auto-generated feature backlog snapshot created by the assistant.

## Priority (Immediate)
- Run `scripts/tests/TestTraitSystem.gd` in Godot to validate Krond and trait application.
- Add trait purchase UI and hook to `Pawn.apply_trait()` (basic shop implemented at `scripts/ui/TraitShop.gd`).
- Add a quick chronicle export button/hotkey (F7) and debug Krond grant (F3) — implemented in `scenes/main/Main.gd`.

## Priority (High)
- Persist trait purchases robustly: save resource paths (res://...) or IDs, and re-load resources on load.
- Implement a player-facing trait catalog (descriptions, icons, filters) and confirm UX flows for purchase confirmation.
- Add integration tests: save/load roundtrip for a pawn with active traits and non-zero Krond.

## Priority (Medium)
- Chronicle UI: compact exporter and export history panel; allow `user://exports` browsing and upload sign-off.
- Trait effects integration: wire trait `effects` dictionary into `Pawn` stat modifiers (attack, defense, gather speed, etc.).
- Economy tuning: adjust `KROND_PER_KILL`, trait costs, and sinks (e.g., trait upgrades, consumables).

## Priority (Low / Long-term)
- Chronicle submission workflow (canon submission): package exports, provenance, and metadata (player, seed, tick range).
- Trait marketplace: randomized daily offerings, cooldowns, and limited inventory across saves.
- UI polish: animated shop, tooltips, localization, icons and art.

---

Files touched by the assistant in this pass:
- `scenes/main/Main.gd` (hotkeys + export/grant helpers + trait shop toggle)
- `scripts/ui/TraitShop.gd` (new UI shop script)
- `autoloads/WorldMemory.gd` (export_chronicle helper)
- `docs/REPO_FEATURE_TODO.md` (this file)

Run this locally:

1) Open Godot, load the project.
2) Run the scene/test:
   - Add a Node with `scripts/tests/TestTraitSystem.gd` to a test scene and run.
3) Use hotkeys while running the main scene:
   - `F7` -> export chronicle to `user://exports/chronicle_<tick>.json`
   - `F3` -> grant 25 Kr to incarnated player pawn (debug only)
   - `U` -> open Trait Shop UI (loads `res://data/traits/` if present)


If you want, I can now:
- Run through save/load persistence of trait purchases and implement resource-path-backed saving.
- Add nicer HUD purchase affordance and cart flow.
- Wire trait `effects` into `Pawn` stat application.

