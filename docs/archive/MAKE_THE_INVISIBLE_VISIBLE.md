# MAKE THE INVISIBLE VISIBLE — HeelKawn's Revolutionary Edge

**Created:** 2026-05-14 by Letta
**Status:** ACTIVE — This is the current build priority. All AI agents read this first.

---

## The Problem

HeelKawn has **137 autoloads**, **86 systems wired to the game tick**, and **377 GDScript files**. But most of these systems are *invisible*. They track state, record events, and wait to be called — but a spectator watching the game cannot *see* them happen.

Culture is numbers in CulturalMemory. Religion is devotion scores in ReligionSystem. Grudges are entries in GrudgeManager. The economy is trade volumes in CurrencySystem. Sacred geography is memorial counts in SacredGeography.

**None of this renders on the map.**

The Truman experience means: you watch the world and *see* the story unfold. You don't open a panel. The world tells its own story through what's built, what's worn, what's grown, what's decayed.

**This is the single thing no other game does.** Other games have culture systems. Other games have religion. Other games have grudges. But they all show you these things through UI panels and text logs. HeelKawn will show you through the *world itself*.

---

## The 6 Pillars of Visible Emergence

### Pillar 1: Cultural Architecture Rendering
**Settlements develop visible building styles that drift over time and merge when populations mix.**

- Each settlement has a `cultural_style` derived from CulturalMemory + CulturalStyleManager
- Buildings in that settlement get tinted/rendered with the settlement's style
- When two settlements trade heavily, their styles blend at the border
- When a settlement is conquered, the conqueror's style slowly replaces the original
- A player can look at two settlements and *see* that they're different cultures — not read it

**Implementation:**
- `WorldOverlay.gd` already has culture tints for buildings. Extend this.
- `CulturalStyleManager.gd` already tracks style per settlement. Use it for rendering.
- Add `get_cultural_color_for_settlement(settlement_id)` that returns a Color
- Apply to all buildings in that settlement's territory
- Blend colors at territory borders
- When settlements merge, blend their cultural colors

**Files to modify:**
- `autoloads/CulturalStyleManager.gd` — add `get_cultural_color_for_settlement()`
- `scenes/world/WorldOverlay.gd` — apply cultural color to building rendering
- `autoloads/SettlementMemory.gd` — track cultural drift per recompute

### Pillar 2: Physical History on Pawns
**A pawn who survived a plague walks slower and has a visible scar. A veteran carries a notched spear. A mother carries her child. A grieving pawn wears a token.**

- BodyPartWounds already tracks wounds. Add *visible* wound indicators (colored dots on sprite)
- Life stages already change stats. Add *visible* age indicators (gray hair for elders, small sprite for children)
- Profession affects what the pawn carries visually (builder carries hammer, healer carries herbs)
- Grieving pawns have a visual token (small dark circle)
- Veterans have a visual notch on their weapon

**Implementation:**
- `HeelKawnian.gd` sprite rendering — add overlay indicators
- `WorldOverlay.gd` — add pawn detail rendering (scar dots, age indicators)
- `HeelKawnianData.gd` — add `get_visual_indicators()` that returns array of {type, color, position}

**Files to modify:**
- `scripts/pawn/HeelKawnian.gd` — add visual indicator rendering
- `scripts/pawn/HeelKawnianData.gd` — add `get_visual_indicators()`
- `scenes/world/WorldOverlay.gd` — render pawn overlays

### Pillar 3: The Land Remembers
**Battlefields grow different grass. Old roads become paths. Burned forests regrow differently. Abandoned settlements crumble.**

- FootpathMemory already tracks foot traffic. Render it as visible paths on terrain.
- SacredGeography already tracks sacred tiles. Render them with a subtle glow.
- Battle sites: after combat, mark tiles. Over time, these tiles grow red-tinted grass.
- Burned forests: after fire, tiles regrow as lighter, sparser forest.
- Abandoned buildings: decay over time (color fades, then feature removed).
- Ruins: collapsed buildings leave a ruin feature that persists for centuries.

**Implementation:**
- `WorldOverlay.gd` — render footpaths as subtle brown lines on terrain
- `WorldOverlay.gd` — render sacred tiles with a faint blue glow
- `World.gd` — terrain color influenced by battle/death history
- `TileFeature.gd` — add RUIN type
- `WorldPersistence.gd` — track decay timers on abandoned features

**Files to modify:**
- `scenes/world/WorldOverlay.gd` — path rendering, sacred glow
- `scenes/world/World.gd` — terrain color from history
- `scripts/world/TileFeature.gd` — add RUIN enum
- `autoloads/WorldPersistence.gd` — decay timers

### Pillar 4: Audible Language Divergence
**Settlements develop different speech patterns. A traveler from another settlement speaks differently.**

