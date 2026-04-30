# GAME VISION

This file captures the long-horizon HeelKawn product direction so future sessions can resume without rebuilding context.

## North Star

HeelKawn is a persistent historical simulation where players are citizens inside a living world, not omnipotent controllers of it.

## Design DNA

- Deterministic simulation first (cause and effect, replayable history).
- Community-driven history (observer/chronicler framing, not scripted hero arcs).
- Roles with social consequence (ruler, soldier, trader, cartographer, healer, builder, etc.).
- Long-form world continuity (worlds remembered, archived, and compared by eras).

## Three layer archetypes (how the game is organized)

These are **roles** for different parts of the experience—not three games to clone.

1. **Dwarf Fortress spirit — the bible (substrate)**  
   Deep, durable **memory**: chronicles, facts, lineage, jobs, persistence. This is the hidden web every subsystem should **read from and append to** (`WorldMemory`, settlement persistence, death records, intent echoes, etc.). Players rarely see every row; **authority** lives here.

2. **RimWorld spirit — the lived surface (face)**  
   What people **feel** while playing: readable needs, moods, recent consequences, short queues. Not a dumbed-down simulation—a **clear reading** of it. Colony HUD, pawn sheet, and everyday feedback stay in this band.

3. **Songs of Syx spirit — the crown view (map)**  
   **Toggleable macro lenses**: settlements, houses, faith/myth tones, regions, trade and pressure at realm scale—seeing **structure** across the world without micromanaging every tile. Observer tools, focus/chronicler routing, and grand-map ambition live here.

**One-line doctrine:** sim depth like a fortress chronicle; human face like a colony story; realm chart like a ruling council’s map.

## Inspiration Blend

- Dwarf Fortress: total recorded history, procedural depth, “everything leaves a trace” discipline.
- RimWorld: emotional readability of individuals and small-group consequence.
- Crusader Kings: dynastic politics, diplomacy, succession pressure.
- Mount and Blade: battlefield hierarchy, command structure, social mobility through conflict.
- Kenshi: harsh world pressure and emergent survival stories.
- Songs of Syx: large-scale settlement development and population logistics.
- WorldBox: macro-simulation readability and sandbox causality.
- Baldur's Gate / tabletop DNA: mythic world flavor, role identity, reactive narrative framing.
- Eco: ecosystems and civilization pressure loops.

## Intended Experience Layers

1. Core world simulation (already active in this repo).
2. Settlement/cultural identity divergence through deterministic history.
3. Player-facing observer tools to read meaning (camera, ambience, world expression).
4. Future community scale layer (stream/web/mobile integrations) built on top of stable simulation truth.

## Scope Guardrails

- Never replace deterministic world truth with scripted convenience.
- New systems must read from memory/meaning/persistence instead of bypassing them.
- No feature should require breaking existing non-negotiables in `docs/HEELKAWN_STATE.md`.
- **UI simplicity** (RimWorld band) must not skip **fact logging** (fortress bible); **macro lenses** (Syx band) must **query** the same stores, not duplicate state.
