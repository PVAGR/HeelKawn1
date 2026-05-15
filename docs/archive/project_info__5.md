# HeelKawn — Codebase Overview & “What else should we put in HeelKawn?”
*(Explore Mode report — focused on canon vision gaps + repo-internal build inventory reality.)*

## Summary
HeelKawn is a **Persistent Simulation Universe** implemented as a deterministic Godot simulation where **WorldMemory records objective events** and **WorldMeaning derives interpretive “meaning”** from those facts. The repo is currently strongest at the **kernel**, **pawn job/needs/social dynamics**, **settlement lifecycle** (active → abandoned → reviving → permanent ruin), **knowledge preservation primitives**, and an **initial civilization-stage lens** and **per-pawn Matrix AI job-bias wiring**. The project is explicitly **not a finished release**; the biggest “what else” items are the v1 gating gaps called out by `docs/BUILD_INVENTORY.md` and the follow-on Matrix/lineage/crafting/exports loops described across `docs/HEELKAWN_STATE.md`, `docs/HEELKAWN_PROJECT_COMPASS.md`, and `docs/HEELKAWN_BLUEPRINT.md`.

## Architecture
- **Primary pattern:** deterministic simulation with **event/ledger-first state**  
  - Core fact capture: `autoloads/WorldMemory.gd` (append-ish event ledger)
  - Interpretation/derived overlays: `autoloads/WorldMeaning.gd` and various “meaning cue” controllers
- **Major subsystems (as represented by docs/build inventory):**
  - **Kernel loop + tick/time:** `autoloads/WorldClock.gd`, `autoloads/WorldRNG.gd`, `autoloads/TickRateDecoupler.gd`, `autoloads/EventBus.gd`
  - **World persistence:** `autoloads/WorldPersistence.gd` + settlement persistence/recovery
  - **Settlement simulation:** `autoloads/SettlementMemory.gd`, `autoloads/SettlementPlanner.gd`, `autoloads/SettlementArchitect.gd`, `autoloads/SettlementRegistry.gd`, `autoloads/SettlementRebirth.gd`
  - **Pawn simulation:** `scripts/pawn/Pawn.gd`, `scripts/pawn/PawnData.gd`, `autoloads/JobManager.gd`
  - **Knowledge & meaning:** `autoloads/KnowledgeSystem.gd`, `autoloads/CulturalMemory.gd`, `autoloads/WorldMeaning.gd`, UI/UX cues such as `autoloads/MeaningAmbianceController.gd`, `scripts/MeaningAudioCue.gd` (per inventory/blueprint)
  - **AI autonomy scaffolding:** “Matrix” identity/profile layers in `autoloads/HeelKawnianManager.gd` + `autoloads/HeelKawnianIdentity.gd` influencing pawn job claiming in `scripts/pawn/Pawn.gd`
- **Technology stack:** Godot 4.x GDScript (project is Godot-first; docs refer to autoloads and scripts/pawn).
- **Execution start / runtime loop:** Godot boots autoloads and runs the main scene tick loop (the build/status docs emphasize deterministic ticking, headless smoke checks, and F10 diagnostics for verification).

## Directory Structure (annotated; only meaningful highlights)
```
project-root/
├── autoloads/                 — Godot autoload singletons (WorldMemory, SettlementMemory, etc.)
├── scripts/                  — Core gameplay scripts (pawn logic, systems, AI glue)
├── scenes/                   — Main scene + UI/observer scenes (e.g., scenes/main/Main.gd)
├── docs/                     — Canon + vision + runtime status + build inventory
├── memory/                   — Runtime memory artifacts (likely generated / persisted)
├── addons/                   — Optional helper addons (AI assistant hub, Godot assistant integrations)
├── tests/                    — Godot/system tests or automation scripts
└── tools/                    — Godot verification / tooling scripts
```

## Key Abstractions (most central to “what else to put in HeelKawn”)
### 1) WorldMemory
- **File**: `autoloads/WorldMemory.gd` (referenced in docs/HEELKAWN_* and BUILD_INVENTORY)
- **Responsibility**: Fact ledger + historical event recording; source-of-truth for determinism and replayable causality.
- **Interface (conceptual from docs)**: `record_event(...)`, queries by tile/region, and readable export helpers (mentioned in HEELKAWN.txt log).
- **Lifecycle**: Lives as an autoload; persists across ticks; participates in exports/save.
- **Used by**: WorldMeaning derivation, AI decision/audit logs, chronicle/summary generation (some still missing/“not yet implemented”).

