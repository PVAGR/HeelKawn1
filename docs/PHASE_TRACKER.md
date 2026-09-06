# HeelKawn — Phase Tracker (0.1 → 1.0)

**Purpose:** The single living plan tracking HeelKawn from its current version (0.1, pre-1.0) toward the 1.0 release. One file to keep current. Append status as work lands; never rewrite history.

**Last Updated:** September 06, 2026
**Current Version:** **0.1** (pre-1.0, no release candidate yet)
**Working discipline:** Deterministic kernel rules (AGENTS.md) apply at every phase. "Done" means implemented + verified (parse check, regression tool, or headless/desktop run), never merely planned.

---

## How to use this file

- Update the **Current Version** line and the phase checklist at the end of every real work session.
- The detailed day-by-day work log lives in `AGENTS.md` (Progress Log). This file is the *plan*; AGENTS.md is the *record*.
- When a phase's Exit Criteria are all checked, promote it to "COMPLETE", bump the version, and return here to state the next phase's start.

---

## Version Roadmap

| Version | Meaning | Theme |
|---------|---------|-------|
| **0.1** | Current. Kernel + scheduling + diagnostics trustworthy. | Foundations & Diagnosis |
| **0.2** | High-speed parity + survival truth. | Everything works at every speed |
| **0.3** | Content depth (lineage, crafting, authority, Matrix AI). | A world, not a prototype |
| **0.4** | Player-facing meaning layer (fog of knowledge, chronicle, incarnation). | Understandable & inspectable |
| **0.5** | Hardening + full regression sweep. | Release candidate |
| **1.0** | Shipped, playtested, documented. | Release |

---

## PHASE 0.1 — Foundations & Diagnosis

**Goal:** The kernel is deterministic, the scheduler handles 1x–200x, pawns stay alive and working at every speed, and F10 *tells the truth*.

### Status summary (as of 2026-09-06)

**Live / verified (from AGENTS.md progress log):**
- Deterministic kernel: `WorldRNG` named stateless streams; tick-count + seed + inputs = world state. No unseeded RNG in sim paths.
- Authoritative world clock (`SimulationClock`) with committed/target lanes; multi-rate scheduling; single pause authority (`GameManager.is_paused`); `TickManager` owns speed + batching.
- 200× batching/coalescing (batch factor 2/4 at 100x/200x) and pawn **movement decoupled into simulation time** (tile truth committed in the sim lane; `_process` is visual-only).
- Pawn liveness at 200x: claim cadence `return 1`, expensive-decision cadence `return 1`, virtual-work cap, watchdog deadline eviction, cooldown wander.
- Mature-world hot kernels identified & reduced: neural-state cache TTL 128, job-scan memo caches, warmth-pressure hoist, arrival tolerance.
- Settlement formalization gate runs at every recompute; settlement/proto center decode is correct in F10.
- F10 snapshot is a bounded, read-only, honest diagnostic (no fabricated counters; effective speed + batch factor reported).
- Documentation consolidated (AGENTS.md 2026-08-18) and pruned of obsolete markdowns (2026-09-06).

### Exit Criteria (remaining → checked when done)

- [ ] **P4 starvation trace** — per-pawn starvation diagnostic; resolve or *prove* that the component-split food-reachability hypothesis is real vs. assumed. Only then decide whether consumption tuning is warranted (do not tune before proof).
- [ ] **P3 per-stage job-rejection counters** — job-scan gate/claim staging for idle adults; per-stage reject distribution, not just totals.
- [ ] **P5 autosave stage timing** — snapshot build / pawn / settlement / WorldMemory / AI / JSON / store / rename; measure before changing.
- [ ] **Mid-world F10 snapshot validation on the real saved colony** (user plays the save; F10 triggers a full truthful snapshot; no fabricated numbers).
- [ ] **JobManager completion counter** — decide: add real `completed_count` (gameplay-adjacent, per rules needs user sign-off) or keep "Completed: unavailable" in F10.
- [ ] **Unattributed TICK_DIAG spikes** — root-cause the ~0.4s non-autosave spikes if they still reproduce on the user's world.
- [ ] **`sim_boot_smoke.gd`** — known limitation: SceneTree `--script` never calls `_ready`, so smoke covers autoloads only, never Main. Either fix or document explicitly as non-Main coverage.
- [ ] **Version bump to 0.2** when all of the above are done.

---

## PHASE 0.2 — High-Speed Parity & Survival Truth

**Goal:** 1x, 100x, and 200x change only the observer's clock speed — not whether pawns live, work, eat, sleep, and die correctly.

### Planned work (order matters)

