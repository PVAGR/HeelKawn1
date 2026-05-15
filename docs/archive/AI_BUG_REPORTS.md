# HeelKawn AI Bug Reports

This file tracks blockers surfaced during runtime tests, UI integration, and system stability work.

---

## UI-001: Godot UI Runtime Test Blockers
- Status: OPEN
- Summary: Initial runtime surfaced node-path issues and missing data bindings in SurvivalHUD, Inventory, and Consciousness tab.
- Likely Fixes: Guard checks for null nodes, ensure get_inventory data path exists, wire Consciousness data feed into UI binding.
- Next Steps: Run test plan, log exact console errors, and add patch notes to AI_BUG_REPORTS.md.

---

## UI-002: Building Placement UI Blockers
- Status: OPEN
- Summary: Tests pending; planning minimal UI scaffolding to validate resource checks and placement overlays.
- Next Steps: Add placeholder UI, wire to BuildToolbar, and test interactions.

---

## UI-003: Crafting Menu Blockers
- Status: OPEN
- Summary: Tests pending; craft recipes wiring and inventory integration.
- Next Steps: Create minimal CraftingMenu UI and connect to PlayerGathering.gd
- UI-001: Godot UI Runtime Test blockers (initial scan)
  - Status: OPEN
  - Summary: Placeholder for UI runtime test blockers after first harness run
