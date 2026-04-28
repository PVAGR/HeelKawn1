# HeelKawn simulation matrix (CK3 bridge + AI grounding)

Single reference for **what exists**, **who can use it**, and **how it maps to a Crusader Kings III–style grand map** without pretending the shipped game is CK3 yet.

## 1. Reality check (ship vs vision)

| Goal | Status | Notes |
|------|--------|--------|
| Painted parchment / 3D heightmap realm style | **Not shipped** | World is 256×256 **pixel terrain** baked to a texture (`World.gd`), not a province mesh. |
| Click any barony → layers (development, control, faith) | **Partial** | **Focus Inspector** (toggle in `Main.gd`): hover **pawn**, **settlement region**, or **tile** for text snapshots. Not a full province UI. |
| Character sheet + schemes + court | **Partial** | `PawnInfoPanel` + governance lines on pawns; no scheme graph. |
| Factions / houses / dynasties | **Stub** | `FactionRegistry`: deterministic **house record per settlement zone**; not a full diplomacy sim. |
| NPC does everything the player can | **Design target** | Today the **player is observer/chronicler** (`HEELKAWN_STATE.md`). Colony **automation** = pawns + `SettlementPlanner` + jobs; **no separate “AI player”** with the same UI affordances. |
| Boss matrix for AI | **This doc** | Use tables below + optional JSON block for agents. |

## 2. CK3 concept → HeelKawn component (v1 routing)

| CK3 idea | Closest HeelKawn surface today | Code / data |
|----------|---------------------------------|-------------|
| Realm map | Orthographic 2D world + camera | `World`, `CameraController`, `Main.tscn` |
| Province / barony | 16×16 **region_key** + settlement cluster | `WorldMemory._region_key`, `SettlementMemory` |
| County holder / top liege | Governance profile + ruler pawn id | `SettlementMemory.get_governance_profile_for_region` |
| Development / control | Material signals + state hysteresis | Settlement dict: `material_signal_*`, `state` / `state_truth_raw` |
| Faction / house color | House stub per zone | `FactionRegistry` |
| Faith overlay | Read-only lens | `ReligionLens` autoload |
| Chronicle / history | Append-only log | `WorldMemory` |
| Economy policy (player-made) | Intents + specialization channel | `IntentMemory`, settlement `current_intent`, work-focus fields |
| “Everything clickable” | Mouse hover + inspector card | `FocusInspector`, `_build_focus_snapshot` in `Main.gd` |

## 3. Actor capability matrix (who can do what)

Rows = **actors**; columns = **capability classes**. `R` = read-only, `W` = can change sim state, `S` = stub / partial.

| Capability | Human player (observer) | Pawn (NPC agent) | SettlementPlanner | Autoloads (kernel-adjacent) |
|------------|-------------------------|------------------|--------------------|----------------------------|
| Move camera / select pawn | W | — | — | — |
| Stamp buildings / stockpile zones (UI drag) | **—** (shipped off; `PLAYER_CAN_PLACE_STRUCTURES_AND_ZONES`) | — | W (plans jobs) | — |
| Place build intent (jobs on map) | — | W (claim/complete) | W (post jobs) | — |
| Claim / complete jobs | — | W | — | — |
| Modify `WorldData` tiles (harvest, build) | — | W (via jobs) | W | — |
| Append `WorldMemory` events | R | indirect W (actions recorded) | indirect | W (`WorldMemory`) |
| Settlement state / governance | R (UI) | indirect (deaths, pressure) | R/S | W (`SettlementMemory` rules) |
| Cultural reputation | R | bias only | — | derived |
| Faction house record | R | — | — | W (`FactionRegistry` lazy sync) |
| PlayerIntentQueue | W | — | — | W |

**NPC parity (your ask):** To make an **NPC “player”** use the same stack as the human, you need a **single command bus** (intents → same validators as UI) and **one observation API** (what Focus Inspector shows, but programmatic). Today observation is **mouse-driven UI**; pawns use **state machine + jobs**, not the inspector.

## 4. Sensory matrix (what the world “exposes”)

| Channel | Resolution | Consumer |
|---------|------------|----------|
| Tile biome / feature / scar tint | Per tile | `World`, pawns, pathfinder |
| Region meaning label | 16×16 aggregate | HUD, terrain tint cache |
| Settlement list + overlay | Per settlement | `SettlementRegistry`, religion lens |
| Live pawn fields | Per pawn | `PawnData`, panels |
| History slice | Event list | F10 exports, `WorldMemory.get_history_export_string` |

