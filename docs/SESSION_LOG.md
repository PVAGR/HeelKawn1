# HEELKAWN SESSION LOG

Use this file as cross-LLM handoff memory.
Each session adds one entry at the top.

---

## 2026-04-25 - Wildlife QoL pass (no-feature-removal balancing)

Date: 2026-04-25
Agent/Model: Codex (Cursor)
Goal: Keep hunting/animal systems intact while preventing repeated wildlife collapse.

Changes made:
- Updated `scripts/pawn/Animal.gd` for survival-first behavior:
  - Reduced species hunger decay (rabbit/deer).
  - Increased passive grazing gain.
  - Added hungry-state action bias so animals prioritize foraging before wandering.
- Updated `scenes/main/Main.gd` hunting pressure logic:
  - Added species wildlife reserve floors (`MIN_RABBIT_RESERVE`, `MIN_DEER_RESERVE`).
  - Added reserve-aware dynamic hunt posting for live animals.
  - Reduced initial/one-shot wildlife hunt seeding caps to dynamic budget limits.

Decisions:
- Preserve all existing systems (hunting, regrowth, dynamic wildlife) and rebalance instead of disabling features.
- Favor sustained ecosystem behavior over short-term meat overproduction.

Open questions:
- Should reserve floors scale with map size / colony population instead of fixed constants?

Next concrete step:
- Add simple HUD debug counters for live rabbit/deer counts and posted HUNT jobs per pass.

Files touched:
- scripts/pawn/Animal.gd
- scenes/main/Main.gd
- docs/SESSION_LOG.md

---

## 2026-04-25 - Emergency anti-lag stabilization pass

Date: 2026-04-25
Agent/Model: Codex (Cursor)
Goal: Stop severe hitch/freeze cycles reported during normal and high-speed runtime.

Changes made:
- Added accumulator backlog clamp in `autoloads/GameManager.gd`:
  - New `MAX_ACCUMULATED_TICKS` cap prevents runaway catch-up storms after a hitch.
- Added high-speed throttling for heavy planners in `scenes/main/Main.gd`:
  - `SettlementPlanner.plan` + `TradePlanner.plan`: every 2 ticks at 6x, every 4 ticks at 12x.
  - `SettlementRebirth.process`: every 3 ticks at 6x, every 6 ticks at 12x.
- Tightened log gate in `autoloads/GameManager.gd` so verbose logs are only controlled by the local constant (no implicit debug-build logging).

Decisions:
- Prefer stable frame pacing over full catch-up during transient stalls.
- Keep deterministic ordering while reducing frequency of expensive non-critical passes at fast-forward speeds.

Open questions:
- Should planner intervals become user-configurable in the debug HUD for quick tuning?

Next concrete step:
- Add per-system tick-time counters in `Main._on_game_tick` to identify the top remaining hitch source.

Files touched:
- autoloads/GameManager.gd
- scenes/main/Main.gd
- docs/SESSION_LOG.md

---

## 2026-04-25 - Wildlife survival rebalance + hunt pressure control

Date: 2026-04-25
Agent/Model: Codex (Cursor)
Goal: Stop early mass wildlife die-off and reduce freeze spikes around haul/hunt churn.

Changes made:
- Rebalanced animal hunger in `scripts/pawn/Animal.gd`:
  - Added species-specific hunger decay (`rabbit 0.12`, `deer 0.09`) instead of a hard `0.5` per tick.
  - Added passive grazing gain on plains/forest when no forage node is present.
- Reduced hunt pressure in `scenes/main/Main.gd`:
  - Added meat stock soft-cap gate before posting more hunt jobs.
  - Added dynamic per-pass hunt budget based on live animal count (plus tighter cap at ultra speed).
- Fixed remaining unconditional pawn build logs in `scripts/pawn/Pawn.gd` so verbose flag is consistently respected.

Decisions:
- Keep hunting active but bounded; avoid queue flooding and full-herd wipeouts.
- Prioritize smoother fast-forward behavior while preserving deterministic simulation rules.

Open questions:
- Should we expose hunt pressure (meat soft-cap, budget divisor) as debug sliders in the HUD?

Next concrete step:
- Add debug counters for per-tick posted/cancelled HUNT jobs and failed haul-path retries to validate stability over long runs.

Files touched:
- scripts/pawn/Animal.gd
- scenes/main/Main.gd
- scripts/pawn/Pawn.gd
- docs/SESSION_LOG.md

---

## 2026-04-25 - Haul freeze mitigation during fast-forward

Date: 2026-04-25
Agent/Model: Codex (Cursor)
Goal: Reduce long stalls seen after haul path-selection messages (e.g. Quinn hauling Meat).

