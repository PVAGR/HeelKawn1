# HeelKawn — Runtime Truth Pass Checklist

**Purpose:** AI cannot run the Godot editor. This checklist tells the human exactly what to verify when the project is opened.

**Godot Version:** 4.6.2.stable
**Last Updated:** May 21, 2026
**Phase:** Consolidation + Phase 5A indefinite evolution foundation

> **How to use:** Open each section in the Godot editor. Check off items as you verify them. Note any failures in the "Issues Found" section at the bottom.

---

## Section 1: Pre-flight

> Run these before doing anything else. If pre-flight fails, stop and fix first.

- [ ] Godot 4.6.2.stable is installed and selected as the editor
- [ ] Project opens without import errors in the Output panel
- [ ] Output panel shows **no red errors** on first load (warnings are OK, errors are not)
- [ ] Headless smoke test passes:
  ```
  godot --headless --quit
  ```
  Exit code should be 0. No script parse errors in console output.
- [ ] All autoloads are registered in `project.godot` under `[autoload]`
- [ ] No circular dependency warnings in Output

**If pre-flight fails:** Check `docs/HEELKAWN_STATE.md` for known blockers. The most common failure point is `ProceduresPawnVisualizer.gd` — if it's missing or misnamed, `Pawn.gd` will cascade-fail.

---

## Section 2: F10 Diagnostic Panels

> Press **F10** in-game to open the debug feature menu. Cycle through each panel. Each should render text without errors in the Output panel.

- [ ] **#03B · Civilization Stage** — shows era name, score, and breakdown (tech_diffusion, literacy_rate, lifespan, institutions)
- [ ] **#35 · Backbone / first-play** — prints `LIVE` vs `DEFERRED` status line
- [ ] **#36 · Chronicle Summary** — shows a readable chronicle of world events
- [ ] **#40 · Grudge System** — lists active grudges between pawns
- [ ] **#41 · Gossip & Reputation** — shows gossip chains and reputation values
- [ ] **#42 · Avoidance AI** — displays avoidance behavior state
- [ ] **#43 · Pawn Narratives** — shows narrative text for sampled pawns
- [ ] **#44 · Knowledge System (18 types)** — lists knowledge types and carrier counts
- [ ] **#45 · Myth Formation** — shows myths that have formed in settlements
- [ ] **#46 · Knowledge Stones** — lists inscribed stones and their knowledge
- [ ] **#49 · HeelKawnians** — shows sample development profiles with Matrix job pulls, rationale, learning targets, and preservation choices
- [ ] **#70 · Legacy System** — shows legacy entries and dynasty data
- [ ] **#71 · Chronicle View** — detailed chronicle timeline
- [ ] **#72 · Settlement Legends** — shows legends tied to settlements
- [ ] **#74 · Dynasty Tree** — visualizes family/generational lines
- [ ] **#75 · Legacy Milestones** — shows milestone progress (not final victory)
- [ ] **#81 · Save Chronicle (NEW)** — triggers chronicle save to `user://`
- [ ] **#82 · Save World Seed (NEW)** — triggers world seed save to `user://`

**What to look for:**
- Panel text renders (not blank, not `null`)
- No red errors in Output when switching panels
- Numbers are non-zero where expected (pawn counts, knowledge carriers, etc.)
- No `Invalid get index` or `Attempt to call function on null` errors

---

## Section 3: HUD Verification

> Look at the main HUD overlay during gameplay.

- [ ] **Identity strip** shows the current civilization stage name (e.g., "Stone Age", "Bronze Age")
- [ ] **Colony line** shows F/H/W/S/K/L pressure indicators (Food, Housing, Workforce, Storage, Knowledge, Legacy)
- [ ] **Pawn count** displayed is accurate (count visible sprites vs. HUD number)
- [ ] **Simulation speed indicator** works — press keys `1` through `7` and verify speed changes
- [ ] **Pause/resume** works — press `Space` and verify simulation stops/starts
- [ ] HUD does not flicker or overlap other UI elements
- [ ] Event notifications appear for significant events (births, deaths, discoveries)

---

## Section 4: Pawn Behavior

> Let the simulation run for at least 2-3 minutes at 1x speed. Watch pawn behavior.