## 5. Kernel rules AI must not violate

From `HEELKAWN_STATE.md`: **no RNG in world history**, **no per-tick O(N) recompute** (design discipline), **derived layers read-only** vs append-only memory, **autoloads do not use `class_name`**.

Any future “boss AI” should **read** these surfaces and **submit** changes only through established writers (jobs, planner, validated intents)—not by mutating derived caches.

## 6. Suggested implementation order (grand map + NPC parity)

1. **Observation API** — one function: `region_key` / `tile` / `pawn_id` → same dictionary the Focus Inspector uses (decouple from mouse).
2. **Command API** — mirror toolbar / edicts into callable methods with shared validation (human + bot).
3. **Map mode** — optional **low-zoom overlay**: region polygons or tinted quads (CK3-like *readability*, not art parity).
4. **Character bar** — pinned rulers per settlement; click jumps camera (reuse selection pipeline).
5. **Dynasty graph** — extend `PawnData` lineage + `FactionRegistry` into a real identity graph (large pass).

## 7. Machine-readable capsule (optional, for agents)

Paste or load alongside this file; bump `matrix_version` when the sim changes.

```json
{
  "matrix_version": "2026-04-27f",
  "engine": "Godot 4.6",
  "player_role": "observer_chronicler",
  "world_representation": "grid_256x256_tile_texture",
  "region_granularity": "16x16_region_key",
  "primary_inspectors": ["FocusInspector", "PawnInfoPanel", "ObserverHUD", "CreatorDebugMenu_F10"],
  "faction_model": "FactionRegistry_house_stub_per_zone",
  "governance_source": "SettlementMemory_governance_profile",
  "history_source": "WorldMemory_append_only",
  "npc_control": "pawns_job_fsm_SettlementPlanner_no_ui_parity_yet",
  "player_manual_construction": false,
  "soul_bundle_report": "CreatorDebugMenu_F10_id_soul_bundle",
  "soul_bundle_script": "res://scripts/kernel/heelkawn_soul_export.gd",
  "distribution_intent": "https://pvabazaar.org — web-attached play (future; not shipped in Godot client today)",
  "integration_notes": "OpenClaw (or successor) bridge TBD — document contract here when chosen; must not violate kernel append-only / no-RNG-history rules unless canon explicitly revises them.",
  "release_tier_a": "Standalone Godot build — participate as pawn-scale actor; PVA Bazaar for distribution/marketing pages (not in-engine web yet).",
  "release_tier_b_maybe": "Shared-screen / hot-seat / LAN-style coop if cheap; true internet MP needs relay or self-host (not free in engineer time).",
  "release_tier_c_later": "New repo or major version: online + OpenClaw-shaped stack; do not block Tier A on this.",
  "portable_character_schema": "heelkawn_character_portable/v1",
  "portable_character_report": "CreatorDebugMenu_F10_id_portable_character"
}
```

## 8. Long-session handoff (1–2 sim years)

**Goal:** Run the sim long enough for the world to “breathe” (planner builds, jobs complete, `WorldMemory` grows), then **copy one block** that still reads well in chat/docs and keeps the **matrix** honest.

| Milestone @ 1x speed | Ticks | Approx wall-clock (0.1s/tick) |
|----------------------|-------|--------------------------------|
| ~1 sim year | `SimTime.TICKS_PER_SIM_YEAR` (30000) | ~50 min |
| ~2 sim years | 60000 | ~100 min |

**What to paste**

1. **F10 → “32 · Soul bundle”** — prints `HEELKAWN_SOUL_BUNDLE`: calendar, `sim_diag`, colony pressures, jobs, settlement count, `WorldMemory` tail (40 dict lines), first ~80 lines of `get_history_export_string(false)`, wildlife snapshot. One contiguous stdout region between `BEGIN` / `END`.
2. Optionally **F10 → “15 · WorldMemory history export”** for the full table if the tail is not enough.
3. Keep **`HEELKAWN_SIM_MATRIX.md`** (this file) + JSON capsule in the same paste folder so readers know what systems the dump refers to.

**Continuity:** The sim does not run “forever” in one Godot session without saves; use **F5/F8** for real continuity across days. The soul bundle is for **observability and AI replay context**, not a substitute for `save.bin`.

**Visuals:** Pawns share a **procedural pixel figure** (`Pawn.PROCEDURAL_PIXEL_PAWN`) driven by the same `PawnData` colors as NPCs — “skin” until bespoke sprites land.

