# F10 Diagnostics — HeelKawn AI World Snapshot System

## PURPOSE
F10 is HeelKawn's canonical world-inspection / AI bug-report system.
It provides read-only diagnostic snapshots of the simulation state for
analysis, debugging, and AI-assisted troubleshooting.

## HUMAN WORKFLOW

1. Run a game.
2. When something looks wrong, press F10.
3. Press GENERATE AI DEBUG BUNDLE.
4. Give external AI:
        screenshot.png
        world_snapshot.txt
   normally enough.
5. Use category reports only for deeper drill-down.

## MASTER SNAPSHOT SCHEMA

The AI World Snapshot produces a coherent moment-in-time report with these sections:

### header
- diagnostic_schema_version: Version of this schema (currently 1)
- title: "HEELKAWN AI WORLD SNAPSHOT"
- godot_version: Engine version string
- build: "debug" or "release"
- os: Operating system name
- fps: Current frames per second
- tick: Current simulation tick count
- year: In-game year (derived from tick)
- day: In-game day of year (derived from tick)
- elapsed_days: Days elapsed as floating point
- game_speed: Current game speed multiplier
- paused: Whether game is paused
- generated_ms: Time to generate snapshot in milliseconds

### world_view
- camera: 
  - global_position: Camera world position
  - tile: Tile coordinates under camera center
  - zoom: Camera zoom level
  - visible_bounds: Approximate visible tile bounds
- hovered_tile: Tile currently under mouse cursor
- designation_mode: Current UI designation mode (e.g., "build", "job")
- selected_pawn_entity: Information about selected pawn if any
- visual_selection_truth: Whether selection represents a valid game entity

### selected_pawn
Complete information about currently selected pawn (if any), plus:
- why: Analysis of why the pawn is exhibiting its current behavior
  - state: Current state name (e.g., "Idle", "Working")
  - hunger, carrying, can_work: Key needs and capabilities
  - Detailed reasoning based on state (job visibility, food access, etc.)

### population
- total_pawns: Total number of pawns in simulation
- by_state: Count of pawns in each state (Idle, Working, etc.)
- needs: Count of pawns with various needs (starving, tired, etc.)
- affiliation: Settlement membership counts
- life_stage: Distribution by life stage
- occupation: Distribution by occupation type
- profession_liking: Distribution by profession preference

### jobs
- open: Number of open jobs
- claimed: Number of claimed jobs
- active_union: Number of jobs in active union (claimed + in progress)
- posted: Lifetime posted jobs count
- completed: Lifetime completed jobs count
- cancelled: Lifetime cancelled jobs count
- by_type: Counts by job type (foraging, building, etc.)
- cancellation_reasons: Breakdown of why jobs were cancelled
- abandon_reasons: Breakdown of why jobs were abandoned
- oldest_open_job: Details of the oldest currently open job

### food
- stockpile_zone_count: Number of stockpile zones
- total_food: Total food units across all stockpiles
- has_any_food: Boolean indicating food availability
- inventory_totals: Breakdown by item type (wood, stone, food, etc.)
- top_items: Top 5 most abundant items
- starving_pawns: Detailed analysis of starving pawns including hunger state and food accessibility

### settlements
- formal:
  - count: Number of formal settlements
  - list: Details of each formal settlement (name, population, founding, etc.)
- proto:
  - count: Number of prototype settlement sites
  - list: Details of each proto site
- realms: count: Number of active political entities
- membership_contract: Analysis of pawn-settlement membership consistency
  - total_checked: Total pawns examined
  - ok: Pawns with correct settlement membership
  - unattached_inside: Pawns inside settlement regions but marked unattached
  - attached_outside: Pawns outside settlements but marked as attached
  - index_mismatch: Pawns with incorrect settlement indices
  - stale_index: Pawns with outdated settlement indices (normal during recompute)
  - examples: Up to 5 examples of each mismatch type

### spatial
- world: Dimensions and tile size
- camera: Center tile and zoom level
- selected_pawn_tile: Tile coordinates of selected pawn
- settlement_centers: List of formal settlement center tiles
- proto_centers: List of prototype site center tiles
- stockpile_count: Number of stockpile zones
- structure_count: Number of placed structures
- path_components: Number of disconnected pathfinding components
- ascii_slice: 21x21 ASCII art representation of world around center point

### structures_development
- total_count: Total number of structures/buildings
- by_type: Counts by structure type (if available)
- recent_constructions: Recently built structures (from WorldMemory events)

### social_culture
- households: Number of player-defined households
- factions: Number of registered factions
- caste_stats: Distribution across caste system (if applicable)
- cultural_diversity: Measure of cultural variety (0.0-1.0)
- cultural_maturity: Measure of cultural development (0.0-1.0)
- character_progression: Number of characters who have progressed