- [ ] Pawns **spawn** at game start (default 20)
- [ ] Pawns **move** toward job sites (not standing still indefinitely)
- [ ] Pawns **claim jobs** from JobManager (builders build, gatherers gather, etc.)
- [ ] Pawns **eat** when hungry (hunger need drives behavior)
- [ ] Pawns **sleep** when tired (fatigue need drives behavior)
- [ ] **Matrix AI job biases** are visible in F10 #49 — pawns show biased job preferences based on their HeelKawnian profile
- [ ] **Social intent** triggers — look for `social_seek` or `teach_seek` in F10 #49 or pawn narrative tab
- [ ] **Settlement ambition** posts jobs — settlements should post build jobs for hearth, storage, beds, walls, marker stone, etc.
- [ ] Profession diversity is visible (not all pawns doing the same job)
- [ ] Pawns can **reassign professions** when a non-primary skill outpaces their current role

**Red flags:**
- All pawns idle with no jobs
- Pawns stuck in one profession forever
- No social interactions after 5+ minutes
- Settlements never post build jobs

---

## Section 5: Knowledge System

> Test knowledge flow end-to-end.

- [ ] **Knowledge carriers are tracked** — F10 #44 shows which pawns carry which knowledge types
- [ ] **Teaching works** between pawns — a knowledgeable pawn teaches another (check F10 #44 carrier count increases)
- [ ] **Knowledge stones can be inscribed** — a scholar pawn inscribes knowledge, a blue stone spawns at the site
- [ ] **Knowledge stones can be read** — right-click a stone, a read dialog opens, another pawn learns the knowledge
- [ ] **Book crafting works** — check CraftingSystem for book recipes (Paper, Leather, Ink, Pen, Book)
- [ ] **Knowledge loss events fire** when the last carrier of a knowledge type dies (check F10 #44 for knowledge disappearing)
- [ ] Knowledge types display correctly (18 types in F10 #44)
- [ ] `WorldRNG` is used for deterministic rediscovery checks (not `randi()`)

---

## Section 6: Settlement Lifecycle

> Watch settlements form and evolve over 5+ minutes of simulation.

- [ ] **Settlements form** from proto-sites when conditions are met
- [ ] Settlements show correct lifecycle state:
  - `active` — pawns present, infrastructure being built
  - `abandoned` — no pawns, below revival threshold
  - `reviving` — a pawn entered or stockpile food rose above 10 units
  - `permanent_ruin` — 60000+ ticks empty and below revival food threshold
- [ ] **SettlementPlanner** posts build jobs (visible in job queue and F10 panels)
- [ ] **ColonySimServices** pressures are accurate — F/H/W/S/K/L values reflect actual settlement state
- [ ] Region tint path reflects settlement lifecycle state visually on the map
- [ ] `BUILD_INTENT_COOLDOWN_TICKS` (1200) prevents build intent spam

---

## Section 7: New Features to Verify

> These are the Phase 5A features added most recently. Verify each individually.

- [ ] **F10 #81 saves chronicle to `user://`** — press the button, then check `user://` directory for the saved chronicle file
- [ ] **F10 #82 saves world seed to `user://`** — press the button, then check `user://` directory for the saved seed file
- [ ] **FactionRegistry** shows houses and relations in debug output
- [ ] **CivilizationStage snapshot** includes `tech_diffusion`, `literacy_rate`, `lifespan`, `institutions` fields
- [ ] **HeelKawnianManager learning targets** work — visible in F10 #49 as suggested learning paths for sampled pawns
- [ ] **HeelKawnianManager preservation choices** work — visible in F10 #49 as preservation pressure indicators
- [ ] **Recovery behavior** chains through 5 phases (pawn recovery from disaster/trauma)
- [ ] **Skill branch choices** are visible in the pawn inspect panel
- [ ] **Knowledge inheritance** is visible in child pawns (children start with some knowledge from parents)
- [ ] **CraftingSystem tool requirements** are visible — recipes show required tools
- [ ] **Knowledge preservation state** is visible — stones and books show their preservation status
- [ ] **Mode contract enforcement** works:
  - `WATCH` mode: cannot interact with world command/edit input
  - `INCARNATED` mode: embodied sprite play (not full-command)
  - `OBSERVER` mode: sole full edit/command authority
- [ ] **AIAutoBuild need gates** work — shelter/storage intents only fire when ColonySimServices pressure thresholds are met
- [ ] **Matrix Settlement Ambition Seeding** works — throttled ambition posts visible in F10 #49 and job queue
- [ ] **Need-driven build gating** works — SettlementPlanner gates bed, fire pit, storage hut, farm planner posts from pressure signals

---

## Section 8: Performance

> Run the simulation at different speeds and monitor.

- [ ] Game runs at **1x** without stutter (target: 80-100 FPS)
- [ ] Game runs at **26x** without freezing (target: 70-90 FPS)
- [ ] **100+ pawns** don't cause performance issues (spawn extra pawns if needed to test)
- [ ] No memory leaks after **10 minutes** of runtime (check memory usage in Godot debugger or OS task manager)
- [ ] **TickBudgetManager** coordinates the 12ms simulation budget (no single tick dominates)
- [ ] Spatial grid for social proximity is active (no O(n^2) social checks)
- [ ] Redraw throttle is working (UI doesn't redraw every frame unnecessarily)
- [ ] Meaning throttle is working (WorldMeaning doesn't recompute every tick)
- [ ] High-frequency debug logs are throttled in the main tick path

**How to test 100+ pawns:** Use the debug spawn command or let natural birth rate increase population over time. Monitor FPS in the Godot debugger's Monitor tab.

---

## Section 9: Known Issues to Watch

> These are known risks from `docs/HEELKAWN_STATE.md` and project history. Watch for them during the truth pass.

| # | Issue | Status | What to Watch |
|---|-------|--------|---------------|
| 1 | **Documentation drift** | Ongoing risk | Older docs may overstate completion vs. `BUILD_INVENTORY.md`. Trust code/runtime first. |
| 2 | **ProceduresPawnVisualizer dependency** | Resolved (May 7) | If `Pawn.gd:5785` area shows errors, check `scripts/utils/ProceduresPawnVisualizer.gd` exists and has `class_name ProceduresPawnVisualizer`. |
| 3 | **Pawn parse errors cascading** | Resolved | If JobManager or UI panels show null errors, check Pawn.gd compiles cleanly first. |
| 4 | **Profession lock bug** | Resolved | Verify pawns can change professions when non-primary skills outpace current role. |
| 5 | **Event schema gap (FoodChainManager)** | Resolved | Verify FoodChainManager events reach WorldMeaning without errors. |
| 6 | **Neural bias speed gate** | Resolved (relaxed to 200x) | Verify Matrix AI biases contribute at normal play speeds (not just 50x+). |
| 7 | **OnboardingSystem RichTextLabel** | Resolved (May 7) | Verify onboarding displays correctly on first launch (no `Label.bbcode_enabled` errors). |
| 8 | **Build intent spam** | Resolved (May 19) | Verify SettlementPlanner cooldown (1200 ticks) prevents duplicate build posts. |
| 9 | **Headless smoke after UI changes** | Needs re-verify | Last confirmed May 7. Re-run `godot --headless --quit` after any UI/system changes. |
| 10 | **Settlement lifecycle state accuracy** | New (Phase 4) | Verify active/abandoned/reviving/permanent_ruin states transition correctly. |

---

## Section 10: Issues Found

> Record any failures here during the truth pass.

| # | Section | Item | Description | Severity | Status |
|---|---------|------|-------------|----------|--------|
|   |         |      |             |          |        |
|   |         |      |             |          |        |
|   |         |      |             |          |        |

**Severity guide:**
- **Critical** — crash, data loss, game won't start
- **Major** — feature broken, incorrect behavior
- **Minor** — cosmetic issue, text overflow, minor inconvenience
- **Suggestion** — enhancement idea, not a bug

---

## Quick Reference

### Key Commands
| Key | Action |
|-----|--------|
| `F10` | Open debug feature menu |
| `1-7` | Simulation speed (1=slowest, 7=fastest) |
| `Space` | Pause/resume |
| `Click pawn` | Open pawn info panel |
| `Right-click stone` | Read knowledge stone |

### Key Files to Check on Error
| Symptom | File to Check |
|---------|---------------|
| Pawn errors cascade | `Pawn.gd`, `scripts/utils/ProceduresPawnVisualizer.gd` |
| Job system broken | `JobManager.gd`, `Job.gd` |
| F10 panels blank | `DebugFeatureMenu.gd` and individual panel scripts |
| HUD missing data | HUD overlay script, `ColonySimServices.gd` |
| Knowledge not tracking | `KnowledgeSystem.gd` |
| Settlement state wrong | `SettlementPlanner.gd`, `SettlementMemory.gd` |
| Matrix AI not working | `HeelKawnianManager.gd`, `Pawn.gd` bias consumption |
| Civilization stage wrong | `CivilizationStage.gd` |

### Godot `user://` Location (Windows)
```
C:\Users\<username>\AppData\Roaming\Godot\app_userdata\HeelKawn\
```
Check here for chronicle saves (#81) and world seed saves (#82).

---

## Sign-off

**Tester:** _______________
**Date:** _______________
**Godot Version:** _______________
**Total Time:** _______________
**Overall Status:** [ ] PASS  [ ] FAIL  [ ] PASS WITH NOTES

**Notes:**