## 9. North star (product vision — **not** shipped sim rules)

Many teams ask: *how do we “create a player” to some degree?* HeelKawn’s **current shipped answer** is still **observer + pawn-local intents + same data model as NPCs** (`HEELKAWN_STATE.md`). Everything below is **intent for later tiers**; it does **not** override kernel constraints until you explicitly revise canon.

| Aspiration (yours) | HeelKawn lane today | Honest gap |
|--------------------|---------------------|------------|
| Life-scale world (work, marriage, society) rivaling mega-budget open worlds | Deterministic colony + settlements + jobs + social/birth hooks + matrix exports | No city-scale streaming, no full “second life” economy, no licensed-scale content pipeline |
| Everyone on **pvabazaar.org** can play the same world | Single-client Godot sim; soul bundle + saves for continuity | Needs **auth, persistence API, anti-abuse, netcode**, and a **contract** between web and sim |
| **OpenClaw** (or chosen stack) as connective tissue | Not wired | Treat as **integration boundary**: document I/O (commands in, state snapshots out), rate limits, and what may never be trusted from the network |

**How to fold “GTA-scale hunger” into the matrix without lying to the build:** keep **§2–§6** as *what runs*. Keep **§9 + JSON `distribution_intent` / `integration_notes`** as *where you’re going*. When a feature ships, **promote** it from §9 into the tables above and bump `matrix_version`.

**Ethical / product reality:** “Take over human lives” is marketing language; shipping systems should still respect player time, consent, and regional law. Put safety and session design in the same spec pass as OpenClaw.

## 10. How we treat **this** repo (decision record)

**Treat HeelKawn (this tree) as a real, shippable product** — a **training / introduction** sim: people **start the game**, **see the NPC world** (planner + jobs + history), and **participate** through the **same pawn loop** (move/interact, cosmetics, selection, exports). You can **roll it out** and point **PVA Bazaar** at builds, patch notes, and community without promising engine features that are not in the binary.

**Treat “OpenClaw + always-on online + second game scale” as a later product or major version** — prepare that **after** Tier A is credible, so scope creep does not collapse the kernel.

### Multiplayer: what “free on GitHub” actually buys you

| Option | Cost pattern | Fit for Tier A |
|--------|----------------|----------------|
| **Single-player + saves + soul bundle** | Free (repo + Godot) | **Yes — now** |
| **Same machine / hot-seat** (pass keyboard) | Free | Possible small UX pass |
| **LAN (ENet) on local network** | Free | Moderate Godot work; no central bill, but you ship two executables and a LAN guide |
| **Internet multiplayer** | Rarely “zero”: relay hosting, NAT, cheating, persistence | Needs design + usually **some** paid VPS or managed relay; engineer time is never free |

**Recommendation:** ship **Tier A** as the story (“play the living world we built”). Add **multiplayer only** when you have a **named stack** (e.g. self-hosted headless + ENet, or a commercial relay) and one maintainer — not because GitHub is free, but because **sync is a product**.

When Tier B or C ships, **promote** rows from this section into §2–§6 and bump `matrix_version`.

## 11. Character continuity (standalone → website / future MMO)

**Intent:** The **first standalone** HeelKawn build is where players **live inside the NPC world**; later services (PVA Bazaar pages, a future MMO, OpenClaw-shaped agents) can **ingest a portable identity** without importing the whole world save.

| Artifact | What it carries | Typical use |
|----------|-----------------|-------------|
| **Save game (F5/F8)** | Full world + all pawns | Same client continuity |
| **Soul bundle (F10 → 32)** | Session / world truth slice | Long-run paste, AI context |
| **Portable character JSON (F10 → 33)** | One pawn: look, lineage hooks, skills/likings, top social edges, `world_seed` + `origin_region_key` | **Website profile**, “import spirit” into a future online build |

**Schema:** `PawnData.PORTABLE_CHARACTER_SCHEMA` (`heelkawn_character_portable/v1`). Bump only when fields change; importers should reject unknown schema versions.

**Not included on purpose (v1):** tile position, active job, inventory — those are **world-bound**; a future MMO spawns you with its own rules and maps `legacy_standalone_pawn_id` + lineage to lore.

**Export path today:** select the pawn you care about → **F10 → “33 · Portable character JSON”** → copy everything between `HEELKAWN_PORTABLE_CHARACTER_JSON BEGIN/END`.