### politics
- active_conflicts: Number of active conflicts
- active_treaties: Number of active treaties
- authority_status: Current world authority state
- active_armies: Number of active military groups
- active_battles: Number of active battles
- factions: Number of registered factions
- government: Information about current world leadership (if available)

### performance
- fps: Current frames per second
- tickprofiler: Breakdown of time spent in major simulation categories (microseconds and milliseconds)
- pawn_dispatch: When enabled, detailed profiling of pawn decision-making stages
- autosave: 
  - interval_ticks: Autosave interval (6000 ticks)
  - next_autosave_tick: Next scheduled autosave tick
  - ticks_until_autosave: Ticks remaining until next autosave
  - save_files: Status of save files (existence and size)

### anomalies
Array of automatically detected contradictions or unusual conditions, each with:
- id: Unique identifier for anomaly type
- severity: "INFO", "WARNING", or "CRITICAL"
- summary: Human-readable description
- evidence: Structured data supporting the anomaly
- not_proof: Limitations of what the anomaly actually proves

### recent_changes
- total_events: Total number of world events recorded
- by_type: Count of events by type
- oldest: First 20 events in simulation
- newest: Last 100 events in simulation
- important_changes: Settlement-related events from recent history
- omitted: Number of events not included due to bounding

### generated_ms
Actual time taken to generate the snapshot in milliseconds

## ANOMALY RULES

### food_starvation_while_food_exists
- Triggers when: pawns have hunger <= HUNGER_EMERGENCY while total_food > 0
- Suggests: Food distribution or accessibility problems
- Does NOT prove: That food is actually accessible to starving pawns (may be reserved, blocked, etc.)

### settlement_member_contract_* 
Types: unattached_inside, attached_outside, index_mismatch
- Triggers when: pawn.data.settlement_id doesn't match geometric settlement assessment
- Suggests: Settlement memory inconsistency or normal recompute churn
- Does NOT prove: SettlementMemory failure (index mismatch is expected during array rebuilds)

### idle_with_open_jobs
- Triggers when: pawns in Idle state while open jobs exist
- Suggests: Potential job matching or claiming issues
- Does NOT prove: JobManager failure (pawns may lack qualifications, be blocked, etc.)

### late_no_formal_settlement
- Triggers when: no formal settlements exist after tick 18000 (~18 days)
- Suggests: Slow settlement development
- Does NOT prove: Formalization system failure (may be legitimate slow start)

### stale_open_jobs
- Triggers when: open job age exceeds 360000 ticks (~1 year)
- Suggests: Job may be impossible to complete
- Does NOT prove: Job system failure (may have legitimate unmet requirements)

### high_cancel_rate
- Triggers when: job cancellation rate exceeds 50%
- Suggests: Systemic issues with job completion
- Does NOT prove: Job system failure (may be due to changing world conditions)

### hot_dispatch_stage
- Triggers when: any pawn decision-making stage averages >5ms
- Suggests: Performance bottleneck in AI processing
- Does NOT prove: Incorrect behavior (performance issue only)

### heelkawnian_tick_hot
- Triggers when: HeelKawnian simulation uses >80% of per-tick budget
- Suggests: Approaching performance limits
- Does NOT prove: Incorrect behavior (performance issue only)

### selected_pawn_idle_no_eligible_jobs
- Triggers when: selected pawn is idle with zero visible eligible jobs
- Suggests: Selected pawn may have non-visible work options
- Does NOT prove: Selected pawn is incorrectly idle

## READ-ONLY SAFETY CONTRACT

The F10 diagnostic system guarantees:
- No simulation state is modified during snapshot generation
- No jobs are claimed, cancelled, or altered
- No food is reserved, consumed, or relocated
- No pawns are moved, have needs altered, or change states
- No settlement membership is changed
- No WorldRNG is consumed (all queries use deterministic peek-only methods)
- No autosave is triggered during snapshot generation
- No save files are modified or accessed for writing
- All data is gathered via read-only queries and canonical API methods

The diagnostic path is completely isolated from simulation mutation paths.

## PERFORMANCE

- Live display (updated every 0.5s): Designed to remain cheap (<16ms) even at 200x speed
- Expensive operations: Only occur on explicit user action (COPY, CATEGORY, BUTTON)
- Snapshot generation time: Reported in generated_ms field
- Category reports: Generate only the requested section for efficiency
- Bundle generation: Includes snapshot creation plus file I/O operations

## ADDING A NEW SYSTEM

Permanent rule:
Any new core HeelKawn system that materially changes the world must expose
enough read-only diagnostic state to appear in the F10 AI World Snapshot.

Required exposure:
1. State relevant to world simulation (counts, totals, status)
2. Membership/relationship data if applicable (for cross-system consistency checks)
3. Performance characteristics if computationally significant
4. Recent changes/events if the system generates historical data
5. Any data necessary for anomaly detection related to the system's domain

## VERSION HISTORY
- v1.0: Initial implementation with full schema as specified