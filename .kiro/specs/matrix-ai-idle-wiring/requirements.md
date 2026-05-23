# Requirements Document

## Introduction

Two Matrix AI advisor functions already exist in `autoloads/HeelKawnianManager.gd` but are never invoked as autonomous idle actions from `scripts/pawn/HeelKawnian.gd`:

- `get_learning_target_for_pawn(pawn)` — returns a knowledge or skill gap the pawn should pursue.
- `get_preservation_choice_for_pawn(pawn)` — returns an urgent preservation action when the pawn holds at-risk knowledge (≤ 2 carriers).

This feature wires both functions into the medium-lane block of `_tick_idle()` so that idle HeelKawnians autonomously seek learning opportunities and act to preserve endangered knowledge. All behaviour must remain deterministic, tick-based, and recorded to WorldMemory. No new RNG sources are introduced; any target selection that requires a choice uses WorldRNG.

---

## Glossary

- **HeelKawnian**: An autonomous pawn node (`scripts/pawn/HeelKawnian.gd`) that owns needs, knowledge, and idle decision logic.
- **HeelKawnianManager**: The autoload singleton (`autoloads/HeelKawnianManager.gd`) that provides Matrix AI advisor functions for pawns.
- **WorldMemory**: The append-only simulation fact log autoload. All meaningful world events are recorded here.
- **WorldRNG**: The seeded, deterministic random-number generator used by all canonical simulation systems. Direct calls to `randi()` or `randf()` without a seed are forbidden.
- **Medium Lane**: The `run_medium_lane` block inside `_tick_idle()`, gated by `_is_lane_tick(now_tick, medium_lane_interval, 11)`. It runs every few ticks, staggered by pawn ID, and is the correct insertion point for non-critical autonomous actions.
- **Learning Target**: The output of `HeelKawnianManager.get_learning_target_for_pawn(pawn)` — a dictionary containing `target_knowledge_type`, `target_skill`, `reason`, and `priority`.
- **Preservation Choice**: The output of `HeelKawnianManager.get_preservation_choice_for_pawn(pawn)` — a dictionary containing `action` (`"teach"`, `"inscribe_stone"`, or `"write_book"`), `knowledge_type`, `target_tile`, `target_pawn_id`, and `reason`.
- **At-Risk Knowledge**: A knowledge type with ≤ 2 living carriers in the settlement.
- **Survival Gate**: The condition that a pawn's hunger is above `HUNGER_EMERGENCY` and rest is above `REST_PANIC_THRESHOLD`. Actions in this feature are blocked when the gate is not satisfied.
- **APPRENTICESHIP / TEACH_SKILL**: Job types in `Job.Type` used to formalise teaching relationships.
- **CARVE_KNOWLEDGE_STONE**: Job type in `Job.Type` for inscribing knowledge on a stone tile.
- **BOOK_BINDING**: Job type in `Job.Type` for writing knowledge into a book at a library tile.
- **`_next_learning_action_tick`**: Per-pawn instance variable (int) tracking the earliest tick at which the learning bridge may fire again.
- **`_next_preservation_action_tick`**: Per-pawn instance variable (int) tracking the earliest tick at which the preservation bridge may fire again.
- **`_try_heelkawnian_learning_action()`**: New helper function added to `HeelKawnian.gd` implementing the learning bridge.
- **`_try_heelkawnian_preservation_action()`**: New helper function added to `HeelKawnian.gd` implementing the preservation bridge.
- **LIFE_EVENT**: The `WorldMemory.Kind.LIFE_EVENT` kind used when recording learning and preservation actions.

---

## Requirements

### Requirement 1: Learning Action Bridge — Idle Trigger

**User Story:** As a HeelKawnian, I want to autonomously seek learning opportunities when I am idle and my survival needs are met, so that knowledge spreads through the settlement without player intervention.

#### Acceptance Criteria

1. THE `HeelKawnian` SHALL declare instance variables `_next_learning_action_tick: int = 0` and `_next_preservation_action_tick: int = 0`.
2. THE `HeelKawnian` SHALL implement a helper function `_try_heelkawnian_learning_action() -> bool` that encapsulates all learning bridge logic.
3. THE `HeelKawnian` SHALL implement a helper function `_try_heelkawnian_preservation_action() -> bool` that encapsulates all preservation bridge logic.
4. WHEN the medium lane runs in `_tick_idle()`, THE `HeelKawnian` SHALL call `_try_heelkawnian_preservation_action()` before `_try_heelkawnian_learning_action()`, so that preservation of at-risk knowledge takes priority over general learning ambition.
5. WHEN `_try_heelkawnian_preservation_action()` returns `true`, THE `HeelKawnian` SHALL not call `_try_heelkawnian_learning_action()` in the same medium-lane tick.