### 2) WorldMeaning
- **File**: `autoloads/WorldMeaning.gd`
- **Responsibility**: Derived “interpretation” tags and meaning cues from stored facts; must not rewrite the ledger.
- **Lifecycle**: Recomputed/updated as part of world update pipeline.
- **Used by**: Meaning cue controllers + player-facing “why this matters” overlays.

### 3) SettlementMemory
- **File**: `autoloads/SettlementMemory.gd`
- **Responsibility**: Clustered settlement/region state curves and persistence (including lifecycle labels).
- **Lifecycle**: Updated by planners and pawn activity; drives region tints/state for long-term continuity.
- **Used by**: Settlement planners, UI/HUD, meaning computation, revival gates.

### 4) SettlementPlanner / SettlementArchitect
- **Files**: `autoloads/SettlementPlanner.gd`, `autoloads/SettlementArchitect.gd`
- **Responsibility**: Autonomous building intent generation and placement logic (deterministic autonomy).
- **Lifecycle**: Runs on tick cadence; consults memory + resource availability.
- **Used by**: Settlement growth and Phase 4 lifecycle hooks.

### 5) Pawn + PawnData
- **Files**: `scripts/pawn/Pawn.gd`, `scripts/pawn/PawnData.gd`
- **Responsibility**: Agent behavior, needs/skills/professions, job claiming, autonomy, and (via PawnData) progression/branching.
- **Lifecycle**: Spawn → act across ticks → death → recorded in WorldMemory.
- **Used by**: Job manager, Matrix bias wiring, social systems, knowledge/teaching hooks (incomplete/wiring gap).

### 6) JobManager
- **File**: `autoloads/JobManager.gd`
- **Responsibility**: Claims and executes jobs, with compatibility adapters (dict-post mapping) for older call sites.
- **Lifecycle**: Active queue across simulation; affects pawn job selection deterministically.
- **Used by**: Pawn job claiming; settlement planners; auto-build seed systems.

### 7) HeelKawnian Matrix AI (identity → biases)
- **Files**: `autoloads/HeelKawnianManager.gd`, `autoloads/HeelKawnianIdentity.gd`, `scripts/pawn/Pawn.gd`
- **Responsibility**: Turn pawn phase/drive/traits/skills/knowledge/era into deterministic job priority biases; includes initial social intent suggestions.
- **Lifecycle**: Lives as autoload(s); per-pawn profile derived each tick or when needed; logs auditable Matrix decisions back to WorldMemory.
- **Used by**: Pawn idle autonomy and job claiming.

### 8) CraftingSystem (currently missing “material reality” wiring)
- **File**: `autoloads/CraftingSystem.gd`
- **Responsibility**: Recipes and crafting pipeline (recipes exist; consumption still missing inventory/stockpile integration).
- **Lifecycle**: Triggered by jobs; modifies/creates items if material requirements are satisfied.
- **Used by**: Builder/worker jobs and tool/item systems (still TODO).

## Data Flow (primary “ledger-first” flow)
1. **Pawn acts** (movement, gathering, building, social interactions) based on deterministic state in `scripts/pawn/Pawn.gd`.
2. **WorldMemory records** meaningful events as objective ledger facts (`autoloads/WorldMemory.gd`).
3. **WorldMeaning derives** tags/cues from ledger facts (`autoloads/WorldMeaning.gd`).
4. **UI/diagnostics read derived meaning** for player readability (audio/ambiance cue controllers and HUD layers).
5. **Settlement lifecycle** uses `SettlementMemory` state curves and revival gates; planners propose construction and log meaningful changes.
6. **Matrix AI** uses derived per-pawn development profiles to bias job claiming, and logs strong decisions to WorldMemory for auditability.

## Non-Obvious Behaviors & Design Decisions (what a new developer must internalize)
- **Determinism is the authority contract**: randomness must be routed through `WorldRNG`, and “AI learning” must be auditable and replayable from WorldMemory facts; LLM text is presentation unless converted into deterministic world data.
- **Meaning cannot rewrite facts**: WorldMeaning summarizes/derives; WorldMemory remains higher authority. This design prevents “AI-sounding lies.”
- **Doc language is intentionally separated into vision vs runtime truth**:  
  - `docs/HEELKAWN_PROJECT_COMPASS.md` defines truth hierarchy and warns that only runtime checks + inventory justify “verified” status.
  - `docs/BUILD_INVENTORY.md` applies strict status labels and calls out runtime verification gaps.