Changes made:
- Updated pawn path selection in `scripts/pawn/Pawn.gd` so high-speed simulation (`>= 6x`) uses regular pathfinding instead of per-call historic-aversion path weighting.
- Added short haul retry cooldown in `scripts/pawn/Pawn.gd` (`HAUL_RETRY_COOLDOWN_TICKS`) so unreachable haul targets do not trigger repeated immediate re-path attempts every tick.

Decisions:
- Keep lower-speed behavior unchanged (historic aversion still active below the high-speed threshold).
- Prioritize frame stability during fast-forward over nuanced scar-avoidance route preferences.

Open questions:
- If we still see freezes, should we move all heavy weighted path requests to a per-tick budget queue in `Main`?

Next concrete step:
- Add pathfinding timing counters (debug-only) around pawn haul/work/eat route calls to identify any remaining outlier spikes.

Files touched:
- scripts/pawn/Pawn.gd
- docs/SESSION_LOG.md

---

## 2026-04-25 - 12x speed stutter reduction (hot-path + warning cleanup)

Date: 2026-04-25
Agent/Model: Codex (Cursor)
Goal: Reduce freeze/stutter bursts at 12x sim speed and lower debugger warning noise.

Changes made:
- Reduced expensive live-animal hunt job scan cadence at ultra speed in `scenes/main/Main.gd`:
  - normal speed: every 10 ticks
  - 12x speed: every 30 ticks
- Wrapped remaining high-frequency pawn debug logs behind `GameManager.verbose_logs()` in `scripts/pawn/Pawn.gd` (haul/deposit/failure/death/threshold/hazard and related spam points).
- Fixed static call warning source by making `WorldMemory._region_key` instance-bound in `autoloads/WorldMemory.gd`.
- Fixed narrowing warnings in `autoloads/SettlementPlanner.gd` by using explicit int casts for age-derived adjustments.

Decisions:
- Keep simulation behavior deterministic while reducing expensive non-critical work frequency at 12x.
- Prioritize runtime smoothness and editor usability over verbose per-action console traces.

Open questions:
- Should we add a dedicated "performance mode" toggle that temporarily disables additional non-critical planners at 12x+?

Next concrete step:
- Profile `Main._on_game_tick` branches in a heavy population save and bucket non-essential updates across alternating tick groups.

Files touched:
- scenes/main/Main.gd
- scripts/pawn/Pawn.gd
- autoloads/WorldMemory.gd
- autoloads/SettlementPlanner.gd
- docs/SESSION_LOG.md

---

## 2026-04-25 - Debug log throttling for smoother editor runtime

Date: 2026-04-25
Agent/Model: Codex (Cursor)
Goal: Reduce run-time stutter caused by heavy console spam during simulation.

Changes made:
- Added global verbose logging switch in `autoloads/GameManager.gd` (`VERBOSE_SIM_LOGS`, default false).
- Wrapped noisy hot-path logs behind `GameManager.verbose_logs()` in:
  - `scripts/pawn/Pawn.gd`
  - `scripts/pawn/Animal.gd`
  - `scripts/pawn/PawnSpawner.gd`
  - `scripts/pawn/AnimalSpawner.gd`

Decisions:
- Keep important behavior unchanged; only suppress spam logs by default.
- Leave verbose tracing available with a single toggle.

Open questions:
- Should we expose verbose toggle via HUD/debug hotkey instead of code constant?

Next concrete step:
- Clean static-call warnings (`STATIC_CALLED_ON_INSTANCE`) to reduce editor warning load.

Files touched:
- autoloads/GameManager.gd
- scripts/pawn/Pawn.gd
- scripts/pawn/Animal.gd
- scripts/pawn/PawnSpawner.gd
- scripts/pawn/AnimalSpawner.gd
- docs/SESSION_LOG.md

---

## 2026-04-25 - Tick smoothing pass (frame spike guard)

Date: 2026-04-25
Agent/Model: Codex (Cursor)
Goal: Reduce gameplay stutter when simulation runs at high speed.

Changes made:
- Added `MAX_TICKS_PER_FRAME` guard in `autoloads/GameManager.gd`.
- Updated tick loop to process at most 6 ticks per rendered frame.
- Kept deterministic tick order and existing speed model intact.

Decisions:
- Prefer smooth frame pacing over aggressive single-frame catch-up bursts.

Open questions:
- Should we expose max ticks/frame as a player setting in UI for low-end machines?

Next concrete step:
- Profile `Main._on_game_tick` heavy branches and add optional staggered update buckets.

Files touched:
- autoloads/GameManager.gd
- docs/SESSION_LOG.md

---

## 2026-04-25 - Safe runtime wiring for imported memory systems