---

### Requirement 2: Learning Action Bridge — Survival Gate

**User Story:** As a HeelKawnian, I want learning actions to be suppressed when I am starving or exhausted, so that survival always takes precedence over self-improvement.

#### Acceptance Criteria

1. WHEN `_try_heelkawnian_learning_action()` is called and `data.hunger` is strictly below `HUNGER_EMERGENCY`, THE `HeelKawnian` SHALL return `false` without posting any job or recording any event.
2. WHEN `_try_heelkawnian_learning_action()` is called and `data.hunger` equals `HUNGER_EMERGENCY`, THE `HeelKawnian` SHALL return `false` without posting any job or recording any event, treating the threshold value itself as an emergency state.
3. WHEN `_try_heelkawnian_learning_action()` is called and `data.rest` is at or below `REST_PANIC_THRESHOLD`, THE `HeelKawnian` SHALL return `false` without posting any job or recording any event.
4. WHEN `_try_heelkawnian_learning_action()` is called and `GameManager.tick_count` is less than `_next_learning_action_tick`, THE `HeelKawnian` SHALL return `false` without calling `HeelKawnianManager.get_learning_target_for_pawn`, blocking all job posting and event recording for that call.

---

### Requirement 3: Learning Action Bridge — Target Resolution and Job Dispatch

**User Story:** As a HeelKawnian, I want to seek a teacher or claim a teaching job when the Matrix AI identifies a learning target, so that knowledge gaps are filled through in-world interaction.

#### Acceptance Criteria

1. WHEN `_try_heelkawnian_learning_action()` is called, survival gates pass, and the cooldown has elapsed, THE `HeelKawnian` SHALL call `HeelKawnianManager.get_learning_target_for_pawn(self)` exactly once.
2. IF `get_learning_target_for_pawn` returns an empty dictionary, THEN THE `HeelKawnian` SHALL return `false` and SHALL NOT update `_next_learning_action_tick`.
3. WHEN a valid Learning Target is returned with a non-negative `target_knowledge_type`, THE `HeelKawnian` SHALL search for a nearby pawn who knows that knowledge type and is able to teach.
4. WHEN a suitable teacher pawn is found, THE `HeelKawnian` SHALL call `autonomy_draft_goto` with purpose `"learning_seek"` and the teacher's pawn ID, then return `true`.
5. WHEN no suitable teacher pawn is found nearby, THE `HeelKawnian` SHALL attempt to claim an open `APPRENTICESHIP` or `TEACH_SKILL` job from `JobManager` that matches the target knowledge type.
6. WHEN a valid Learning Target is returned with only a non-negative `target_skill` (and `target_knowledge_type` is -1), THE `HeelKawnian` SHALL attempt to claim an open `APPRENTICESHIP` or `TEACH_SKILL` job from `JobManager`.
7. IF no teacher and no matching job are found, THEN THE `HeelKawnian` SHALL return `false`.
8. WHEN `_try_heelkawnian_learning_action()` returns `true`, THE `HeelKawnian` SHALL set `_next_learning_action_tick` to `GameManager.tick_count` plus a deterministic cooldown interval derived from the pawn's ID using `posmod(int(data.id), LEARNING_ACTION_COOLDOWN_VARIANCE) + LEARNING_ACTION_COOLDOWN_BASE`, where both constants are tick-based integers defined in `HeelKawnian.gd`.
9. WHEN `_try_heelkawnian_learning_action()` returns `false` after a failed search (teacher and job both absent), THE `HeelKawnian` SHALL set `_next_learning_action_tick` to `GameManager.tick_count` plus a shorter retry interval so the pawn does not re-query every medium-lane tick.

---

### Requirement 4: Learning Action Bridge — WorldMemory Recording

**User Story:** As a simulation historian, I want every autonomous learning action to be recorded in WorldMemory, so that the fact log reflects how knowledge spreads through the population.

#### Acceptance Criteria