- LanguageSystem already generates naming patterns per settlement.
- Extend to PawnChatter: different settlements use different word patterns in speech bubbles.
- Over many generations, two isolated settlements produce very different "dialects."
- Trade/contact slows divergence. Isolation accelerates it.
- A player can *hear* (read) the cultural drift in how HeelKawnians talk.

**Implementation:**
- `autoloads/LanguageSystem.gd` — add `generate_phrase(settlement_id, intent)` for chatter
- `autoloads/PawnChatterBubbles.gd` — use LanguageSystem for phrase generation
- `autoloads/CulturalMemory.gd` — track language divergence rate

**Files to modify:**
- `autoloads/LanguageSystem.gd` — phrase generation
- `autoloads/PawnChatterBubbles.gd` — use settlement dialect
- `autoloads/CulturalMemory.gd` — language divergence tracking

### Pillar 5: Death Becomes the Landscape
**When a HeelKawnian dies, their body becomes a feature. Their grave becomes a landmark. Their unfinished work decays. Their children inherit.**

- MemorialSystem already creates graves. Make them *visible* on the map (small markers).
- SacredGeography already tracks significance. Make sacred ground *glow*.
- Unfinished buildings decay into ruins over time.
- Dead pawns' tools are inherited by children (already in BloodlineSystem).
- A battlefield with many graves becomes a "memorial field" — a visible landmark.

**Implementation:**
- `WorldOverlay.gd` — render grave markers as small crosses/dots
- `WorldOverlay.gd` — render memorial fields with a subtle aura
- `autoloads/WorldPersistence.gd` — add decay timer for unfinished buildings
- `autoloads/BloodlineSystem.gd` — ensure inheritance of tools/possessions

**Files to modify:**
- `scenes/world/WorldOverlay.gd` — grave rendering, memorial fields
- `autoloads/WorldPersistence.gd` — building decay
- `autoloads/BloodlineSystem.gd` — possession inheritance

### Pillar 6: The Economy is a Living River
**Trade routes visible on the map. Caravans walking between settlements. Stockpiles visibly growing and shrinking.**

- TradePlanner already plans trade. Make it *visible* — pawns physically carry goods between settlements.
- TradeMemory already tracks routes. Render them as dotted lines on the minimap.
- StockpileManager already tracks inventory. Make stockpile zones visually pulse when full/empty.
- CurrencySystem already tracks phases. When currency emerges, show coins in stockpiles.

**Implementation:**
- `scripts/pawn/HeelKawnian.gd` — TRADE_CARRY state: pawn walks between settlements with goods
- `scripts/ui/Minimap.gd` — render trade routes as dotted lines
- `scenes/world/WorldOverlay.gd` — stockpile fill indicators
- `autoloads/TradePlanner.gd` — spawn trade caravan jobs

**Files to modify:**
- `scripts/pawn/HeelKawnian.gd` — TRADE_CARRY state
- `scripts/ui/Minimap.gd` — trade route rendering
- `scenes/world/WorldOverlay.gd` — stockpile indicators
- `autoloads/TradePlanner.gd` — caravan job spawning

---

## Build Order (Priority Sequence)

1. **Pillar 1: Cultural Architecture Rendering** — highest impact, most systems already exist
2. **Pillar 3: The Land Remembers** — footpaths + sacred glow + ruins
3. **Pillar 5: Death Becomes the Landscape** — grave rendering + building decay
4. **Pillar 2: Physical History on Pawns** — visual indicators on sprites
5. **Pillar 4: Audible Language Divergence** — chatter dialects
6. **Pillar 6: The Economy is a Living River** — trade routes + caravans

---

## Technical Notes for AI Agents

- All rendering goes through `WorldOverlay.gd` or `HeelKawnian.gd` sprite system
- CulturalStyleManager already has `get_style_for_settlement()` — extend it
- FootpathMemory already has `get_foot_traffic(tile)` — render it
- SacredGeography already has `sacred_tiles` dict — render it
- MemorialSystem already creates graves — just render them
- TileFeature needs RUIN type added (enum + color + name)
- Performance: all new rendering must use the existing budget system (6ms per frame at 60fps)
- Use sparse rendering: don't render every tile, sample every 2nd-4th tile
- Cache rendered overlays: only re-render when data changes (dirty flags)

---

## What "Done" Looks Like

A spectator boots HeelKawn, watches for 5 minutes, and can see:
- Two settlements with visibly different building colors (culture)
- A path worn between them from foot traffic (land remembers)
- A grave marker near an old battlefield (death = landscape)
- An elder with gray hair walking slowly (physical history)
- A speech bubble from one settlement using different words than another (language)
- A pawn carrying goods along a visible trade route (economy)

**No UI panels opened. No tooltips hovered. Just watching.**
