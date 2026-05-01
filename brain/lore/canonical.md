# Canonical Universe Truth

This file consolidates the non-negotiable canon of HeelKawn. Any AI making changes to the game MUST consult this file first. If something here conflicts with any other document, THIS file wins (after docs/HEELKAWN_STATE.md).

**Source of truth:** `docs/WORLD_BIBLE/` (full library) and `AI_README.md` (master AI instructions).

---

## Foundational World Laws

### 1. The Deterministic Kernel
The world is a machine of cause and effect. Every event has a traceable cause. No unseeded randomness in world history. Seeded variety (WorldRNG) is allowed for initial conditions only.

### 2. Records Actions, Not Intentions
WorldMemory records what happened, not what was planned. A settlement that intended to build a wall but never did leaves no wall fact.

### 3. Append-Only Memory
History cannot be erased. Facts are appended, never deleted or overwritten. Memory degrades into form (patterns, culture) but individual facts persist.

### 4. Player Role
The player is an ordinary human — an observer and chronicler. Not a commander. Not a god. The world exists with or without the player.

### 5. Collapse and Persistence
Civilizations fall. What survives is not the full record but what was carved into stone, song, and habit. Selective persistence — history degrades into form, not explanation.

---

## Core Themes

- **Incompleteness:** Nothing is ever fully known or finished
- **Legacy over victory:** What you leave behind matters more than what you achieve
- **Memory over power:** Remembering is stronger than conquering
- **Weight:** Actions have permanent consequences
- **Slow time:** Vast spans, gradual change, deep history

---

## Metaphysics (World-Internal)

- **Asha & Druj:** Two currents — order/truth vs chaos/deceit — not good vs evil
- **The Veil:** Boundary between living and dead; thins at certain places/times
- **Seven Ages:** Structural ladder from First Age (primordial) through Seventh (unknown)
- **Life/Death cycle:** Death is not erasure; it is transformation into memory

---

## Faction Philosophy

- Prefer **emergent factions** over authored ones
- Kingdom colors and house names are historical illustration, not mandatory canon
- Factions arise from pressure, geography, and memory — not design fiat

---

## Anti-Patterns (What HeelKawn Must NOT Become)

1. A hero's journey game
2. A morality-play with good/evil meters
3. A base-builder where the player commands everything
4. A roguelike with reset-and-try-again
5. A gacha or progression-grind game
6. A multiplayer competitive game
7. A lore dump disguised as gameplay
8. A game where the player is the center of the universe

---

## Influences (Blended, Not Copied)

WorldBox (scale) + RimWorld (pawns) + Crusader Kings (dynasties) + Dwarf Fortress (depth) + Kenshi (atmosphere) + Songs of Syx (grand strategy) + Stonehearth (settlements) + The Sims (social) + Eco (ecology) + Baldur's Gate (narrative weight) + MapWars (emergence)

---

## Canon Tiers

| Tier | Status | Examples |
|------|--------|----------|
| T1 — Kernel locked | Non-negotiable | Deterministic causality, append-only memory, no RNG in history |
| T2 — Simulation canon | Strong | Geography, biomes, timeline labels |
| T3 — Probable intent | Design direction | Economy, war choreography, classes |
| T4 — Exploratory | Not yet canon | Taured/DRUJ/Ark, parallel Earths, named characters |

---

## Technical Canon

- **Engine:** Godot 4.6, GL Compatibility renderer
- **Determinism:** Seeded streams via WorldRNG; no unseeded random in sim
- **Save format:** Append-only JSON via WorldPersistence
- **Main scene:** `res://scenes/main/Main.tscn`
- **Tick loop:** Main.gd `_process` → GameManager tick emission → system updates