Date: 2026-04-25
Agent/Model: Codex (Cursor)
Goal: Activate imported systems in low-risk path so testing covers merged content.

Changes made:
- Registered new autoloads in `project.godot`: `SacredMemory`, `ChronicleLog`, `WorldClock`.
- Wired sacred-site sync into world-derivative recompute flow in `scenes/main/Main.gd`.
- Added `sacred` and `chronicle` persistence fields to save/load payload in `scenes/main/Main.gd`.
- Added explicit clear/reset for sacred/chronicle state on reroll/load prep.

Decisions:
- Integrate only safe deterministic memory systems first; defer high-risk social migration managers until APIs are aligned.

Open questions:
- Should sacred-site state drive immediate visual overlays, or remain a logic-only layer for now?

Next concrete step:
- Add first ChronicleLog producers from existing deterministic events (settlement collapse/revival markers).

Files touched:
- project.godot
- scenes/main/Main.gd
- docs/SESSION_LOG.md

---

## 2026-04-25 - Legacy project import and stabilization

Date: 2026-04-25
Agent/Model: Codex (Cursor)
Goal: Merge richer non-git OneDrive project into GitHub repo and keep runtime safe.

Changes made:
- Synced old project content from OneDrive into repo (addons/assets/resources/new systems).
- Kept git safety by excluding `.git`, `.godot`, `.cursor`, and `.sixth` folders.
- Fixed imported scripts using nonexistent `GameManager.sim_tick` to `GameManager.tick_count`.
- Removed leaked addon secret config and replaced with `config.example.cfg`.
- Added ignore rule for local addon secret config in `.gitignore`.

Decisions:
- Import all useful content first, then integrate runtime systems in controlled slices.
- Do not commit real API keys or local secret config files.

Open questions:
- Which imported addon/plugin folders should remain part of the game repo versus dev-only tooling?

Next concrete step:
- Validate imported runtime scripts in-editor and integrate new systems one at a time (Chronicle/Sacred/Fragmentation path).

Files touched:
- .gitignore
- autoloads/ChronicleLog.gd
- scripts/kernel/history_compressor.gd
- scripts/kernel/settlement_persistence.gd
- addons/godotassistant/config.example.cfg
- docs/SESSION_LOG.md

---

## 2026-04-25 - Settlement style expression pass

Date: 2026-04-25
Agent/Model: Codex (Cursor)
Goal: Advance Phase 4 identity target with deeper non-text settlement expression.

Changes made:
- Added public culture helpers to `autoloads/SettlementPlanner.gd` (`get_culture_type_for_settlement`, `get_culture_name_for_settlement`, `get_culture_audio_bias_for_settlement`).
- Wired settlement style into ambient generation in `scenes/main/Main.gd` with subtle deterministic bias (open vs defensive tonal shift).
- Added `docs/WORLD_BIBLE/GAME_VISION.md` to preserve long-horizon design direction.

Decisions:
- Keep expression subtle and non-intrusive (no text overlays, no gameplay stat changes).
- Derive style strictly from existing deterministic settlement data.

Open questions:
- Should style also influence architectural material palettes (future visual pass) or remain behavior/audio only?

Next concrete step:
- Add deterministic architectural palette/rule variants per style (open/cautious/defensive) beyond current placement order differences.

Files touched:
- autoloads/SettlementPlanner.gd
- autoloads/SettlementMemory.gd
- scenes/main/Main.gd
- docs/WORLD_BIBLE/GAME_VISION.md
- docs/WORLD_BIBLE/MASTER_INDEX.md
- docs/SESSION_LOG.md

---

## 2026-04-25 - Cross-LLM continuity baseline

Date: 2026-04-25
Agent/Model: Codex (Cursor)
Goal: Stop rebuild loops and establish stable memory/canon workflow.

Changes made:
- Expanded `docs/LLM_ONBOARDING.md` with free-forever stack and required session workflow.
- Created `docs/WORLD_BIBLE/` with index, timeline, regions, factions, characters, glossary, and canon changelog.
- Updated `README.md` to point to continuity docs.

Decisions:
- Repo files are the memory system; chat threads are temporary.
- Canon changes must be tracked explicitly.

Open questions:
- Which first culture/architecture style should be treated as canonical seed?

Next concrete step:
- Implement first cultural architecture pass in code and mirror outcomes in world bible files.

Files touched:
- README.md
- docs/LLM_ONBOARDING.md
- docs/SESSION_LOG.md
- docs/WORLD_BIBLE/*

---

## SESSION TEMPLATE

Date:
Agent/Model:
Goal:

Changes made:
- 

Decisions:
- 

Open questions:
- 

Next concrete step:
- 

Files touched:
- 
