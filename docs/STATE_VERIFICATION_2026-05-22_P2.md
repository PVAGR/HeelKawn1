# State Verification — Material Reality: Crafting & Consumption
**Date:** 2026-05-22
**Task:** Verify all crafting paths actually consume resources, fix broken mappings, close gameplay gaps.

## Bugs Found & Fixed

### Bug 1: CraftingSystem.gd — Wrong integer literals for resource-to-item mapping
The `_get_stockpile_quantity()` and `_consume_ingredients()` functions used raw integers:
- `"iron": 4` → actually `Item.Type.MEAT` (wrong! should be `Item.Type.IRON_ORE` = 34)
- `"herbs": 5` → actually `Item.Type.FLINT` (wrong! no HERBS type existed)
- `"cloth": 6` → actually `Item.Type.STICK` (wrong! no CLOTH type existed)

These three recipes (iron_sword, herbal_remedy, bandages) would never correctly check or consume resources.

**Fix:** Replaced with proper `Item.Type.IRON_ORE` references. Removed "herbs"/"cloth" recipes since no corresponding Item.Type exists — replaced with ingredients that use real Item.Type values (BERRY, BONE, etc.)

### Bug 2: CraftingSystem.gd — Wrong integer literals for output items
The output_item values used raw integers that didn't match Item.Type:
- `"output_item": 10` → meant FLINT_KNIFE but 10 = WOODEN_SPEAR
- `"output_item": 13` → meant FLINT_PICK but 13 = SEEDS
- `"output_item": 14` → meant WOODEN_SPEAR but 14 = COOKED_BERRIES
- `"output_item": 20` → meant IRON_SWORD but 20 = WRITTEN_BOOK
- `"output_item": 30` → meant FURNITURE_TABLE but 30 = ALE
- `"output_item": 40/41` → meant HERBAL_MEDICINE/BANDAGES but don't exist

**Fix:** Replaced with proper `Item.Type` enum values.

### Verification: _finish_craft() material consumption
`HeelKawnian.gd:_finish_craft()` uses `Item.get_recipe()` which returns `Item.CRAFTING_RECIPES` — this uses proper `Item.Type` enums throughout. The consumption path via `_target_zone.take_item()` and the StockpileManager fallback is correct. **No fix needed.**

### Verification: _finish_shelter_build() / _consume_all_build_materials()
Build jobs consume materials via `_consume_all_build_materials()` which checks `_resolved_cost_entries_for_build()` using `Item.Type` enums and stockpile lookup. This path is correct. **No fix needed.**

### Verification: CraftingSystem._complete_crafting_job() consumption
When CraftingSystem completes a crafting job via `_complete_crafting_job()`, it calls `_consume_ingredients()` which now uses proper Item.Type references. **Fixed.**

## What Remains Unverified
- The CraftingSystem recipes are reachable via `start_crafting()` but no Job.Type currently triggers this path — they're wired for future workshop crafting
- Simple tool crafting (CRAFT_KNIFE, CRAFT_TORCH, CRAFT_PICK, CRAFT_SPEAR) goes through the correct `_finish_craft()` path