1. WHEN `_try_heelkawnian_learning_action()` dispatches a learning action (teacher walk or job claim), THE `HeelKawnian` SHALL call `WorldMemory.record_event` with a dictionary containing at minimum: `"kind": WorldMemory.Kind.LIFE_EVENT`, `"type": "learning_action_started"`, `"pawn_id": int(data.id)`, `"tick": GameManager.tick_count`, `"knowledge_type": target_knowledge_type`, `"reason": reason` (from the Learning Target).
2. THE `HeelKawnian` SHALL NOT record a WorldMemory event when `_try_heelkawnian_learning_action()` returns `false`.

---

### Requirement 5: Preservation Action Bridge — Survival Gate

**User Story:** As a HeelKawnian, I want preservation actions to be suppressed when I am starving or exhausted, so that my own survival takes precedence even over urgent knowledge preservation.

#### Acceptance Criteria

1. WHEN `_try_heelkawnian_preservation_action()` is called and `data.hunger` is at or below `HUNGER_EMERGENCY`, THE `HeelKawnian` SHALL return `false` without posting any job or recording any event.
2. WHEN `_try_heelkawnian_preservation_action()` is called and `data.rest` is at or below `REST_PANIC_THRESHOLD`, THE `HeelKawnian` SHALL return `false` without posting any job or recording any event.
3. WHEN `_try_heelkawnian_preservation_action()` is called and `GameManager.tick_count` is less than `_next_preservation_action_tick`, THE `HeelKawnian` SHALL return `false` without calling `HeelKawnianManager.get_preservation_choice_for_pawn`.

---

### Requirement 6: Preservation Action Bridge — Choice Resolution and Dispatch

**User Story:** As a HeelKawnian who holds endangered knowledge, I want to autonomously teach, inscribe, or write that knowledge when idle, so that it is not lost when I die.

#### Acceptance Criteria

1. WHEN `_try_heelkawnian_preservation_action()` is called and survival gates pass and the cooldown has elapsed, THE `HeelKawnian` SHALL call `HeelKawnianManager.get_preservation_choice_for_pawn(self)` exactly once.
2. IF `get_preservation_choice_for_pawn` returns an empty dictionary, THEN THE `HeelKawnian` SHALL return `false` and SHALL NOT update `_next_preservation_action_tick`.
3. WHEN the Preservation Choice has `action == "teach"` and `target_pawn_id >= 0`, THE `HeelKawnian` SHALL locate the target pawn by ID and call `autonomy_draft_goto` with purpose `"preservation_teach"` and the target pawn ID, then return `true`.
4. WHEN the Preservation Choice has `action == "inscribe_stone"` and `target_tile` is a valid tile (x >= 0), THE `HeelKawnian` SHALL post a `CARVE_KNOWLEDGE_STONE` job at `target_tile` via `JobManager` and immediately claim it, then return `true`.
5. WHEN the Preservation Choice has `action == "write_book"` and `target_tile` is a valid tile (x >= 0), THE `HeelKawnian` SHALL post a `BOOK_BINDING` job at `target_tile` via `JobManager` and immediately claim it, then return `true`.
6. WHEN the target pawn for a `"teach"` action cannot be found or is no longer valid, THE `HeelKawnian` SHALL return `false` without posting a job.
7. WHEN a `CARVE_KNOWLEDGE_STONE` or `BOOK_BINDING` job cannot be posted (e.g. `JobManager.post` returns null), THE `HeelKawnian` SHALL return `false`.
8. WHEN `_try_heelkawnian_preservation_action()` returns `true`, THE `HeelKawnian` SHALL set `_next_preservation_action_tick` to `GameManager.tick_count` plus a deterministic cooldown interval derived from the pawn's ID using `posmod(int(data.id), PRESERVATION_ACTION_COOLDOWN_VARIANCE) + PRESERVATION_ACTION_COOLDOWN_BASE`, where both constants are tick-based integers defined in `HeelKawnian.gd`.
9. WHEN `_try_heelkawnian_preservation_action()` returns `false` after a failed dispatch (target invalid or job post failed), THE `HeelKawnian` SHALL set `_next_preservation_action_tick` to `GameManager.tick_count` plus a shorter retry interval.

---

### Requirement 7: Preservation Action Bridge — WorldMemory Recording

**User Story:** As a simulation historian, I want every autonomous preservation action to be recorded in WorldMemory, so that the fact log captures how the settlement responds to knowledge loss risk.

#### Acceptance Criteria