- **v1 progress gating is integration, not feature count**: Build inventory explicitly prioritizes lineage/skill trees/crafting material reality/teaching wiring/exports because those connect multiple systems into a coherent loop.
- **Performance tuning is part of correctness**: many earlier notes mention throttling, caching, cadence staggering—so “what else to put” must respect tick budgets and avoid new global scans/events storms.

## What else should we put in HeelKawn? (prioritized, repo-backed checklist)
This is the actionable interpretation of the repo’s own vision + build inventory + current state “next tasks.”

### P0 — Next v1 “truth + playable loop” items (highest impact)
1. **Runtime truth pass in Godot (editor verification)**  
   - Inventory and compass docs both emphasize “headless smoke passed” is not enough; the missing piece is confirming systems in-editor without red UI/runtime errors.
2. **HeelKawnian Matrix AI deepening beyond job bias**  
   - Current wiring exists (job bias + some social intent). Missing: household intent, coordinated group plans, teaching target choice, recovery behavior, longer-horizon settlement ambitions—while staying deterministic and auditable.
3. **Skill trees / progression branching**  
   - `scripts/pawn/PawnData.gd` has TODO slots at levels **5/10/15/20**.
4. **Lineage/kinship depth + real child creation**  
   - `scripts/pawn/PawnData.gd` TODO parent lookup; `scripts/pawn/Pawn.gd` TODO child creation/spawn.

### P1 — Make existing systems feel “real” via material + knowledge loops
5. **Crafting material consumption (inventory/stockpile integration)**  
   - Recipes exist; consumption and tool/item checks are still TODO/stub-level.
6. **Teaching/knowledge propagation end-to-end wiring**
   - Knowledge system exists, but teaching propagation is not fully connected into pawn teaching behavior.
7. **Chronicle + seed/state export**
   - WorldMemory has readable export helpers mentioned in logs, but inventory marks chronicle/world seed export as not implemented/auto-generated.

### P2 — Expand narrative civilization layers after v1 loop cohesion
8. **Civilization stage foundation deepening**
   - Initial lens exists; extend with per-settlement tech diffusion, literacy, lifespan, institutions.
9. **Governance/faction/religion depth**
   - FactionRegistry is currently stubbed (“house stub per zone” only); ReligionLens is read-only with Sacred/Myth/DRUJ/Asha etc explicitly unimplemented.

## Suggested Reading Order (fast onboarding)
1. `docs/HEELKAWN_PROJECT_COMPASS.md` — truth hierarchy + what’s next, and what not to trust.
2. `docs/HEELKAWN_BLUEPRINT.md` — immutable design laws (determinism, ledger-first, meaning derived only).
3. `docs/HEELKAWN_STATE.md` — current runtime phase and immediate next tasks.
4. `docs/BUILD_INVENTORY.md` — the strict built-vs-missing reality check that answers “what else.”
5. `docs/WORLD_BIBLE/MASTER_INDEX.md` and `docs/WORLD_BIBLE/CANON_SYSTEMS_FEATURE_QUEUE.md` — how lore canon maps into system work.

## Module Reference (high-signal “where to look next”)
- `docs/BUILD_INVENTORY.md` — tells you exactly what’s implemented vs stubbed and what blocks v1.
- `autoloads/WorldMemory.gd` — ledger + event recording; anchor for everything deterministic.
- `autoloads/WorldMeaning.gd` — derived meaning; must not rewrite facts.
- `autoloads/SettlementMemory.gd`, `autoloads/SettlementPlanner.gd` — settlement lifecycle and autonomy.
- `scripts/pawn/Pawn.gd`, `scripts/pawn/PawnData.gd` — agent logic + progression TODOs.
- `autoloads/JobManager.gd` — deterministic job queue and claiming.
- `autoloads/CraftingSystem.gd` — recipes exist, material reality is missing wiring.

## Appendix: Why “put more stuff in HeelKawn” often means “wire loops together”
The repo repeatedly warns against adding isolated systems. The correct expansion pattern is:
- build a deterministic loop,
- ensure it records meaningful events to WorldMemory,
- derive meaning for player readability,
- and only then expand the content surface (combat/governance/religion) so the world remains truthful and audit-able.