- [ ] **Per-pawn starvation trace conclusions** → apply the proven fix (component-split reachability, radius, or consumption) with determinism intact.
- [ ] **Settlement membership semantics** — resolve the mixed `settlement_id` (array index) vs `center_region` (key) contract documented 2026-08-29; 42 call sites, research before touching.
- [ ] **200x fidelity audit** — verify jobs/settlements/development run at the same *world-time* cadence at 200x as at 1x (post-batch-intro, with the `Effective World Speed` metric as the honest ceiling).
- [ ] **Autosave fence in code** — add a real-time autosave gate (per Permanent Tool Rule) so aged saves can never be silently overwritten by a diagnostic run.
- [ ] **Full regression set green at default speed** — `diag_parse_check`, `f10_live_data_regression`, `chronicle_contract_regression`, `sim_boot_smoke`, `diag_multirate_smoke`, `diag_highspeed_pawns`.
- [ ] **Version bump to 0.3** when survival truth holds at every speed without regression.

---

## PHASE 0.3 — Content Depth

**Goal:** Moving from "living prototype" to "a world." Systems the canonical blueprint calls for are no longer stubs.

### Areas (from compass / blueprint / TODO history)

- [ ] **Skill trees & profession progression** — deeper branches, thresholds, inheritance hooks verified in runtime.
- [ ] **Lineage & children depth** — parent lookup, child creation, inheritance fully wired and visible in UI.
- [ ] **Crafting material reality** — every recipe consumes real stockpile/inventory, requires tools where intended, depletes resources.
- [ ] **Authority / governance / faction / religion** — move beyond stubs: emergence, decay, leadership, guilds, religion lens (SacredMemory/MythMemory/DRUJ/Asha interpretation).
- [ ] **HeelKawnian Matrix AI deepening** — extend job-bias into learning targets, teaching targets, preservation choices, recovery plans, household intent, settlement ambitions.
- [ ] **Knowledge preservation loop** — stones, books, teaching, literacy, lost/rediscovered knowledge unified and verifiable in-game.
- [ ] **Civilization stage deepening** — per-settlement tech diffusion, literacy, lifespan/QoL, institutions from live state.
- [ ] **Version bump to 0.4** when a new player can understand *why* a place/pawn/faction/ruin matters without reading debug output.

---

## PHASE 0.4 — Player Meaning Layer

**Goal:** The player sees meaning, not a system dump. Fog of knowledge beats fog of war; myth vs. truth; chronicle as history.

- [ ] **Fog of knowledge** — ordinary pawns / incarnated player know only what they could know (observer retains full diagnostic view by design).
- [ ] **Observer chronicle** — follow a person, family, settlement, artifact, or civilization across history; readable exports (chronicle, world seed).
- [ ] **Myth vs. truth mechanics** — conflicting local beliefs about the same past event, surfaced in UI.
- [ ] **Incarnation mode polish** — playing one HeelKawnian without breaking the simulation's soul.
- [ ] **Visual/ambient truth** — the world looks *lived in* (aligned with `docs/HEELKAWN_VISUAL_DIRECTION.md`): grown-not-placed settlements, visible building history, war's aftermath persists.
- [ ] **Version bump to 0.5** when an hour of play produces a story a human can tell back.

---

## PHASE 0.5 — Hardening & Release Candidate

**Goal:** Nothing new ships; everything is verified, fast, and documented.

- [ ] **Performance targets** — 1x responsive; 200x ~25 in-game days / ~15,000 ticks in ≤75s without freezing.
- [ ] **Determinism regression suite** — seeded fixed-FPS replay equality across the whole regression toolset.
- [ ] **Quality gate** — run the full static + headless + desktop verification set; zero parse/script errors in the gate.
- [ ] **Export & packaging** — export settings reviewed (notepad: `docs/EXPORT_SETTINGS.md`), itch.io/release checklist, license confirmed, README final.
- [ ] **Player guide** — `docs/PLAYER_GUIDE.md` truthful to the shipped build.
- [ ] **1.0 release.** 

---

## Open items carried from AGENTS.md (still unresolved, do not lose)

- `sim_boot_smoke.gd` autoload-only limitation (does not boot Main under `--script`).
- Autosave real-time gate behavior differs between the working tree and the 2026-08-19 notes — verify on the user's real tree before trusting any autosave timing work.
- F10 formal/proto `name` renders blank/(unknown) for guild-gate settlements (cosmetic; F10 reads `name` while SettlementMemory emits none for those).
- `.aider.*`, `.godot/**`, `.letta/` and other working-tree junk — candidates for .gitignore/cleanup.

---

## Changelog

- **2026-09-06** — Created. Consolidated the pre-0.1 ad-hoc task lists (TASKS.md/TODO.md removed) into this single phase plan. Obsolete markdowns removed across the repo (docs/archive, brain/, memory/, logs/, session logs, STATE_VERIFICATION_*, AI_CODER_*, AI_README, CANONICAL_MAP). Stale doc references updated (README, STATE, BUILD_INVENTORY, COMPASS, handoff rules).