1. WHEN `_try_heelkawnian_preservation_action()` dispatches a preservation action, THE `HeelKawnian` SHALL call `WorldMemory.record_event` with a dictionary containing at minimum: `"kind": WorldMemory.Kind.LIFE_EVENT`, `"type": "preservation_action_started"`, `"pawn_id": int(data.id)`, `"tick": GameManager.tick_count`, `"knowledge_type": knowledge_type` (from the Preservation Choice), `"preservation_action": action` (from the Preservation Choice), `"reason": reason` (from the Preservation Choice).
2. THE `HeelKawnian` SHALL NOT record a WorldMemory event when `_try_heelkawnian_preservation_action()` returns `false`, including when no preservation action was dispatched due to an invalid target, a failed job post, or any other reason that prevents an actual preservation action from occurring.

---

### Requirement 8: Determinism

**User Story:** As a simulation architect, I want all new idle-bridge behaviour to be fully deterministic and tick-based, so that replays from the same seed produce identical histories.

#### Acceptance Criteria

1. THE `HeelKawnian` SHALL NOT call `randi()`, `randf()`, or any unseeded random function inside `_try_heelkawnian_learning_action()` or `_try_heelkawnian_preservation_action()`.
2. WHEN any target selection within the learning or preservation bridges requires a random choice among equally-scored candidates, THE `HeelKawnian` SHALL use `WorldRNG` with a deterministic seed derived from `GameManager.tick_count` and `int(data.id)`.
3. THE `HeelKawnian` SHALL derive all cooldown intervals from tick-based integer constants and `posmod(int(data.id), …)` staggering, with no wall-clock time or frame-delta involvement. IF `GameManager` is null or `GameManager.tick_count` is unavailable, THE `HeelKawnian` SHALL fall back to wall-clock time for cooldown tracking rather than blocking the action entirely.
4. THE `HeelKawnian` SHALL NOT read or write any UI state as a condition or side-effect of the learning or preservation bridges.

---

### Requirement 9: Medium-Lane Integration and Ordering

**User Story:** As a simulation architect, I want the new bridges to follow the existing medium-lane pattern exactly, so that idle-tick cost remains bounded and the priority chain is respected.

#### Acceptance Criteria

1. WHEN `run_medium_lane` is `false`, THE `HeelKawnian` SHALL NOT call `_try_heelkawnian_preservation_action()` or `_try_heelkawnian_learning_action()`.
2. THE `HeelKawnian` SHALL call `_try_heelkawnian_preservation_action()` after `_try_heelkawnian_matrix_ambition_seed()` and before any lower-priority idle actions in the medium-lane block.
3. THE `HeelKawnian` SHALL call `_try_heelkawnian_learning_action()` after `_try_heelkawnian_preservation_action()` in the medium-lane block.
4. WHEN `_try_heelkawnian_preservation_action()` returns `true`, THE `HeelKawnian` SHALL return from `_tick_idle()` immediately, consistent with the early-return pattern used by `_try_heelkawnian_matrix_social_action()`.
5. WHEN `_try_heelkawnian_preservation_action()` returns `false`, THE `HeelKawnian` SHALL also return from `_tick_idle()` immediately without processing further medium-lane actions in that tick.
6. WHEN `_try_heelkawnian_learning_action()` returns `true`, THE `HeelKawnian` SHALL return from `_tick_idle()` immediately.
7. THE `HeelKawnian` SHALL stagger medium-lane calls using `posmod(GameManager.tick_count + int(data.id) * N, M) == 0` guards inside each helper, consistent with the pattern used by `_try_heelkawnian_matrix_social_action()`, so that not all pawns query the Matrix AI on the same tick.

---

### Requirement 10: No Duplicate Job Posting

**User Story:** As a simulation architect, I want the bridges to avoid posting redundant jobs, so that the job queue is not flooded with duplicate teaching or inscription tasks.

#### Acceptance Criteria

1. WHEN `_try_heelkawnian_learning_action()` would post or claim a job, THE `HeelKawnian` SHALL first check whether an open `APPRENTICESHIP` or `TEACH_SKILL` job for the same knowledge type already exists in `JobManager` and is claimable by this pawn; IF such a job exists, THE `HeelKawnian` SHALL claim the existing job rather than posting a new one.
2. WHEN `_try_heelkawnian_preservation_action()` would post a `CARVE_KNOWLEDGE_STONE` or `BOOK_BINDING` job, THE `HeelKawnian` SHALL first check whether an open job of that type at the same target tile already exists in `JobManager`; IF such a job exists, THE `HeelKawnian` SHALL claim the existing job rather than posting a new one.
