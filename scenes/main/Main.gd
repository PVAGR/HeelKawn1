extends Node2D
class_name Main

## Top-level scene controller. Owns input hotkeys and the startup / reroll (debug R)
## sequence: world -> stockpile -> pawns -> jobs. Each step depends on the
## previous, so order here matters.

const STOCKPILE_SCENE: PackedScene = preload("res://scenes/stockpile/Stockpile.tscn")
const INCARNATION_PICKER_SCRIPT: Script = preload("res://scripts/ui/IncarnationPicker.gd")
## Static `_region_key` helper lives on the script; reuse instead of per-call preload in hot paths.
const _WM = preload("res://autoloads/WorldMemory.gd")
const TRAIT_SHOP_PATH: String = "res://scripts/ui/TraitShop.gd"
const DEBUG_PANEL_PATH: String = "res://scripts/ui/DebugControlPanel.gd"

## Tuning for initial job generation.
const FORAGE_WORK_TICKS: int = 20
const MINE_WORK_TICKS: int = 40
const MINE_WALL_WORK_TICKS: int = 60   # walls are slower than loose ore
const CHOP_WORK_TICKS: int = 25
const HUNT_RABBIT_WORK_TICKS: int = 20 # quick chase + clobber; small payoff
const HUNT_DEER_WORK_TICKS:   int = 45 # bigger animal, harder to bring down
const BUILD_BED_WORK_TICKS: int = 30   # roughly the same as a mine: solid effort but not a chore
const BUILD_WALL_WORK_TICKS: int = 40  # heftier than a bed -- it's structural
const BUILD_DOOR_WORK_TICKS: int = 25  # quick, slots between two walls
# Harvest priorities. ALL EQUAL on purpose: pawns then pick the nearest job
# of any harvest type, which gives a natural mix. (Earlier I tried bumping
# MINE above the rest and it caused pawns to ignore food entirely -- they
# starved while mining stone. Don't do that again.)
# Food balance is enforced separately by the food-emergency override in
# HeelKawnian._tick_idle, which forces idle pawns onto FORAGE jobs when the
# stockpile is almost out.
const FORAGE_PRIORITY: int = 3
const MINE_PRIORITY: int = 3
const CHOP_PRIORITY: int = 3
const HUNT_PRIORITY: int = 3       # peer of forage/mine/chop -- distance breaks ties
const MINE_WALL_PRIORITY: int = 2
## Build jobs sit at the top of the harvest stack so once the player designates
## a site, pawns prioritize getting it up over yet another forage. Walls > beds
## > doors just because walls usually frame what comes next. The materials
## filter prevents pawns from claiming a build with no wood in stockpile, so
## these don't actually starve out harvest work.
const BUILD_BED_PRIORITY: int = 6
const BUILD_WALL_PRIORITY: int = 6
const BUILD_DOOR_PRIORITY: int = 6

## When player presses B, designate this many beds in a tight ring around the
## stockpile (or as many as fit before we run out of slots / scan radius).
const BEDS_PER_DESIGNATION: int = 5
## Search radius around the stockpile for bed sites. 6 -> 13x13 area.
const BED_SCAN_RADIUS: int = 6
const MAX_FORAGE_JOBS: int = 80
## Bumped from 40 alongside the new surface-ore deposits so the queue can
## actually hold them all -- otherwise the reactive seeder spends cycles
## repeatedly trying to repost.
const MAX_MINE_JOBS: int = 80
const MAX_CHOP_JOBS: int = 60
## All wildlife on the main landmass is huntable; this just caps how many we
## actually post at once so the queue stays readable.
const MAX_HUNT_JOBS: int = 50
## Runtime hunt pressure controls (v1 balance):
## - Keep some wildlife alive.
## - Avoid flooding queue/pathing when meat stock is already healthy.
const MAX_DYNAMIC_HUNT_JOBS_PER_PASS: int = 4
const HUNT_JOB_PER_ANIMALS_DIVISOR: int = 6
const HUNT_MEAT_STOCKPILE_SOFT_CAP: int = 18
const FISH_PRIORITY: int = 3
const FISH_WORK_TICKS: int = 30
const MAX_FISH_JOBS: int = 30
const FISH_COOLDOWN_TICKS: int = 300  # fish-specific respawn delay between catches
## Preserve a baseline wildlife population so hunting never hard-collapses fauna.
const MIN_RABBIT_RESERVE: int = 16
const MIN_DEER_RESERVE: int = 8
## Cap concurrent tunnels so the colony doesn't dump all its labor into rocks.
## When one finishes, the reactive seeder posts the next.
const MAX_ACTIVE_MINE_WALL_JOBS: int = 4

# -------------------- regrowth tuning --------------------
# Renewable resources: berries grow back on FERTILE_SOIL and trees grow back
# on the tiles they were chopped from. Without this the colony exhausts the
# map and starves once everything has been harvested once.
#
# 600 ticks = 60s real at 1x, 10s real at 6x = ~1 in-game day.
const FORAGE_REGROW_TICKS: int = 600
## Trees take longer (slower-growing). 1500 ticks ~ 2.5 in-game days.
const TREE_REGROW_TICKS: int = 1500
## Wildlife respawn: roughly between berries and trees. Each kill seeds a
## fresh animal of the same species back on the same tile after this delay,
## representing herd / warren repopulation rather than literal resurrection.
const RABBIT_REGROW_TICKS: int = 900
const DEER_REGROW_TICKS:   int = 1800
const AMBIENT_MIX_RATE: int = 22050
const AMBIENT_BASE_AMP: float = 0.028
## Player-readable meaning v1: subtle camera drift + ambient mix (read-only data).
const MEANING_CAM_VEL_MAX: float = 0.22
const MEANING_CAM_REVIV_P: float = 0.00042
const MEANING_CAM_ABAND_P: float = 0.00036
const MEANING_CAM_PERM_ABAND_P: float = 0.00052
const MEANING_CAM_SCAR3_P: float = 0.0005
const MEANING_CAM_LOSCAR_P: float = 0.00014
const MEANING_AMBIENT_SMOOTH: float = 1.1
## World map traces: redraw the WorldTrace layer at least this often (traces
## draw in WorldTrace._draw — not Main._draw — so they appear above the map).
const TRACE_REDRAW_INTERVAL_SEC: float = 1.0
## Generational turnover (v1): one new pawn per this many ticks if population > 0.
const GENERATION_TICKS: int = 20000
const REPRODUCTION_CHECK_INTERVAL_TICKS: int = 300
## Co-presence rapport for pairing / births (deterministic; same path component only).
const SOCIAL_RAPPORT_ACCUM_INTERVAL_TICKS: int = 40
const SOCIAL_MEETING_EVENT_COOLDOWN_TICKS: int = 400
const SOCIAL_RAPPORT_MILESTONES: Array[int] = [56, 140, 280, 560]
## Cap chronicle writes per rapport pass. Co-located crowds (night at one stockpile)
## are O(n²) pairs; unconstrained WorldMemory spam tanks frames and inflates event counts.
const SOCIAL_WM_RECORD_BUDGET_PER_PASS: int = 48
const INFLUENCE_UPDATE_INTERVAL_TICKS: int = 500
const OBSERVER_HUD_REFRESH_TICKS: int = 30
const FOCUS_INSPECTOR_REFRESH_TICKS: int = 15
## Deterministic rebirth cadence (tick-gated, no frame-time).
const REBIRTH_CHECK_INTERVAL_TICKS: int = 4000  # OPTIMIZATION: Increased from 2000 to reduce hitch frequency
const SETTLEMENT_ARCHITECT_INTERVAL_TICKS: int = 5000
const SETTLEMENT_ARCHITECT_PHASE_OFFSET_TICKS: int = 347
const AGE_MEMORY_INTERVAL_TICKS: int = 10000
const AGE_MEMORY_PHASE_OFFSET_TICKS: int = 719
## Offset [method AnimalSpawner.update_population_dynamics] so it does not land on the same tick as [member REBIRTH_CHECK_INTERVAL_TICKS] (both were multiples of 1000; spike [code]animal_population[/code]+[code]rebirth_recompute[/code]).
const ANIMAL_POPULATION_PHASE_TICKS: int = 500
## Ecosystems (hunt) stay inert until this tick (world gen / reroll / load).
const WORLD_STABILIZATION_TICKS: int = 50
## Player does not architect the colony: no manual walls/beds/doors/stockpile zones.
## Construction remains `SettlementPlanner` + pawn job claims (NPC-equivalent sim path).
## Now dynamic: Observer mode enables placement; other modes disable it.
const PLAYER_CAN_PLACE_STRUCTURES_AND_ZONES: bool = false  # Legacy — use _can_player_place() instead

func _can_player_place() -> bool:
	return _player_mode == PlayerMode.OBSERVER
## Toolbar + keys 1–7 match GameManager.SPEED_STEPS (F10 creator menu still steals digit keys while open).
const ALLOW_SPEED_NUMBER_HOTKEYS: bool = true
## Keep load-in sessions predictable; speed only changes via explicit user action.
const RESTORE_SPEED_FROM_SAVE: bool = false
## World-level only; HeelKawnian/Animal read via [code]Main._world_stabilization_until_tick[/code].
## -1 = not initialized yet (hunt/tick guards treat as: allow hunt once bootstrapped sets a non-negative window).
static var _world_stabilization_until_tick: int = -1

@onready var _world: World = $WorldViewport/World
@onready var _preview_layer: Node2D = $WorldViewport/BuildPreviewOverlay
@onready var _pawn_spawner: PawnSpawner = $WorldViewport/PawnSpawner
@onready var _animal_spawner: AnimalSpawner = $WorldViewport/AnimalSpawner
@onready var _enemy_spawner: EnemySpawner = $WorldViewport/EnemySpawner
@onready var _hud: ColonyHUD = $UI_Viewport/ColonyHUD
@onready var _observer_hud: ObserverHUD = $UI_Viewport/ObserverHUD
@onready var _chronicle_ledger: ChronicleLedger = $UI_Viewport/ChronicleLedger
@onready var _chronicle_book: Node = $UI_Viewport/ChronicleBook
@onready var _seed_gallery: Node = $UI_Viewport/SeedGallery
@onready var _pawn_ai_inspector = $UI_Viewport/PawnAIInspector
@onready var _focus_inspector: FocusInspector = $UI_Viewport/FocusInspector
@onready var _region_inspector: RegionInspector = $UI_Viewport/RegionInspector
@onready var _timeline_controls: TimelineControls = $UI_Viewport/TimelineControls
@onready var _incarnation_picker: Control = null  # IncarnationPicker instance (created on demand)
@onready var _tutorial_hints: Node = null  # TutorialHints instance (created on demand)
@onready var _trade_overview: CanvasLayer = null  # TradeOverviewPanel instance (created on first open)
@onready var _first_launch_welcome: Node = null  # FirstLaunchWelcome instance (created on demand)
@onready var _map_mode_overlay: Node = $MapModeOverlay
@onready var _creator_debug_menu: CreatorDebugMenu = $CreatorDebugMenu
@onready var _settings_panel: CanvasLayer = $UI_Viewport/SettingsPanel
@onready var _toolbar: BuildToolbar = $UI_Viewport/BuildToolbar
@onready var _info_panel: PawnInfoPanel = $UI_Viewport/PawnInfoPanel
@onready var _minimap = $UI_Viewport/Minimap
@onready var _urgent_alert = $UI_Viewport/UrgentAlert
@onready var _audio_controller = $UI_Viewport/AudioController
@onready var _save_load_menu = $UI_Viewport/SaveLoadMenu
@onready var _main_menu = $UI_Viewport/MainMenu
@onready var _tile_tooltip = $UI_Viewport/TileTooltip
@onready var _inventory_ui: Node = get_node_or_null("UI_Viewport/PlayerInventory")
@onready var _survival_hud: Node = $UI_Viewport/SurvivalHUD
@onready var _camera_bookmarks = $CameraBookmarks
@onready var _event_particles = $EventParticles
@onready var _weather_overlay = $WeatherOverlay
@onready var _world_overlay = $WorldViewport/World/WorldOverlay
@onready var _fire_glow = $WorldViewport/World/FireGlow
@onready var _sun_moon = $WorldViewport/World/SunMoon
@onready var _ambient_biome_particles = $WorldViewport/World/AmbientBiomeParticles
@onready var _bloom_glow = $WorldViewport/World/BloomGlow
@onready var _command_mode = $CommandMode
@onready var _command_indicator = $WorldViewport/CommandIndicator
@onready var _pawn_name_labels = $WorldViewport/PawnNameLabels
@onready var _pawn_chatter = $WorldViewport/PawnChatter
@onready var _settlement_banner = $WorldViewport/SettlementBanner
@onready var _territory_overlay = $WorldViewport/TerritoryOverlay
@onready var _ambient_audio = $AmbientAudio
@onready var _trait_shop: Control = null
@onready var _debug_panel: Control = null
@onready var _day_night: DayNightCycle = $DayNight
@onready var _camera: Camera2D = $WorldViewport/Camera

# -------------------- runtime diagnostics --------------------
var _kernel_diagnostic: KernelDiagnostic = null
var _phase8_proof_overlay_layer: CanvasLayer = null
var _phase8_proof_overlay_text: RichTextLabel = null
var _spatial_profile_overlay_text: RichTextLabel = null
var _performance_monitor: PerformanceMonitorUI = null
var _research_particle_texture: Texture2D = null
const SELECT_PICK_RADIUS_PX: float = 16.0
var _kill_count: int = 0
var _resource_balance_audit_last_sig: String = ""

# -------------------- selection --------------------
## Currently selected pawn (right-side info panel). null = nothing selected.
## Click a pawn to select; click empty ground or press Esc to deselect.
var _selected_pawn = null
## Runtime truth tracking for click selection
var last_click_screen_position: Vector2 = Vector2.ZERO
var last_click_world_position: Vector2 = Vector2.ZERO
var last_click_method: String = "none"
var last_click_candidates_count: int = 0
var last_selected_pawn_id: int = -1
var last_selected_pawn_path: String = "none"
var last_selection_success: bool = false
var last_selection_failure_reason: String = "no_click_yet"
var selection_manual_click_proven: bool = false
## HUD + bottom toolbar + pawn sheet visibility (`` ` `` toggles for map-first play).
var _play_chrome_visible: bool = true
## Smooth camera lock on selected pawn (`G`). Cleared by middle-mouse pan.
var _camera_follow_selected: bool = false
var _playtest_recorder_ref: Node = null
var _playtest_last_cam_tick: int = 0
## Deterministic local-control pawn. Defaults to current selection.
var _player_pawn = null
var _hotkeys_enabled: bool = true
## Two **shipped** perspectives (CK3-style map cam, first-person, etc. are later layers).
## - **SPECTATOR** — worldwide / chronicler / "observer or developer" flyover: same sim clock, free camera, inspection, time speed, no single-body embodiment (docs/HEELKAWN_STANDALONE_MASTER_PLAN.md: Spectator state).
## - **INCARNATED** — you are one `HeelKawnian` in the world (same class as NPCs): embodied input, shared needs/jobs; parity target = everything an NPC can do that is implemented (ibid.: Incarnation state).
## - **OBSERVER** — full command authority over all pawns and structures (formerly "God mode").
enum PlayerMode {
	SPECTATOR = 0,
	INCARNATED = 1,
	OBSERVER = 2,
}
var _player_mode: int = PlayerMode.OBSERVER

## Incarnated players only "know" pawns / nearby places within this Chebyshev tile radius (spectator: worldwide).
const INCARNATE_KNOWLEDGE_FOG_RADIUS_TILES: int = 18


func _is_player_incarnated() -> bool:
	return _player_mode == PlayerMode.INCARNATED


func _tile_chebyshev_dist(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


## UI / observer: all pawns in spectator; only local pawns when [method is_player_incarnated].
func get_visible_pawns() -> Array[HeelKawnian]:
	var out: Array[HeelKawnian] = []
	if _pawn_spawner == null:
		return out
	if not is_player_incarnated():
		for p in _pawn_spawner.pawns:
			if p != null and is_instance_valid(p) and p.data != null:
				out.append(p)
		return out
	if _player_pawn == null or not is_instance_valid(_player_pawn) or _player_pawn.data == null:
		return out
	var my_tile: Vector2i = _player_pawn.data.tile_pos
	var r: int = INCARNATE_KNOWLEDGE_FOG_RADIUS_TILES
	for p in _pawn_spawner.pawns:
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		if _tile_chebyshev_dist(my_tile, p.data.tile_pos) <= r:
			out.append(p)
	return out


func get_visible_settlement_count() -> int:
	if not is_player_incarnated() or _player_pawn == null or not is_instance_valid(_player_pawn) or _player_pawn.data == null:
		return SettlementMemory.get_formal_settlement_count()
	var pt: Vector2i = _player_pawn.data.tile_pos
	var r: int = INCARNATE_KNOWLEDGE_FOG_RADIUS_TILES
	var n: int = 0
	for st_any in SettlementMemory.get_formal_settlements():
		if not (st_any is Dictionary):
			continue
		var ckr: int = int((st_any as Dictionary).get("center_region", -1))
		if ckr < 0:
			continue
		var ct: Vector2i = _center_tile_from_region_key(ckr)
		if _tile_chebyshev_dist(pt, ct) <= r:
			n += 1
	return n
var _player_input: PlayerInputBuffer = null
var _player_action_state: String = "idle"
var _chronicle_feed = null  # ChronicleFeed instance
## Observer routing from [PlayerIntentQueue] (one dispatch step per sim tick).
var _player_intent_pin_zone_id: String = ""
var _player_intent_focus_center_region: int = -1
var _avatar_panel: Node = null
var _consciousness_panel: Node = null
var _dialogue_panel: Node = null
var _settlement_mind_panel: Node = null


# -------------------- draft mode (combat) --------------------
## Draft mode: select pawns to fight enemies. Pawns in draft mode stop normal work.
var _draft_mode_active: bool = false
var _drafted_pawns: Array[HeelKawnian] = []
var _ambient_player: AudioStreamPlayer = null
var _ambient_playback: AudioStreamGeneratorPlayback = null
var _ambient_phase: float = 0.0
var _ambient_freq_current: float = 112.0
var _trace_redraw_timer: float = 0.0
var _ambient_freq_target: float = 112.0
var _ambient_audio_last_update_ms: int = 0
var _frame_time_samples: int = 0
var _frame_time_accum: float = 0.0
const AMBIENT_AUDIO_UPDATE_INTERVAL_MS: int = 200
const MAX_AMBIENT_AUDIO_FRAMES_PER_UPDATE: int = 64
## 0 = dead/empty, 1 = open/living. Drives crossfade; current region at camera.
var _meaning_ambient_mood: float = 0.5
var _meaning_cam_bias_timer: float = 0.0
## Settlement style expression (derived): open -> positive, defensive -> negative.
var _meaning_style_bias: float = 0.0
## Full-screen very low-alpha overlay (read-only mood); created in [_ensure_meaning_vignette].
var _meaning_vignette_rect: ColorRect = null

## Due-tick buckets for regrowth: ready_tick -> Array[{tile, feature, ready_tick}].
var _regrow_due_buckets: Dictionary = {}
var _regrow_due_ticks: Array[int] = []
## Sim tick at which the last generational birth (or failed attempt) was processed. Serialized.
var _last_generation_tick: int = 0
## Pawns/Animals run after Main on `game_tick`; one deferred pass flushes after their `WorldMemory` writes.
var _world_memory_derivative_flush_queued: bool = false
## RoadMemory.flush can run multiple times per render frame when catch-up ticks batch;
## coalesce to one deferred flush per frame max.
var _road_flush_deferred_pending: bool = false
## Coalesce same-tick [World] terrain / path cost refreshes (pair vs stack+ruins are separate).
var _last_heavy_refresh_tick: int = -1
var _last_heavy_stack_tick: int = -1
## Mining-reactive ore reseed is expensive (full-grid scan). Queue and process
## on cadence instead of per-completion to avoid long frame stalls.
var _mining_react_pending: bool = false
var _last_mining_react_tick: int = -1
## Debug-only hotspot reporter for `_on_game_tick` sections.
var _last_tick_hotspot_log_ms: int = -1_000_000
const MAIN_TICK_HOTSPOT_LOG_INTERVAL_MS: int = 2500
const MAIN_TICK_HOTSPOT_MIN_TOTAL_MS: float = 8.0
const MINING_REACT_MIN_INTERVAL_TICKS: int = 300
const REGROWTH_SCAN_BUDGET_PER_TICK: int = 32
const REGROWTH_RESTORE_BUDGET_PER_TICK: int = 4
const MINING_REACT_SCAN_ROWS_PER_STEP: int = 4

# Mining react step interval at high speed (skip N ticks between steps to reduce per-frame load)
var _mining_react_step_skip_counter: int = 0
const MINING_REACT_WORK_BUDGET_PER_TICK: int = 2048
const INSPECT_SCAN_INTERVAL_TICKS: int = 30
const CONSTRUCTION_JOB_SEED_INTERVAL_TICKS: int = 30
var _last_inspect_event_tick_shown: int = -1
var _inspect_tooltip_node: Control = null
var _inspect_audio_player: AudioStreamPlayer = null
var _inspect_audio_playback: AudioStreamGeneratorPlayback = null
## Incremental mining-react state: avoid full-map scans in one tick.
var _mining_react_in_progress: bool = false
var _mining_react_scan_y_cursor: int = 0
var _mining_react_newly_minable_accum: int = 0
var _mining_react_work_used: int = 0
## Cache tunnel frontier targets so we avoid repeated full-map tunnel target BFS.
var _tunnel_frontier_cache: Array[Vector2i] = []
var _tunnel_frontier_cache_cursor: int = 0
var _tunnel_frontier_cache_component: int = -1
var _tunnel_frontier_cache_built_tick: int = -1
const TUNNEL_FRONTIER_CACHE_MAX_TARGETS: int = 24
const TUNNEL_FRONTIER_CACHE_REFRESH_TICKS: int = 720
## Hunt candidate index: deterministic sorted tile list refreshed periodically.
var _hunt_candidate_tiles: Array[Vector2i] = []
var _hunt_candidate_cursor: int = 0
var _hunt_candidate_last_refresh_tick: int = -1
var _hunt_live_counts_cache: Dictionary = {}
var _hunt_live_total_cache: int = 0
const HUNT_CANDIDATE_REFRESH_TICKS: int = 24
const HUNT_CANDIDATE_SCAN_LIMIT_MIN: int = 18
## pair key ("low-high") -> last tick a social_meeting event was logged.
var _social_meeting_last_tick_by_pair: Dictionary = {}
## pair key ("low-high") -> highest rapport milestone already logged.
var _social_rapport_milestone_by_pair: Dictionary = {}

const PAWN_DIVERGENCE_PACKET_SCHEMA_VERSION: int = 1
var _pawn_divergence_by_center: Dictionary = {}
var _pawn_divergence_total_claim_events_seen: int = 0
var _pawn_divergence_skip_no_bound_center: int = 0
var _pawn_divergence_skip_pre_settlement_context: int = 0
var _pawn_divergence_native_bound_events: int = 0
var _pawn_divergence_fallback_bound_events: int = 0
var _pawn_divergence_context_source_counts: Dictionary = {}
var _pawn_divergence_skip_no_specialization_context: int = 0
var _pawn_divergence_no_spec_by_center: Dictionary = {}
var _pawn_divergence_no_spec_by_phase: Dictionary = {}
var _pawn_divergence_last_job_by_pawn_id: Dictionary = {}
var _pawn_divergence_scored_events: int = 0
var _pawn_divergence_aligned_total: int = 0
var _pawn_divergence_divergent_total: int = 0
var _pawn_divergence_neutral_total: int = 0
var _pawn_divergence_first_scored_center_region: int = -1
var _pawn_divergence_first20_scored_lines: Array[String] = []
var _pawn_divergence_exit_summary_emitted: bool = false
var _pawn_divergence_summary_emitted_ticks: Dictionary = {}

func _is_ultra_speed() -> bool:
	return GameManager.game_speed >= 12.0


func _is_simulation_worker_mode() -> bool:
	if GameManager == null:
		return false
	return GameManager.get("simulation_worker_mode") == true


func get_pawn_spawner() -> Node:
	return _pawn_spawner


func get_player_pawn_id() -> int:
	if _player_pawn != null and is_instance_valid(_player_pawn) and _player_pawn.data != null:
		return int(_player_pawn.data.id)
	return -1

func _high_speed_interval(normal_ticks: int, fast_ticks: int, ultra_ticks: int) -> int:
	# Re-enabled for smooth gameplay - game was lagging too hard without throttling
	if GameManager == null:
		return normal_ticks
	var gs: float = GameManager.game_speed
	if gs >= 100.0:
		return ultra_ticks
	if gs >= 50.0:
		return fast_ticks
	return normal_ticks


func _planner_interval_for_speed() -> int:
	# Re-enabled for smooth gameplay - game was lagging too hard without throttling
	if GameManager == null:
		return 90
	var gs: float = GameManager.game_speed
	if gs >= 100.0:
		return 360
	if gs >= 50.0:
		return 240
	if gs >= 26.0:
		return 180
	if gs >= 12.0:
		return 120
	return 90


func _heavy_planner_interval_for_speed() -> int:
	# Re-enabled for smooth gameplay - game was lagging too hard without throttling
	if GameManager == null:
		return 180
	var gs: float = GameManager.game_speed
	if gs >= 100.0:
		return 720
	if gs >= 50.0:
		return 480
	if gs >= 26.0:
		return 360
	if gs >= 12.0:
		return 240
	return 180


func _pawn_divergence_detail_logs_enabled() -> bool:
	if not OS.is_debug_build():
		return false
	# Per-claim lines (bind/skip/scored) can print hundreds per tick → editor/game hitching.
	# Enable only when a harness const asks for it, not normal DEBUG playtests.
	if not _pawn_divergence_validation_logs_enabled():
		return false
	if GameManager.game_speed >= 26.0:
		return false
	return true


func _pawn_divergence_validation_logs_enabled() -> bool:
	if not OS.is_debug_build():
		return false
	var env_value: String = OS.get_environment("HEELKAWN_VALIDATION_LOGS")
	if env_value == "1" or env_value.to_lower() == "true":
		return true
	if SettlementMemory != null:
		if bool(SettlementMemory.VALIDATION_SESSION_ENABLED):
			return true
		if bool(SettlementMemory.SPECIALIZATION_VALIDATION_LOG_ENABLED):
			return true
	return false


func _should_post_more_hunt_jobs() -> bool:
	return StockpileManager.total_count_of(Item.Type.MEAT) < HUNT_MEAT_STOCKPILE_SOFT_CAP

func _dynamic_hunt_job_budget(live_animals: int = -1) -> int:
	if live_animals < 0:
		if _animal_spawner == null:
			return 1
		live_animals = 0
		for a in _animal_spawner.animals:
			if a != null and is_instance_valid(a):
				live_animals += 1
	var budget: int = maxi(1, int(ceil(float(live_animals) / float(HUNT_JOB_PER_ANIMALS_DIVISOR))))
	budget = mini(budget, MAX_DYNAMIC_HUNT_JOBS_PER_PASS)
	if GameManager != null:
		var gs: float = GameManager.game_speed
		if gs >= 100.0:
			return 1
		if gs >= 50.0:
			return 1
		if gs >= 26.0:
			return mini(2, budget)
		if gs >= 12.0:
			budget = maxi(1, int(ceil(float(budget) * 0.5)))
	return budget

func _hunt_reserve_for_species(species: int) -> int:
	if species == Animal.Type.DEER:
		return MIN_DEER_RESERVE
	return MIN_RABBIT_RESERVE

func _live_wildlife_counts() -> Dictionary:
	var out: Dictionary = {
		int(Animal.Type.RABBIT): 0,
		int(Animal.Type.DEER): 0,
	}
	if _animal_spawner == null:
		return out
	for a in _animal_spawner.animals:
		if a == null or not is_instance_valid(a):
			continue
		var sp: int = int(a.animal_type)
		out[sp] = int(out.get(sp, 0)) + 1
	return out

# -------------------- designation (player build mode) --------------------
## Player build modes. NONE means clicks are ignored. Every other mode uses
## the same click-drag rectangle system:
##   - click + release on the same tile  -> stamp one tile (back-compat).
##   - click + drag + release             -> stamp every tile in the rect.
##
## BUILD_BED / BUILD_WALL / BUILD_DOOR post one build job per tile in the rect.
## DESIGNATE_ZONE creates a single Stockpile covering the whole rect.
enum DesignationMode { 
	NONE, 
	BUILD_BED, 
	BUILD_WALL, 
	BUILD_DOOR, 
	BUILD_SHELTER,
	BUILD_STORAGE_HUT,
	BUILD_FIRE_PIT,
	BUILD_WORKSHOP,
	DESIGNATE_ZONE 
}
var _designation_mode: int = DesignationMode.NONE
## Currently hovered tile in tile coords, or (-1,-1) if mouse is off-map.
var _hover_tile: Vector2i = Vector2i(-1, -1)

# -------------------- drag-to-stamp state --------------------
## Filter applied to the next-designated zone. Cycles through Stockpile.Filter
## via the F key or the toolbar "Filter:" button. Doesn't affect already-
## placed zones.
var _zone_next_filter: int = 0  # Stockpile.Filter.ALL -- typed as int to
								# avoid touching Stockpile before autoloads load
## True while the player is holding left mouse in a designation mode. The
## rectangle grows with the mouse; release commits.
var _is_dragging: bool = false
## First and current tile of the in-progress drag. (-1,-1) when not dragging.
var _drag_start: Vector2i = Vector2i(-1, -1)
var _drag_current: Vector2i = Vector2i(-1, -1)

## Zones have their own size caps; build-mode stamps use a tile count cap to
## keep a stray wide drag from dumping 10k jobs into the queue.
const ZONE_MAX_AREA: int = 400   # 20x20 cap for stockpile zones
const BUILD_DRAG_MAX_TILES: int = 256  # ~16x16 of walls/beds/doors at once

## One-shot [VALIDATION_STATUS] / [VALIDATION_WARN] after scene boot (observability only).
var _validation_harness_observability_logged: bool = false
## Max settlement rows in Observer realm panel; Shift+F9 cycles 8→12→16→24.
var _realm_crown_max_settlements: int = 8
# Per-tile job-post cooldown to reduce spam and stabilize labor pacing.
const JOB_POST_COOLDOWN_TICKS: int = 50
var _job_post_cooldowns: Dictionary = {}
const PRUNE_INTERVAL_TICKS: int = 500
var _last_prune_tick: int = -1
var _jobs_suppressed_this_session: int = 0

func _tile_job_key(tile: Vector2i) -> int:
	return tile.y * WorldData.WIDTH + tile.x

func _can_post_job_at(tile: Vector2i) -> bool:
	if GameManager == null:
		return true
	var now: int = GameManager.tick_count
	var expiry: int = int(_job_post_cooldowns.get(_tile_job_key(tile), 0))
	return expiry <= now

func _set_job_post_cooldown(tile: Vector2i, override_ticks: int = -1) -> void:
	if GameManager == null:
		return
	var ticks: int = JOB_POST_COOLDOWN_TICKS if override_ticks < 0 else override_ticks
	_job_post_cooldowns[_tile_job_key(tile)] = GameManager.tick_count + ticks

func _prune_job_post_cooldowns() -> void:
	if GameManager == null:
		return
	var before_size: int = _job_post_cooldowns.size()
	var now: int = GameManager.tick_count
	var keys_to_remove: Array = []
	for k in _job_post_cooldowns.keys():
		var expiry: int = int(_job_post_cooldowns.get(k, 0))
		if expiry < now:
			keys_to_remove.append(k)
	for k in keys_to_remove:
		_job_post_cooldowns.erase(k)
	var after_size: int = _job_post_cooldowns.size()
	if GameManager.verbose_logs():
		print("[JobCooldown] Pruned cooldowns: before=%d after=%d" % [before_size, after_size])


func _reset_job_cooldown_telemetry() -> void:
	_jobs_suppressed_this_session = 0


func _cycle_realm_crown_max_settlements() -> void:
	var opts: Array = [8, 12, 16, 24]
	var idx: int = opts.find(_realm_crown_max_settlements)
	if idx < 0:
		idx = 0
	else:
		idx = (idx + 1) % opts.size()
	_realm_crown_max_settlements = int(opts[idx])
	if OS.is_debug_build():
		print("[Main] Realm crown list cap: %d settlements" % _realm_crown_max_settlements)


func _ready() -> void:
	CrashTrap.enter_system("Main._ready")
	var simulation_worker: bool = _is_simulation_worker_mode()
	if not simulation_worker:
		SettlementMemory.print_validation_smoketest_from_main()

	# CRITICAL: Create and add TickManager if it doesn't exist
	if TickManager == null:
		var tick_manager: Node = load("res://autoloads/TickManager.gd").new()
		tick_manager.name = "TickManager"
		add_child(tick_manager)

	# Connect to PlaytestRecorder for automated playtest logging
	# (HeelKawnian selection recording is now handled inside _set_selected_pawn)
	var playtest_recorder: Node = get_node_or_null("/root/PlaytestRecorder")
	if playtest_recorder != null:
		# Log camera movement (sample every 10 ticks via _on_world_tick)
		_playtest_recorder_ref = playtest_recorder

	# Ticks are driven by TickManager fixed-step clock.
	if TickManager != null and TickManager.has_signal("tick_processed"):
		TickManager.tick_processed.connect(_on_world_tick)
	GameManager.speed_changed.connect(_on_speed_changed)
	if TickManager != null:
		CrashTrap.validate_signal(TickManager, &"tick_processed")
	CrashTrap.validate_signal(GameManager, &"speed_changed")
	CrashTrap.validate_autoload("SettlementMemory", "Node")
	CrashTrap.validate_autoload("WorldAI", "Node")
	if not simulation_worker:
		_player_input = PlayerInputBuffer.new()
		_player_input.name = "PlayerInputBuffer"
		add_child(_player_input)
		_player_input.set_process_unhandled_input(true)
		# Chronicle feed — real-time event stream
		var _cf = load("res://scripts/ui/ChronicleFeed.gd").new()
		_cf.name = "ChronicleFeed"
		add_child(_cf)
		_chronicle_feed = _cf
		_kernel_diagnostic = KernelDiagnostic.new()
		_kernel_diagnostic.name = "KernelDiagnostic"
		add_child(_kernel_diagnostic)
		_init_ambient_audio()
		# Initialize Phase 5 Map Mode overlay
		if _map_mode_overlay != null and _map_mode_overlay.has_method("initialize"):
			_map_mode_overlay.call("initialize", _world, _camera)
		# Initialize new UI systems
		if _minimap != null and _minimap.has_method("initialize"):
			_minimap.initialize(_world, _camera, _pawn_spawner)
		if _urgent_alert != null and _urgent_alert.has_method("initialize"):
			_urgent_alert.initialize(_world, _camera)
		# Initialize new UI systems (round 2)
		if _tile_tooltip != null and _tile_tooltip.has_method("initialize"):
			_tile_tooltip.initialize(_world, _camera)
		if _camera_bookmarks != null and _camera_bookmarks.has_method("initialize"):
			_camera_bookmarks.initialize(_camera)
		if _event_particles != null and _event_particles.has_method("initialize"):
			_event_particles.initialize(_world)
		if _weather_overlay != null and _weather_overlay.has_method("initialize"):
			_weather_overlay.initialize(_world, _camera)
		if _world_overlay != null and _world_overlay.has_method("initialize"):
			_world_overlay.initialize(_world, _camera)
		if _fire_glow != null and _fire_glow.has_method("initialize"):
			_fire_glow.initialize(_world, _camera)
			_sun_moon.initialize(_world)
			_ambient_biome_particles.initialize(_world, _camera)
			_bloom_glow.initialize(_world)
		# Initialize command mode
		if _command_mode != null and _command_mode.has_method("initialize"):
			_command_mode.initialize(_world, _camera, _pawn_spawner)
			_command_mode.command_issued.connect(_on_command_issued)
			_command_mode.zone_painted.connect(_on_zone_painted)
			_command_mode.can_command_callback = _can_command_pawn
		if _command_indicator != null and _command_indicator.has_method("initialize"):
			_command_indicator.initialize(_world)
		if _pawn_name_labels != null and _pawn_name_labels.has_method("initialize"):
			_pawn_name_labels.initialize(_world, _camera)
		if _pawn_chatter != null and _pawn_chatter.has_method("initialize"):
			_pawn_chatter.initialize(_world)
			if _pawn_chatter.has_method("set_llm_client") and _pawn_chatter.get("_llm_client") == null:
				var orch: Node = get_node_or_null("/root/HeelKawnAIOrchestrator")
				if orch != null and orch.get("_llm_client") != null:
					_pawn_chatter.set_llm_client(orch.get("_llm_client"))
		if _settlement_banner != null and _settlement_banner.has_method("initialize"):
			_settlement_banner.initialize(_world)
		if _territory_overlay != null and _territory_overlay.has_method("initialize"):
			_territory_overlay.initialize(_world, _camera)
		if _ambient_audio != null and _ambient_audio.has_method("initialize"):
			_ambient_audio.initialize(_world, _camera)
		
		# Initialize TutorialHints (polish pass)
		var tutorial_hints_script: Script = load("res://scripts/ui/TutorialHints.gd")
		_tutorial_hints = tutorial_hints_script.new()
		_tutorial_hints.name = "TutorialHints"
		add_child(_tutorial_hints)
		
		# Initialize FirstLaunchWelcome (polish pass)
		var welcome_script: Script = load("res://scripts/ui/FirstLaunchWelcome.gd")
		_first_launch_welcome = welcome_script.new()
		_first_launch_welcome.name = "FirstLaunchWelcome"
		add_child(_first_launch_welcome)
		
		# Wire SaveLoadMenu signals
		if _save_load_menu != null:
			_save_load_menu.save_requested.connect(_on_save_slot)
			_save_load_menu.load_requested.connect(_on_load_slot)
			_save_load_menu.new_game_requested.connect(_on_new_game)
		# Initialize SurvivalHUD
		if _survival_hud != null and _survival_hud.has_method("initialize"):
			_survival_hud.call("initialize", _world, _camera)
		# Wire MainMenu signals
		if _main_menu != null:
			_main_menu.new_game_pressed.connect(_on_new_game)
			_main_menu.play_pressed.connect(_on_play_mode)
			_main_menu.observer_mode_pressed.connect(_on_observer_mode_start)
			_main_menu.load_game_pressed.connect(func(): if _save_load_menu != null: _save_load_menu.toggle())
			_main_menu.settings_pressed.connect(func(): if _settings_panel != null: _settings_panel.toggle())
			_main_menu.quit_pressed.connect(func(): get_tree().quit())
		if _seed_gallery != null and not _seed_gallery.seed_selected.is_connected(_on_seed_gallery_seed_selected):
			_seed_gallery.seed_selected.connect(_on_seed_gallery_seed_selected)
			_seed_gallery.closed.connect(_on_seed_gallery_closed)
		if _chronicle_ledger != null:
			_chronicle_ledger.bind(_pawn_spawner)
		if _chronicle_book != null:
			_chronicle_book.bind(_pawn_spawner)
		if FootpathMemory != null and FootpathMemory.has_method("bind_context"):
			FootpathMemory.bind_context(_world, _pawn_spawner)
		if BuildingUsageTracker != null and BuildingUsageTracker.has_method("bind_context"):
			BuildingUsageTracker.bind_context(_world, _pawn_spawner)
		# SnowAccumulation disabled due to persistent caching error
		if TimeLapseRecorder != null and TimeLapseRecorder.has_method("bind_context"):
			TimeLapseRecorder.bind_context(_world, _pawn_spawner, _camera)
		
		# Wire BuildToolbar signals
		if _toolbar != null:
			_toolbar.structure_type_requested.connect(_on_structure_type_requested)
			
		if TechnologySystem != null:
			# Connect to technology signals safely
			if TechnologySystem.has_signal("research_started"):
				TechnologySystem.research_started.connect(_on_research_started)
			# Backward/forward compatibility: some branches expose `research_progress`,
			# others expose `research_progressed`.
			if TechnologySystem.has_signal("research_progressed"):
				TechnologySystem.research_progressed.connect(_on_research_progressed)
			if TechnologySystem.has_signal("research_completed"):
				TechnologySystem.research_completed.connect(_on_research_completed)
		# React to mining progress: when a wall comes down or an ore is cleared,
		# new ores can become reachable and we may want to queue the next tunnel.
		JobManager.job_completed.connect(_on_job_completed)
		JobManager.job_claimed.connect(_on_job_claimed)
		# Bottom toolbar: time, save/load, appearance (no manual structure stamping).
		if _toolbar != null:
			_toolbar.speed_index_requested.connect(GameManager.set_speed_index)
			_toolbar.pause_toggled.connect(GameManager.toggle_pause)
			_toolbar.save_requested.connect(_colony_save)
			_toolbar.load_requested.connect(_colony_load)
			_toolbar.appearance_edit_requested.connect(_toggle_avatar_panel)
			if _toolbar.has_signal("structure_type_requested"):
				_toolbar.structure_type_requested.connect(_on_structure_type_selected)
		call_deferred("_ensure_avatar_panel")
	if OS.is_debug_build():
		print("[Main] Scene ready. Tick interval: %.2fs" % GameManager.TICK_INTERVAL_SECONDS)
	# Start every session at 1x, unpaused. Player can change only through explicit controls.
	GameManager.set_speed_index(0)
	_bootstrap_colony()
	if not simulation_worker:
		if _hud != null:
			_hud.set_player_control_refs(_player_input, _player_pawn)
			_update_hud_mode_badge()
		if _observer_hud != null:
			_observer_hud.set_visible_state(false)
		if _focus_inspector != null:
			_focus_inspector.set_visible_state(false)
		_init_phase8_proof_overlay()
		_init_performance_monitor()
		_refresh_spatial_profile_overlay()
		_ensure_meaning_vignette()
		# Debug panel is loaded lazily via F12 to keep startup path minimal.
	else:
		_disconnect_worker_ui_signal_receivers()
		_configure_simulation_worker_mode()
	call_deferred("_log_validation_harness_observability_once")
	CrashTrap.exit_system("Main._ready")


func _ensure_debug_panel() -> void:
	# Keep startup resilient: if the debug panel script fails, boot still proceeds.
	if _debug_panel != null and is_instance_valid(_debug_panel):
		return
	var debug_script := ResourceLoader.load(DEBUG_PANEL_PATH) as Script
	if debug_script == null:
		if OS.is_debug_build():
			print("[Main] Debug panel script not found: %s" % DEBUG_PANEL_PATH)
		return
	var dp = debug_script.new()
	if dp == null or not (dp is Control):
		if OS.is_debug_build():
			print("[Main] Debug panel instantiation failed")
		return
	_debug_panel = dp
	$UI_Viewport.add_child(_debug_panel)
	# Ensure hotkeys default to enabled; panel checkbox can toggle
	_set_hotkeys_enabled(true)


func _configure_simulation_worker_mode() -> void:
	if not _is_simulation_worker_mode():
		return
	_play_chrome_visible = false
	var muted_nodes: Array[Node] = [_hud, _observer_hud, _focus_inspector, _toolbar, _info_panel, _map_mode_overlay, _creator_debug_menu, _settings_panel]
	for node in muted_nodes:
		if node != null and is_instance_valid(node):
			node.process_mode = Node.PROCESS_MODE_DISABLED
			if node is CanvasItem:
				(node as CanvasItem).visible = false


func _disconnect_worker_ui_signal_receivers() -> void:
	if not _is_simulation_worker_mode():
		return
	var muted_prefixes: PackedStringArray = ["/root/Main/UI_Viewport", "/root/Main/CreatorDebugMenu", "/root/Main/MapModeOverlay"]
	for signal_name in ["game_tick", "speed_changed"]:
		var connection_list: Array = GameManager.get_signal_connection_list(signal_name)
		for connection_any in connection_list:
			if not (connection_any is Dictionary):
				continue
			var connection: Dictionary = connection_any as Dictionary
			var callable_variant: Variant = connection.get("callable", null)
			if not (callable_variant is Callable):
				continue
			var callable: Callable = callable_variant as Callable
			if not callable.is_valid():
				continue
			var target: Object = callable.get_object()
			if not (target is Node):
				continue
			var target_node: Node = target as Node
			var target_path: String = str(target_node.get_path())
			var should_disconnect: bool = false
			for prefix in muted_prefixes:
				if target_path.begins_with(prefix):
					should_disconnect = true
					break
			if not should_disconnect:
				continue
			if GameManager.is_connected(signal_name, callable):
				GameManager.disconnect(signal_name, callable)
			target_node.queue_free()


func _exit_tree() -> void:
	_emit_pawn_divergence_summary_if_needed(GameManager.tick_count, true)


func _log_validation_harness_observability_once() -> void:
	if _validation_harness_observability_logged:
		return
	_validation_harness_observability_logged = true
	var dbg: bool = OS.is_debug_build()
	var session_const: bool = SettlementMemory.VALIDATION_SESSION_ENABLED
	var clean_const: bool = WorldEvents.VALIDATION_CLEAN_ECONOMY_EVENTS
	var clean_active: bool = WorldEvents.validation_clean_economy_events_active()
	var truth_active: bool = SettlementMemory.validation_truth_verify_armed()
	var spec_active: bool = SettlementMemory.validation_specialization_log_armed()
	if dbg:
		print(
				(
                        "[VALIDATION_STATUS] debug_build=%s VALIDATION_SESSION_ENABLED_const=%s "
						+ "WorldEvents_VALIDATION_CLEAN_ECONOMY_EVENTS_const=%s clean_economy_active=%s "
						+ "settlement_truth_verify_active=%s specialization_validation_log_active=%s"
				)
				% [dbg, session_const, clean_const, clean_active, truth_active, spec_active]
		)
	if session_const and not dbg:
		print(
                "[VALIDATION_WARN] VALIDATION_SESSION_ENABLED is true but OS.is_debug_build() is false — harness stays DISARMED "
				+ "(no economy-event suppression, no [SETTLEMENT_VERIFY], no [SPECIALIZATION_VALIDATE]). "
				+ "Use editor Play or a debug export."
		)
	if clean_const and not dbg:
		print(
                "[VALIDATION_WARN] WorldEvents.VALIDATION_CLEAN_ECONOMY_EVENTS is true but not a debug build — suppression stays off."
		)
	if SettlementMemory.SETTLEMENT_STATE_TRUTH_VERIFY_MODE and not dbg:
		print(
                "[VALIDATION_WARN] SETTLEMENT_STATE_TRUTH_VERIFY_MODE is true but not a debug build — [SETTLEMENT_VERIFY] will not print."
		)
	if SettlementMemory.SPECIALIZATION_VALIDATION_LOG_ENABLED and not dbg:
		print(
                "[VALIDATION_WARN] SPECIALIZATION_VALIDATION_LOG_ENABLED is true but not a debug build — [SPECIALIZATION_VALIDATE] will not print."
		)
	if session_const and dbg and (not clean_active or not truth_active or not spec_active):
		print(
                "[VALIDATION_WARN] VALIDATION_SESSION_ENABLED in a debug build but a subsystem reports inactive "
				+ "(clean=%s truth=%s spec=%s) — inspect harness gates if this ever appears."
				% [clean_active, truth_active, spec_active]
		)


func _job_channel_for_divergence_log(job_type: int) -> String:
	match int(job_type):
		Job.Type.CHOP, Job.Type.BUILD_BED, Job.Type.BUILD_WALL, Job.Type.BUILD_DOOR:
			return "wood"
		Job.Type.MINE, Job.Type.MINE_WALL:
			return "stone"
		Job.Type.FORAGE, Job.Type.HUNT, Job.Type.FISH:
			return "food"
		Job.Type.TRADE_HAUL:
			return "trade"
		_:
			return ""


func _settlement_by_center_region(center_region: int) -> Dictionary:
	if center_region < 0:
		return {}
	for st_any in SettlementMemory.settlements:
		if not (st_any is Dictionary):
			continue
		var st: Dictionary = st_any as Dictionary
		if int(st.get("center_region", -1)) == center_region:
			return st
	return {}


func _settlement_context_for_claim(
	effective_center_region: int,
	job_region: int,
	pawn_region: int
) -> Dictionary:
	var st_center: Dictionary = _settlement_by_center_region(effective_center_region)
	if not st_center.is_empty():
		return {"settlement": st_center, "source": "center_region"}
	var st_job_v: Variant = SettlementMemory.get_settlement_at_region(job_region)
	if st_job_v is Dictionary:
		var st_job: Dictionary = st_job_v as Dictionary
		if int(st_job.get("center_region", -1)) == effective_center_region:
			return {"settlement": st_job, "source": "job_region_membership"}
	var st_pawn_v: Variant = SettlementMemory.get_settlement_at_region(pawn_region)
	if st_pawn_v is Dictionary:
		var st_pawn: Dictionary = st_pawn_v as Dictionary
		if int(st_pawn.get("center_region", -1)) == effective_center_region:
			return {"settlement": st_pawn, "source": "pawn_region_membership"}
	return {"settlement": {}, "source": "none"}


func _has_any_valid_settlement_center() -> bool:
	for st_any in SettlementMemory.settlements:
		if not (st_any is Dictionary):
			continue
		var c: int = int((st_any as Dictionary).get("center_region", -1))
		if c >= 0:
			return true
	return false


func _build_pawn_divergence_center_fingerprint() -> String:
	var centers: Array = _pawn_divergence_by_center.keys()
	centers.sort()
	var center_digest_parts: PackedStringArray = PackedStringArray()
	for c_any in centers:
		var c: int = int(c_any)
		var row: Dictionary = _pawn_divergence_by_center.get(c, {})
		center_digest_parts.append(
            "%d:%d,%d,%d,%d"
			% [
				c,
				int(row.get("scored", 0)),
				int(row.get("aligned", 0)),
				int(row.get("divergent", 0)),
				int(row.get("neutral", 0)),
			]
		)
	var center_fingerprint: String = ";".join(center_digest_parts)
	if center_fingerprint == "":
		center_fingerprint = "none"
	return center_fingerprint


func _center_region_from_fast_map(region_key: int) -> int:
	return SettlementMemory.get_center_region_for_region(region_key)


func _center_region_from_direct_membership(region_key: int) -> int:
	var st_v: Variant = SettlementMemory.get_settlement_at_region(region_key)
	if st_v is Dictionary:
		return int((st_v as Dictionary).get("center_region", -1))
	return -1


func _claim_tile_hits_any_stockpile_zone(tile: Vector2i) -> bool:
	for z in StockpileManager.zones():
		if z != null and is_instance_valid(z) and z.contains_tile(tile):
			return true
	return false


func _claim_center_fallback_from_zone_context(
	pawn_tile: Vector2i,
	job_tile: Vector2i
) -> int:
	if not _claim_tile_hits_any_stockpile_zone(pawn_tile) and not _claim_tile_hits_any_stockpile_zone(job_tile):
		return -1
	var st: Dictionary = _pick_validation_proof_anchor_settlement()
	if st.is_empty():
		return -1
	return int(st.get("center_region", -1))


func _on_job_claimed(job: Job, pawn: HeelKawnian) -> void:
	# CLAIM-TIME BINDING VALIDATION TARGET
	# PASS:
	# - at least one claim resolves center_region >= 0
	# - at least one scored [PAWN_DIVERGENCE] line appears
	# - summary shows scored_events > 0
	# - bind trace distinguishes native binding vs fallback binding
	# FAIL:
	# - claims remain overwhelmingly unbound
	# - no scored divergence lines occur
	# - summary ends with scored_events=0 in an active colony run
	# Claim-time binding diagnosis:
	# 1) First attempt is fast region->center map (SettlementMemory cache).
	# 2) Fallback is direct settlement membership query by region.
	# 3) Final debug-only fallback uses visible zone context + deterministic anchor center.
	# 4) If all three fail, center stays -1 and claim is skipped as no_bound_center.
	if not OS.is_debug_build():
		return
	if job == null or pawn == null or not is_instance_valid(pawn) or pawn.data == null:
		return
	_pawn_divergence_total_claim_events_seen += 1
	var pawn_tile: Vector2i = pawn.data.tile_pos
	var job_tile: Vector2i = job.work_tile
	var pawn_region: int = _WM._region_key(pawn_tile.x, pawn_tile.y)
	var job_region: int = _WM._region_key(job.work_tile.x, job.work_tile.y)
	var pawn_center_fast_map: int = _center_region_from_fast_map(pawn_region)
	var job_center_fast_map: int = _center_region_from_fast_map(job_region)
	var pawn_center_direct_membership: int = _center_region_from_direct_membership(pawn_region)
	var job_center_direct_membership: int = _center_region_from_direct_membership(job_region)
	var pawn_center_region: int = pawn_center_fast_map
	var job_center_region: int = job_center_fast_map
	var effective_center_region: int = (job_center_region if job_center_region >= 0 else pawn_center_region)
	var bind_source: String = "fast_map"
	var zone_fallback_center: int = -1
	if effective_center_region < 0:
		pawn_center_region = pawn_center_direct_membership
		job_center_region = job_center_direct_membership
		effective_center_region = (job_center_region if job_center_region >= 0 else pawn_center_region)
		bind_source = "direct_membership"
	if effective_center_region < 0:
		zone_fallback_center = _claim_center_fallback_from_zone_context(pawn_tile, job_tile)
		if zone_fallback_center >= 0:
			effective_center_region = zone_fallback_center
			bind_source = "zone_context_fallback"
	if effective_center_region < 0:
		bind_source = "unbound"
	if _pawn_divergence_detail_logs_enabled():
		print(
			(
                "[PAWN_DIVERGENCE_BIND_TRACE] tick=%d action=claim bind_source=%s pawn_id=%d pawn=%s "
				+ "pawn_region=%d job_region=%d pawn_center_fast_map=%d job_center_fast_map=%d "
				+ "pawn_center_direct_membership=%d job_center_direct_membership=%d "
				+ "zone_fallback_center=%d center_region=%d"
			)
			% [
				GameManager.tick_count,
				bind_source,
				int(pawn.data.id),
				pawn.data.display_name,
				pawn_region,
				job_region,
				pawn_center_fast_map,
				job_center_fast_map,
				pawn_center_direct_membership,
				job_center_direct_membership,
				zone_fallback_center,
				effective_center_region,
			]
		)
	if effective_center_region < 0:
		var has_settlement_context: bool = _has_any_valid_settlement_center()
		if has_settlement_context:
			_pawn_divergence_skip_no_bound_center += 1
			var skip_line_no_center: String = (
                "[PAWN_DIVERGENCE_SKIP] tick=%d action=claim reason=no_bound_center pawn_id=%d pawn=%s pawn_region=%d job_region=%d pawn_center_region=%d job_center_region=%d center_region=%d"
				% [
					GameManager.tick_count,
					int(pawn.data.id),
					pawn.data.display_name,
					pawn_region,
					job_region,
					pawn_center_region,
					job_center_region,
					effective_center_region,
				]
			)
			if _pawn_divergence_detail_logs_enabled():
				print(skip_line_no_center)
		else:
			_pawn_divergence_skip_pre_settlement_context += 1
			if _pawn_divergence_detail_logs_enabled():
				print(
                    "[PAWN_DIVERGENCE_SKIP] tick=%d action=claim reason=pre_settlement_context pawn_id=%d pawn=%s pawn_region=%d job_region=%d center_region=%d"
					% [
						GameManager.tick_count,
						int(pawn.data.id),
						pawn.data.display_name,
						pawn_region,
						job_region,
						effective_center_region,
					]
				)
		return
	if bind_source == "fast_map":
		_pawn_divergence_native_bound_events += 1
	else:
		_pawn_divergence_fallback_bound_events += 1
	var st_ctx: Dictionary = _settlement_context_for_claim(
		effective_center_region,
		job_region,
		pawn_region
	)
	var st_source: String = str(st_ctx.get("source", "none"))
	_pawn_divergence_context_source_counts[st_source] = int(
		_pawn_divergence_context_source_counts.get(st_source, 0)
	) + 1
	var st: Dictionary = st_ctx.get("settlement", {}) as Dictionary
	if st_source != "center_region" and _pawn_divergence_detail_logs_enabled():
		print(
            "[PAWN_DIVERGENCE_CONTEXT_TRACE] tick=%d action=claim context_source=%s center_region=%d pawn_region=%d job_region=%d"
			% [
				GameManager.tick_count,
				st_source,
				effective_center_region,
				pawn_region,
				job_region,
			]
		)
	var spec_phase: String = str(st.get("specialization_phase", SettlementMemory.SPECIALIZATION_PHASE_UNKNOWN))
	var spec_locked: String = str(st.get("specialization_channel", ""))
	var spec_candidate: String = str(st.get("specialization_candidate_channel", ""))
	if st.is_empty() or spec_phase == SettlementMemory.SPECIALIZATION_PHASE_UNKNOWN:
		_pawn_divergence_skip_no_specialization_context += 1
		_pawn_divergence_no_spec_by_center[effective_center_region] = int(
			_pawn_divergence_no_spec_by_center.get(effective_center_region, 0)
		) + 1
		_pawn_divergence_no_spec_by_phase[spec_phase] = int(
			_pawn_divergence_no_spec_by_phase.get(spec_phase, 0)
		) + 1
		var settlement_found: bool = not st.is_empty()
		var committed_state: String = str(st.get("state", ""))
		var current_intent: String = str(st.get("current_intent", ""))
		var skip_line_no_spec: String = (
			(
                "[PAWN_DIVERGENCE_SKIP] tick=%d action=claim reason=no_specialization_context pawn_id=%d pawn=%s "
				+ "pawn_center_region=%d job_center_region=%d center_region=%d spec_phase=%s "
				+ "settlement_found=%s committed_state=%s current_intent=%s spec_locked=%s spec_candidate=%s"
			)
			% [
				GameManager.tick_count,
				int(pawn.data.id),
				pawn.data.display_name,
				pawn_center_region,
				job_center_region,
				effective_center_region,
				spec_phase,
				settlement_found,
				committed_state,
				current_intent,
				spec_locked,
				spec_candidate,
			]
		)
		if _pawn_divergence_detail_logs_enabled():
			print(skip_line_no_spec)
		return
	var job_channel: String = _job_channel_for_divergence_log(job.type)
	var alignment: String = "neutral"
	if job_channel == spec_locked:
		alignment = "aligned"
	elif job_channel == "" or spec_locked == "":
		alignment = "neutral"
	else:
		alignment = "divergent"
	var pawn_id: int = int(pawn.data.id)
	var prev_label: String = str(_pawn_divergence_last_job_by_pawn_id.get(pawn_id, "None"))
	var next_label: String = Job.describe_type(job.type)
	_pawn_divergence_last_job_by_pawn_id[pawn_id] = next_label
	_pawn_divergence_scored_events += 1
	var center_row: Dictionary = _pawn_divergence_by_center.get(
		effective_center_region,
		{"scored": 0, "aligned": 0, "divergent": 0, "neutral": 0}
	)
	center_row["scored"] = int(center_row.get("scored", 0)) + 1
	match alignment:
		"aligned":
			_pawn_divergence_aligned_total += 1
			center_row["aligned"] = int(center_row.get("aligned", 0)) + 1
		"divergent":
			_pawn_divergence_divergent_total += 1
			center_row["divergent"] = int(center_row.get("divergent", 0)) + 1
		_:
			_pawn_divergence_neutral_total += 1
			center_row["neutral"] = int(center_row.get("neutral", 0)) + 1
	_pawn_divergence_by_center[effective_center_region] = center_row
	if _pawn_divergence_first_scored_center_region < 0:
		_pawn_divergence_first_scored_center_region = effective_center_region
	var scored_line: String = (
		(
            "[PAWN_DIVERGENCE] tick=%d action=claim pawn_id=%d pawn=%s "
			+ "pawn_center_region=%d job_center_region=%d center_region=%d "
			+ "spec_phase=%s spec_locked=%s spec_candidate=%s "
			+ "job_from=%s job_to=%s job_channel=%s alignment=%s"
		)
		% [
			GameManager.tick_count,
			pawn_id,
			pawn.data.display_name,
			pawn_center_region,
			job_center_region,
			effective_center_region,
			spec_phase,
			spec_locked,
			spec_candidate,
			prev_label,
			next_label,
			job_channel,
			alignment,
		]
	)
	if _pawn_divergence_detail_logs_enabled():
		print(scored_line)
	if _pawn_divergence_first20_scored_lines.size() < 20:
		_pawn_divergence_first20_scored_lines.append(scored_line)


func _emit_pawn_divergence_summary_if_needed(tick: int, force_exit: bool = false) -> void:
	if not _pawn_divergence_validation_logs_enabled():
		return
	if force_exit:
		if _pawn_divergence_exit_summary_emitted:
			return
		_pawn_divergence_exit_summary_emitted = true
	else:
		var milestone: bool = false
		for mt in SimTime.divergence_milestone_ticks():
			if tick == mt:
				milestone = true
				break
		if not milestone:
			return
		if _pawn_divergence_summary_emitted_ticks.has(tick):
			return
		_pawn_divergence_summary_emitted_ticks[tick] = true
	var emit_reason: String = "exit_tree" if force_exit else ("tick_%d" % tick)
	print("[PAWN_DIVERGENCE_SUMMARY]")
	print("[PAWN_DIVERGENCE_SCHEMA] packet_schema_version=%d" % PAWN_DIVERGENCE_PACKET_SCHEMA_VERSION)
	print("[PAWN_DIVERGENCE_EMIT] tick=%d reason=%s" % [tick, emit_reason])
	print("tick=%d" % tick)
	print("total_claim_events_seen=%d" % _pawn_divergence_total_claim_events_seen)
	print("scored_events=%d" % _pawn_divergence_scored_events)
	print("skip_pre_settlement_context=%d" % _pawn_divergence_skip_pre_settlement_context)
	print("skip_no_bound_center=%d" % _pawn_divergence_skip_no_bound_center)
	print("skip_no_specialization_context=%d" % _pawn_divergence_skip_no_specialization_context)
	print("aligned_total=%d" % _pawn_divergence_aligned_total)
	print("divergent_total=%d" % _pawn_divergence_divergent_total)
	print("neutral_total=%d" % _pawn_divergence_neutral_total)
	print("native_bound_events=%d" % _pawn_divergence_native_bound_events)
	print("fallback_bound_events=%d" % _pawn_divergence_fallback_bound_events)
	print("first_scored_center_region=%d" % _pawn_divergence_first_scored_center_region)
	print("scored_events_present=%s" % ("true" if _pawn_divergence_scored_events > 0 else "false"))
	var context_sources: Array = _pawn_divergence_context_source_counts.keys()
	context_sources.sort()
	for source_any in context_sources:
		var source: String = str(source_any)
		print(
            "[PAWN_DIVERGENCE_CONTEXT_SUMMARY] source=%s claims=%d"
			% [source, int(_pawn_divergence_context_source_counts.get(source, 0))]
		)
	var ctx_total: int = 0
	var ctx_none: int = 0
	var ctx_center_region: int = 0
	var ctx_job_region_membership: int = 0
	var ctx_pawn_region_membership: int = 0
	var ctx_unknown: int = 0
	for source_any in context_sources:
		var source_name: String = str(source_any)
		var source_count: int = int(_pawn_divergence_context_source_counts.get(source_name, 0))
		ctx_total += source_count
		if source_name == "none":
			ctx_none += source_count
		elif source_name == "center_region":
			ctx_center_region += source_count
		elif source_name == "job_region_membership":
			ctx_job_region_membership += source_count
		elif source_name == "pawn_region_membership":
			ctx_pawn_region_membership += source_count
		else:
			ctx_unknown += source_count
	var native_bound_total: int = _pawn_divergence_native_bound_events
	var fallback_bound_total: int = _pawn_divergence_fallback_bound_events
	var bind_total: int = native_bound_total + fallback_bound_total
	var native_rate: float = 0.0
	var fallback_rate: float = 0.0
	if bind_total > 0:
		native_rate = float(native_bound_total) / float(bind_total)
		fallback_rate = float(fallback_bound_total) / float(bind_total)
	var ctx_center_rate: float = 0.0
	var ctx_job_rate: float = 0.0
	var ctx_pawn_rate: float = 0.0
	var ctx_none_rate: float = 0.0
	if ctx_total > 0:
		ctx_center_rate = float(ctx_center_region) / float(ctx_total)
		ctx_job_rate = float(ctx_job_region_membership) / float(ctx_total)
		ctx_pawn_rate = float(ctx_pawn_region_membership) / float(ctx_total)
		ctx_none_rate = float(ctx_none) / float(ctx_total)
	print(
		(
            "[PAWN_DIVERGENCE_BINDING_MIX] tick=%d native=%d fallback=%d native_rate=%.3f fallback_rate=%.3f "
			+ "ctx_center_rate=%.3f ctx_job_rate=%.3f ctx_pawn_rate=%.3f ctx_none_rate=%.3f ctx_unknown=%d"
		)
		% [
			tick,
			native_bound_total,
			fallback_bound_total,
			native_rate,
			fallback_rate,
			ctx_center_rate,
			ctx_job_rate,
			ctx_pawn_rate,
			ctx_none_rate,
			ctx_unknown,
		]
	)
	var scored_present: bool = _pawn_divergence_scored_events > 0
	var any_bound: bool = (_pawn_divergence_native_bound_events + _pawn_divergence_fallback_bound_events) > 0
	var no_spec_rate: float = 0.0
	if _pawn_divergence_total_claim_events_seen > 0:
		no_spec_rate = float(_pawn_divergence_skip_no_specialization_context) / float(
			_pawn_divergence_total_claim_events_seen
		)
	var fallback_dominant: bool = bind_total > 0 and fallback_rate >= 0.5
	var context_none_present: bool = ctx_none > 0
	var high_no_spec_rate: bool = no_spec_rate >= 0.5
	var pre_settlement_only: bool = (
		_pawn_divergence_skip_pre_settlement_context > 0
		and _pawn_divergence_scored_events == 0
		and _pawn_divergence_skip_no_bound_center == 0
	)
	print(
		(
            "[PAWN_DIVERGENCE_ALERTS] tick=%d fallback_dominant=%s context_none_present=%s "
			+ "high_no_spec_rate=%s pre_settlement_only=%s"
		)
		% [
			tick,
			"true" if fallback_dominant else "false",
			"true" if context_none_present else "false",
			"true" if high_no_spec_rate else "false",
			"true" if pre_settlement_only else "false",
		]
	)
	var next_action: String = "none"
	var next_action_detail: String = "healthy_or_observe"
	if pre_settlement_only:
		next_action = "observe_until_settlement_forms"
		next_action_detail = "claims_precede_valid_settlement_context"
	elif not scored_present and any_bound:
		next_action = "inspect_specialization_context"
		next_action_detail = "bound_claims_exist_but_not_scored"
	elif not scored_present:
		next_action = "inspect_claim_time_binding_path"
		next_action_detail = "no_scored_events_and_no_stable_bound_path"
	elif high_no_spec_rate:
		next_action = "audit_specialization_population_path"
		next_action_detail = "high_no_specialization_context_rate"
	elif context_none_present:
		next_action = "audit_context_resolution_chain"
		next_action_detail = "context_source_none_detected"
	elif fallback_dominant:
		next_action = "stabilize_fast_map_coverage"
		next_action_detail = "fallback_path_is_dominant"
	print(
        "[PAWN_DIVERGENCE_NEXT_ACTION] tick=%d action=%s detail=%s"
		% [tick, next_action, next_action_detail]
	)
	var binding_quality: String = "FAIL"
	var binding_reason: String = "no_bound_or_scored_events"
	if scored_present:
		binding_quality = "PASS"
		binding_reason = "scored_events_present"
		if high_no_spec_rate:
			binding_quality = "WARN"
			binding_reason = "high_no_specialization_rate"
		elif context_none_present:
			binding_quality = "WARN"
			binding_reason = "context_resolution_gaps"
	print(
		(
            "[PAWN_DIVERGENCE_BINDING_QUALITY] tick=%d result=%s reason=%s "
			+ "ctx_none=%d ctx_total=%d no_spec_rate=%.3f scored_events=%d"
		)
		% [
			tick,
			binding_quality,
			binding_reason,
			ctx_none,
			ctx_total,
			no_spec_rate,
			_pawn_divergence_scored_events,
		]
	)
	var scored_bucket_sum: int = (
		_pawn_divergence_aligned_total + _pawn_divergence_divergent_total + _pawn_divergence_neutral_total
	)
	var skip_bucket_sum: int = (
		_pawn_divergence_skip_pre_settlement_context
		+ _pawn_divergence_skip_no_bound_center
		+ _pawn_divergence_skip_no_specialization_context
	)
	var center_scored_sum: int = 0
	for row_any in _pawn_divergence_by_center.values():
		var row: Dictionary = row_any as Dictionary
		center_scored_sum += int(row.get("scored", 0))
	var claim_resolution_total: int = _pawn_divergence_scored_events + skip_bucket_sum
	var invariant_ok: bool = true
	var invariant_reason: String = "ok"
	if scored_bucket_sum != _pawn_divergence_scored_events:
		invariant_ok = false
		invariant_reason = "scored_bucket_mismatch"
	elif center_scored_sum != _pawn_divergence_scored_events:
		invariant_ok = false
		invariant_reason = "center_scored_mismatch"
	elif claim_resolution_total != _pawn_divergence_total_claim_events_seen:
		invariant_ok = false
		invariant_reason = "claim_resolution_mismatch"
	print(
		(
            "[PAWN_DIVERGENCE_INVARIANT] tick=%d pass=%s reason=%s total_claims=%d resolved_claims=%d "
			+ "scored=%d scored_bucket_sum=%d center_scored_sum=%d skip_bucket_sum=%d"
		)
		% [
			tick,
			"true" if invariant_ok else "false",
			invariant_reason,
			_pawn_divergence_total_claim_events_seen,
			claim_resolution_total,
			_pawn_divergence_scored_events,
			scored_bucket_sum,
			center_scored_sum,
			skip_bucket_sum,
		]
	)
	var fingerprint: String = (
        "t=%d|tc=%d|sc=%d|al=%d|dv=%d|nt=%d|sp=%d|nb=%d|ns=%d|bn=%d|bf=%d|cn=%d|ct=%d|q=%s|r=%s|a=%s|inv=%s"
		% [
			tick,
			_pawn_divergence_total_claim_events_seen,
			_pawn_divergence_scored_events,
			_pawn_divergence_aligned_total,
			_pawn_divergence_divergent_total,
			_pawn_divergence_neutral_total,
			_pawn_divergence_skip_pre_settlement_context,
			_pawn_divergence_skip_no_bound_center,
			_pawn_divergence_skip_no_specialization_context,
			native_bound_total,
			fallback_bound_total,
			ctx_none,
			ctx_total,
			binding_quality,
			binding_reason,
			next_action,
			"1" if invariant_ok else "0",
		]
	)
	print("[PAWN_DIVERGENCE_FINGERPRINT] %s" % fingerprint)
	var gate_scored_present: bool = _pawn_divergence_scored_events > 0
	var gate_has_any_bound: bool = (_pawn_divergence_native_bound_events + _pawn_divergence_fallback_bound_events) > 0
	var gate_no_bound_center_zero: bool = _pawn_divergence_skip_no_bound_center == 0
	var gate_invariant_ok: bool = invariant_ok
	var gates_pass: bool = (
		gate_scored_present
		and gate_has_any_bound
		and gate_no_bound_center_zero
		and gate_invariant_ok
	)
	print(
		(
            "[PAWN_DIVERGENCE_GATES] tick=%d pass=%s scored_present=%s has_any_bound=%s "
			+ "no_bound_center_zero=%s invariant_ok=%s"
		)
		% [
			tick,
			"true" if gates_pass else "false",
			"true" if gate_scored_present else "false",
			"true" if gate_has_any_bound else "false",
			"true" if gate_no_bound_center_zero else "false",
			"true" if gate_invariant_ok else "false",
		]
	)
	var go_no_go: String = "BLOCK"
	var go_reason: String = "gates_failed"
	if gates_pass:
		go_no_go = "GO"
		go_reason = "core_gates_passed"
		if fallback_dominant or context_none_present or high_no_spec_rate:
			go_no_go = "HOLD"
			go_reason = "quality_alerts_present"
	elif pre_settlement_only:
		go_no_go = "HOLD"
		go_reason = "pre_settlement_only"
	print(
        "[PAWN_DIVERGENCE_GO_NO_GO] tick=%d decision=%s reason=%s"
		% [tick, go_no_go, go_reason]
	)
	var packet_center_fingerprint: String = _build_pawn_divergence_center_fingerprint()
	var packet_basis: String = (
        "s=%d|t=%d|er=%s|d=%s|dr=%s|q=%s|qr=%s|gp=%s|fd=%s|cn=%s|hn=%s|ps=%s|fp=%s|cfp=%s"
		% [
			PAWN_DIVERGENCE_PACKET_SCHEMA_VERSION,
			tick,
			emit_reason,
			go_no_go,
			go_reason,
			binding_quality,
			binding_reason,
			"1" if gates_pass else "0",
			"1" if fallback_dominant else "0",
			"1" if context_none_present else "0",
			"1" if high_no_spec_rate else "0",
			"1" if pre_settlement_only else "0",
			fingerprint,
			packet_center_fingerprint,
		]
	)
	var packet_id: int = packet_basis.hash()
	print(
		(
            "[PAWN_DIVERGENCE_PACKET] schema=%d tick=%d emit_reason=%s packet_id=%d decision=%s decision_reason=%s quality=%s quality_reason=%s "
			+ "gates_pass=%s alerts=fallback_dominant:%s,context_none_present:%s,high_no_spec_rate:%s,pre_settlement_only:%s "
			+ "fingerprint=%s center_fingerprint=%s"
		)
		% [
			PAWN_DIVERGENCE_PACKET_SCHEMA_VERSION,
			tick,
			emit_reason,
			packet_id,
			go_no_go,
			go_reason,
			binding_quality,
			binding_reason,
			"true" if gates_pass else "false",
			"true" if fallback_dominant else "false",
			"true" if context_none_present else "false",
			"true" if high_no_spec_rate else "false",
			"true" if pre_settlement_only else "false",
			fingerprint,
			packet_center_fingerprint,
		]
	)
	print(
		(
            "[PAWN_DIVERGENCE_STATE] tick=%d total_claims=%d scored=%d aligned=%d divergent=%d neutral=%d "
			+ "pre_settlement_skips=%d no_bound_skips=%d no_spec_skips=%d native_bound=%d fallback_bound=%d "
			+ "ctx_total=%d ctx_none=%d quality=%s quality_reason=%s next_action=%s"
		)
		% [
			tick,
			_pawn_divergence_total_claim_events_seen,
			_pawn_divergence_scored_events,
			_pawn_divergence_aligned_total,
			_pawn_divergence_divergent_total,
			_pawn_divergence_neutral_total,
			_pawn_divergence_skip_pre_settlement_context,
			_pawn_divergence_skip_no_bound_center,
			_pawn_divergence_skip_no_specialization_context,
			native_bound_total,
			fallback_bound_total,
			ctx_total,
			ctx_none,
			binding_quality,
			binding_reason,
			next_action,
		]
	)
	var health: String = "FAIL"
	if scored_present:
		health = "PASS"
	elif any_bound:
		health = "WARN"
	print(
		(
            "[PAWN_DIVERGENCE_HEALTH] tick=%d result=%s any_bound=%s scored_events_present=%s "
			+ "pre_settlement_skips=%d no_bound_center_skips=%d no_spec_skips=%d"
		)
		% [
			tick,
			health,
			any_bound,
			scored_present,
			_pawn_divergence_skip_pre_settlement_context,
			_pawn_divergence_skip_no_bound_center,
			_pawn_divergence_skip_no_specialization_context,
		]
	)
	var no_spec_centers: Array = _pawn_divergence_no_spec_by_center.keys()
	no_spec_centers.sort()
	for c_any in no_spec_centers:
		var c: int = int(c_any)
		print(
            "[PAWN_DIVERGENCE_NO_SPEC_SUMMARY] center_region=%d skips=%d"
			% [c, int(_pawn_divergence_no_spec_by_center.get(c, 0))]
		)
	var no_spec_phases: Array = _pawn_divergence_no_spec_by_phase.keys()
	no_spec_phases.sort()
	for phase_any in no_spec_phases:
		var phase: String = str(phase_any)
		print(
            "[PAWN_DIVERGENCE_NO_SPEC_PHASE_SUMMARY] spec_phase=%s skips=%d"
			% [phase, int(_pawn_divergence_no_spec_by_phase.get(phase, 0))]
		)
	var centers: Array = _pawn_divergence_by_center.keys()
	centers.sort()
	for c_any in centers:
		var c: int = int(c_any)
		var row: Dictionary = _pawn_divergence_by_center.get(c, {})
		print(
            "[PAWN_DIVERGENCE_CENTER_SUMMARY] center_region=%d scored=%d aligned=%d divergent=%d neutral=%d"
			% [
				c,
				int(row.get("scored", 0)),
				int(row.get("aligned", 0)),
				int(row.get("divergent", 0)),
				int(row.get("neutral", 0)),
			]
		)
	var center_digest_parts: PackedStringArray = PackedStringArray()
	for c_any in centers:
		var c: int = int(c_any)
		var row: Dictionary = _pawn_divergence_by_center.get(c, {})
		center_digest_parts.append(
            "%d:%d,%d,%d,%d"
			% [
				c,
				int(row.get("scored", 0)),
				int(row.get("aligned", 0)),
				int(row.get("divergent", 0)),
				int(row.get("neutral", 0)),
			]
		)
	var center_fingerprint: String = ";".join(center_digest_parts)
	if center_fingerprint == "":
		center_fingerprint = "none"
	print(
        "[PAWN_DIVERGENCE_CENTER_FINGERPRINT] tick=%d centers=%d digest=%s"
		% [tick, centers.size(), center_fingerprint]
	)
	print("[PAWN_DIVERGENCE_FIRST20_BEGIN]")
	for line in _pawn_divergence_first20_scored_lines:
		print(str(line))
	print("[PAWN_DIVERGENCE_FIRST20_END]")
	var proof_center_region: int = _pawn_divergence_first_scored_center_region
	if proof_center_region < 0:
		proof_center_region = 524295
	var proof_row: Dictionary = _pawn_divergence_by_center.get(proof_center_region, {})
	var proof_scored: int = int(proof_row.get("scored", 0))
	print(
        "[PAWN_DIVERGENCE_PROOF] center_region=%d scored_events_present=%s"
		% [proof_center_region, "true" if proof_scored > 0 else "false"]
	)


func _process(delta: float) -> void:
	if _is_simulation_worker_mode():
		return
	# Frame-time monitor: log every 5 seconds if FPS drops below 50
	_frame_time_samples += 1
	_frame_time_accum += delta
	if _frame_time_accum >= 5.0:
		var avg_fps: float = float(_frame_time_samples) / _frame_time_accum
		if avg_fps < 50.0 and OS.is_debug_build():
			var tick_batch_ms: float = float(TickManager.debug_last_tick_batch_usec) / 1000.0
			var job_count: int = JobManager.stats().get("active", 0) if JobManager != null else 0
			print("[PERF] avg_fps=%.0f over %.1fs | tick_batch=%.1fms | pawns=%d jobs=%d settlements=%d proto_sites=%d" % [
				avg_fps, _frame_time_accum, tick_batch_ms,
				_pawn_spawner.pawns.size() if _pawn_spawner != null else 0,
				job_count,
				SettlementMemory.get_formal_settlement_count() if SettlementMemory != null else 0,
				SettlementMemory.get_proto_sites().size() if SettlementMemory != null else 0
			])
		_frame_time_samples = 0
		_frame_time_accum = 0.0
	_meaning_ambient_mood = lerpf(
		_meaning_ambient_mood, _get_meaning_ambient_mood_target(), minf(1.0, delta * MEANING_AMBIENT_SMOOTH)
	)
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		_camera_follow_selected = false
	if (
			_camera_follow_selected
			and _selected_pawn != null
			and is_instance_valid(_selected_pawn)
			and _camera != null
	):
		var tgt: Vector2 = _selected_pawn.global_position
		_camera.global_position = _camera.global_position.lerp(
				tgt, clampf(delta * 8.0, 0.0, 1.0)
		)
	else:
		_update_camera_meaning_bias(delta)
	if (
			_player_pawn != null
			and is_instance_valid(_player_pawn)
			and _camera != null
			and _camera.has_method("clamp_position_to_world")
			and is_instance_valid(_world)
	):
		_camera.call("clamp_position_to_world", _world, 48.0)
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _ambient_audio_last_update_ms >= AMBIENT_AUDIO_UPDATE_INTERVAL_MS:
		_ambient_audio_last_update_ms = now_ms
		_update_ambient_audio(delta)
	_update_meaning_vignette()
	_trace_redraw_timer += delta
	if _trace_redraw_timer >= TRACE_REDRAW_INTERVAL_SEC:
		_trace_redraw_timer = 0.0
		if has_node("WorldTrace"):
			$WorldTrace.queue_redraw()


func _ensure_avatar_panel() -> void:
	if _avatar_panel != null and is_instance_valid(_avatar_panel):
		return
	var scr: Script = load("res://scripts/ui/PlayerAvatarPanel.gd") as Script
	if scr == null:
		return
	_avatar_panel = scr.new() as Node
	_avatar_panel.name = "PlayerAvatarPanel"
	var ui_vp: Node = get_node_or_null("UI_Viewport")
	if ui_vp != null:
		ui_vp.add_child(_avatar_panel)
	else:
		add_child(_avatar_panel)


func _toggle_avatar_panel() -> void:
	_ensure_avatar_panel()
	if _avatar_panel == null:
		return
	if _avatar_panel.visible:
		_avatar_panel.close_panel()
		return
	var target: HeelKawnian = _player_pawn
	if target == null or not is_instance_valid(target):
		target = _selected_pawn
	if target != null and is_instance_valid(target) and target.data != null:
		_avatar_panel.open_for_pawn(target)
	elif OS.is_debug_build():
		print("[Main] Sprite panel: select a pawn first (click on map)")


func _toggle_consciousness_panel() -> void:
	_ensure_consciousness_panel()
	if _consciousness_panel == null:
		return
	if _consciousness_panel.visible:
		_consciousness_panel.close_panel()
		return
	_consciousness_panel.open_for_player("player")


func _ensure_consciousness_panel() -> void:
	if _consciousness_panel != null and is_instance_valid(_consciousness_panel):
		return
	var ui_vp: Node = get_node_or_null("UI_Viewport")
	var scr = load("res://scripts/ui/PlayerConsciousnessPanel.gd")
	_consciousness_panel = scr.new() as Node
	_consciousness_panel.name = "PlayerConsciousnessPanel"
	if ui_vp != null:
		ui_vp.add_child(_consciousness_panel)
	else:
		add_child(_consciousness_panel)


func _toggle_dialogue_panel() -> void:
	if _selected_pawn == null or not is_instance_valid(_selected_pawn):
		return
	_ensure_dialogue_panel()
	if _dialogue_panel == null:
		return
	if _dialogue_panel.visible:
		_dialogue_panel.close_panel()
		return
	var pawn_id: int = int(_selected_pawn.data.id) if _selected_pawn.data != null else -1
	var pawn_name: String = _selected_pawn.data.display_name if _selected_pawn.data != null and _selected_pawn.data.has("display_name") else "Pawn"
	_dialogue_panel.open_for_pawn(pawn_id, pawn_name)

func _ensure_dialogue_panel() -> void:
	if _dialogue_panel != null and is_instance_valid(_dialogue_panel):
		return
	var ui_vp: Node = get_node_or_null("UI_Viewport")
	var scr = load("res://scripts/ui/PawnDialoguePanel.gd")
	_dialogue_panel = scr.new() as Node
	_dialogue_panel.name = "PawnDialoguePanel"
	if ui_vp != null:
		ui_vp.add_child(_dialogue_panel)
	else:
		add_child(_dialogue_panel)

func _toggle_settlement_mind_panel() -> void:
	if _selected_pawn == null or not is_instance_valid(_selected_pawn):
		return
	var d = _selected_pawn.data
	if d == null:
		return
	_ensure_settlement_mind_panel()
	if _settlement_mind_panel == null:
		return
	if _settlement_mind_panel.visible:
		_settlement_mind_panel.close_panel()
		return
	var sm: Node = get_node_or_null("/root/SettlementMemory")
	if sm == null:
		return
	var st_rk: int = WorldMemory._region_key(d.tile_pos.x, d.tile_pos.y) if WorldMemory != null else -1
	var st_center: int = sm.get_center_region_for_region(st_rk) if sm.has_method("get_center_region_for_region") else -1
	if st_center < 0:
		return
	_settlement_mind_panel.open_for_settlement(st_center)

func _ensure_settlement_mind_panel() -> void:
	if _settlement_mind_panel != null and is_instance_valid(_settlement_mind_panel):
		return
	var ui_vp: Node = get_node_or_null("UI_Viewport")
	var scr = load("res://scripts/ui/SettlementMindPanel.gd")
	_settlement_mind_panel = scr.new() as Node
	_settlement_mind_panel.name = "SettlementMindPanel"
	if ui_vp != null:
		ui_vp.add_child(_settlement_mind_panel)
	else:
		add_child(_settlement_mind_panel)

func _ensure_incarnation_picker() -> void:
	if _incarnation_picker != null and is_instance_valid(_incarnation_picker):
		return
	var ui_vp: Node = get_node_or_null("UI_Viewport")
	_incarnation_picker = INCARNATION_PICKER_SCRIPT.new()
	_incarnation_picker.name = "IncarnationPicker"
	if _incarnation_picker.has_signal("entry_confirmed"):
		_incarnation_picker.connect("entry_confirmed", Callable(self, "_on_incarnation_entry_confirmed"))
	if _incarnation_picker.has_signal("closed"):
		_incarnation_picker.connect("closed", Callable(self, "_on_incarnation_picker_closed"))
	if ui_vp != null:
		ui_vp.add_child(_incarnation_picker)
	else:
		add_child(_incarnation_picker)


func _toggle_incarnation_picker() -> void:
	_ensure_incarnation_picker()
	if _incarnation_picker == null:
		return
	if _incarnation_picker.visible:
		_incarnation_picker.call("close_picker")
		_sync_player_context_ui()
		return
	var candidates: Array = _incarnation_candidates_snapshot()
	if candidates.is_empty():
		if OS.is_debug_build():
			print("[Main] Incarnation picker: no eligible living pawns")
		return
	_incarnation_picker.call("open_with_candidates", candidates, get_player_mode_label())
	_sync_player_context_ui()


func _incarnation_candidates_snapshot() -> Array:
	var out: Array = []
	if _pawn_spawner == null:
		return out
	for p in _pawn_spawner.pawns:
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		var d: HeelKawnianData = p.data
		var rk: int = _WM._region_key(d.tile_pos.x, d.tile_pos.y)
		var center_region: int = SettlementMemory.get_center_region_for_region(rk)
		var settlement_state: String = SettlementMemory.get_state_at_region(center_region if center_region >= 0 else rk)
		var region_reputation: int = CulturalMemory.get_region_reputation(center_region if center_region >= 0 else rk)
		var state_name: String = p.get_state_name() if p.has_method("get_state_name") else "Unknown"
		var current_job: String = p.get_current_job_label() if p.has_method("get_current_job_label") else "None"
		var age_value: int = int(d.age)
		var life_stage: String = "child"
		if age_value >= 60:
			life_stage = "elder"
		elif age_value >= 18:
			life_stage = "adult"
		elif age_value >= 13:
			life_stage = "teen"
		var region_label: int = center_region if center_region >= 0 else rk
		var priority_score: int = _incarnation_candidate_priority(d, life_stage, settlement_state, region_reputation)
		out.append({
			"pawn_id": int(d.id),
			"name": d.display_name,
			"age": age_value,
			"life_stage": life_stage,
			"region": region_label,
			"settlement_state": settlement_state,
			"region_reputation": region_reputation,
			"profession": d.profession_name(),
			"role": current_job,
			"state": state_name,
			"hunger": float(d.hunger),
			"rest": float(d.rest),
			"mood": float(d.mood),
			"priority_score": priority_score,
			"priority_reason": _incarnation_candidate_reason(life_stage, settlement_state, region_reputation, int(d.children_count), int(d.parent_a_id), int(d.parent_b_id), int(d.current_profession)),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ascore: int = int(a.get("priority_score", 0))
		var bscore: int = int(b.get("priority_score", 0))
		if ascore != bscore:
			return ascore > bscore
		var aid: int = int(a.get("pawn_id", -1))
		var bid: int = int(b.get("pawn_id", -1))
		if aid == bid:
			return false
		return aid < bid
	)
	return out


func _incarnation_candidate_priority(d: HeelKawnianData, life_stage: String, settlement_state: String, region_reputation: int) -> int:
	var score: int = 0
	match life_stage:
		"elder":
			score += 35
		"adult":
			score += 50
		"teen":
			score += 28
		_:
			score += 12
	match settlement_state:
		"active":
			score += 40
		"revivable":
			score += 32
		"recovering":
			score += 18
		"dormant":
			score += 8
		"abandoned":
			score -= 12
		"permanently_abandoned":
			score -= 24
		_:
			score += 0
	score += clampi(region_reputation, -3, 3) * 8
	if int(d.current_profession) != HeelKawnianData.Profession.NONE:
		score += 6
	if int(d.children_count) > 0:
		score += 6
	if int(d.parent_a_id) >= 0 or int(d.parent_b_id) >= 0:
		score += 4
	return score


func _incarnation_candidate_reason(life_stage: String, settlement_state: String, region_reputation: int, children_count: int, parent_a_id: int, parent_b_id: int, profession: int) -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append(life_stage)
	if not settlement_state.is_empty():
		parts.append(settlement_state)
	var rep: String = "rep %+d" % region_reputation
	parts.append(rep)
	if profession != HeelKawnianData.Profession.NONE:
		parts.append("profession-tied")
	if children_count > 0:
		parts.append("has-children")
	if parent_a_id >= 0 or parent_b_id >= 0:
		parts.append("lineage-bound")
	return ", ".join(parts)


func _on_incarnation_entry_confirmed(pawn_id: int) -> void:
	if pawn_id < 0:
		request_spectator_return("picker_cancel")
		return
	var pawn: HeelKawnian = _find_pawn_by_id(pawn_id)
	if pawn == null:
		if OS.is_debug_build():
			print("[Main] Incarnation picker: pawn %d not found" % pawn_id)
		return
	_player_pawn = pawn
	_set_selected_pawn(pawn)
	_camera_follow_selected = true
	_set_player_mode(PlayerMode.INCARNATED)
	PlayerIntentQueue.request_incarnation_entry("picker_confirm", {"pawn_id": pawn_id})
	if _incarnation_picker != null and is_instance_valid(_incarnation_picker):
		_incarnation_picker.call("close_picker")
	if IncarnationManager != null:
		IncarnationManager.on_player_incarnated("player", pawn_id)


func _on_incarnation_picker_closed() -> void:
	_sync_player_context_ui()


func _sync_player_context_ui() -> void:
	if _info_panel != null and is_instance_valid(_info_panel) and _info_panel.has_method("set_player_context"):
		_info_panel.call("set_player_context", get_player_mode_label(), get_player_pawn_id(), _incarnation_picker != null and is_instance_valid(_incarnation_picker) and _incarnation_picker.visible)


func _update_hud_mode_badge() -> void:
	if _hud != null and is_instance_valid(_hud) and _hud.has_method("set_player_mode_badge"):
		var rank: String = _get_player_authority_rank() if _player_mode == PlayerMode.INCARNATED else ""
		_hud.set_player_mode_badge(get_player_mode_label(), rank)


func _set_player_mode(mode: int) -> void:
	if _player_mode == mode:
		return
	_player_mode = mode
	_sync_player_context_ui()
	_update_hud_mode_badge()
	_update_ui_for_player_mode()
	if OS.is_debug_build():
		print("[Main] Player mode: %s" % get_player_mode_label())


func get_player_mode_label() -> String:
	match _player_mode:
		PlayerMode.INCARNATED:
			return "INCARNATED"
		PlayerMode.OBSERVER:
			return "OBSERVER"
		_:
			return "WATCH"


func is_player_incarnated() -> bool:
	return _player_mode == PlayerMode.INCARNATED


func is_player_observer() -> bool:
	return _player_mode == PlayerMode.OBSERVER


func _is_watch_mode() -> bool:
	return _player_mode == PlayerMode.SPECTATOR


## Ctrl+G: toggle between SPECTATOR and OBSERVER mode.
func _toggle_observer_mode() -> void:
	if _player_mode == PlayerMode.OBSERVER:
		_set_player_mode(PlayerMode.SPECTATOR)
		_player_pawn = null
		_set_selected_pawn(null)
		if OS.is_debug_build():
			print("[Main] Observer mode OFF — returning to spectator")
	else:
		if _player_mode == PlayerMode.INCARNATED:
			if IncarnationManager != null:
				IncarnationManager.on_player_returned("player")
			_player_pawn = null
			_set_selected_pawn(null)
		_set_player_mode(PlayerMode.OBSERVER)
		_player_pawn = null
		if OS.is_debug_build():
			print("[Main] Observer mode ON — full command authority")


## Ctrl+T: toggle between SPECTATOR and INCARNATED mode.
func _toggle_incarnation_mode() -> void:
	if _player_mode == PlayerMode.INCARNATED:
		if IncarnationManager != null:
			IncarnationManager.on_player_returned("player")
		_set_player_mode(PlayerMode.SPECTATOR)
		_player_pawn = null
		_set_selected_pawn(null)
		if OS.is_debug_build():
			print("[Main] Incarnation released — returning to spectator")
	else:
		_open_incarnation_picker()


func request_incarnation_entry(note: String = "manual_entry", payload: Dictionary = {}) -> bool:
	_toggle_incarnation_picker()
	return _incarnation_picker != null and is_instance_valid(_incarnation_picker) and bool(_incarnation_picker.visible)


## Can the player command a specific pawn?
## Observer mode = yes. Watch/Sprite modes = no.
func _can_command_pawn(target: HeelKawnian) -> bool:
	if target == null or not is_instance_valid(target) or target.data == null:
		return false
	return _player_mode == PlayerMode.OBSERVER


## Get the player's authority rank label for HUD display.
func _get_player_authority_rank() -> String:
	if _player_mode != PlayerMode.INCARNATED:
		return ""
	if _player_pawn == null or not is_instance_valid(_player_pawn) or _player_pawn.data == null:
		return ""
	if AuthoritySystem == null:
		return "HeelKawnian"
	var pid: int = _player_pawn.data.id
	var mil: float = AuthoritySystem.get_authority_level(pid, AuthoritySystem.AuthorityContext.MILITARY)
	var civ: float = AuthoritySystem.get_authority_level(pid, AuthoritySystem.AuthorityContext.CIVIL)
	var high_contexts: int = 0
	if mil >= 0.5:
		high_contexts += 1
	if civ >= 0.5:
		high_contexts += 1
	if high_contexts >= 2:
		return "Ruler"
	if mil >= 0.3:
		return "Captain"
	if civ >= 0.3:
		return "Elder"
	return "HeelKawnian"


func request_spectator_return(note: String = "manual_return", payload: Dictionary = {}) -> bool:
	var ok: bool = PlayerIntentQueue.request_spectator_return(note, payload)
	if _incarnation_picker != null and is_instance_valid(_incarnation_picker):
		_incarnation_picker.call("close_picker")
	if _player_mode == PlayerMode.INCARNATED and IncarnationManager != null:
		IncarnationManager.on_player_returned("player")
	_set_selected_pawn(null)
	if _player_pawn == null or not is_instance_valid(_player_pawn) or _player_pawn.data == null:
		_player_pawn = _first_live_pawn()
	_set_player_mode(PlayerMode.SPECTATOR)
	_update_ui_for_player_mode()
	return ok


func _update_ui_for_player_mode() -> void:
	# Show survival UI only when incarnated (playing as a pawn)
	# Hide in spectator and observer modes (watching/commanding from above)
	var is_incarnated: bool = _player_mode == PlayerMode.INCARNATED

	# Hide/show main HUD elements based on mode
	if _hud != null:
		_hud.visible = not is_incarnated

	if _observer_hud != null:
		_observer_hud.visible = not is_incarnated

	if _minimap != null:
		_minimap.visible = not is_incarnated

	# Hide/show survival UI (SurvivalHUD, PlayerInventory) based on mode
	var survival_hud: Node = get_node_or_null("UI_Viewport/SurvivalHUD")
	if survival_hud != null:
		survival_hud.visible = is_incarnated

	var inventory_ui: Node = get_node_or_null("UI_Viewport/PlayerInventory")
	if inventory_ui != null:
		inventory_ui.visible = is_incarnated

	# Show minimal incarnated UI
	if is_incarnated:
		print("[Main] Incarnated mode: Survival UI visible. You experience needs, hunger, thirst through your pawn.")
	elif _player_mode == PlayerMode.OBSERVER:
		print("[Main] Observer mode: Full command UI. You command all pawns from above.")
	else:
		print("[Main] Watch mode: world runs fully autonomous; you observe without commanding.")


func _reset_player_intent_observer_routing() -> void:
	_player_intent_pin_zone_id = ""
	_player_intent_focus_center_region = -1


## Dispatches at most one queued intent per **simulation tick** (FIFO, cursor-based).
func _process_player_intent_dispatch_tick() -> void:
	var e: Dictionary = PlayerIntentQueue.take_next_unprocessed()
	if e.is_empty():
		return
	var kind: int = int(e.get("kind", 0))
	match kind:
		PlayerIntentQueue.IntentKind.OBSERVER_NOTE:
			pass
		PlayerIntentQueue.IntentKind.REQUEST_INCARNATION_ENTRY, PlayerIntentQueue.IntentKind.REQUEST_SPECTATOR_RETURN:
			pass
		PlayerIntentQueue.IntentKind.CHRONICLE_PIN_ZONE:
			var zid: String = str(e.get("zone_id", ""))
			if not zid.is_empty():
				_player_intent_pin_zone_id = zid
		PlayerIntentQueue.IntentKind.REQUEST_SETTLEMENT_FOCUS:
			var pl_var: Variant = e.get("payload", {})
			var pl: Dictionary = pl_var as Dictionary if pl_var is Dictionary else {}
			var cr: int = int(pl.get("center_region", pl.get("region", -1)))
			if cr >= 0:
				_player_intent_focus_center_region = cr
		PlayerIntentQueue.IntentKind.DEBUG_TOOL:
			pass
		_:
			pass


func _run_heavy_refresh_once_per_tick(cb: Callable) -> void:
	if GameManager.tick_count == _last_heavy_refresh_tick:
		return
	_last_heavy_refresh_tick = GameManager.tick_count
	cb.call()


func _run_heavy_stack_refresh_once_per_tick(cb: Callable) -> void:
	if GameManager.tick_count == _last_heavy_stack_tick:
		return
	_last_heavy_stack_tick = GameManager.tick_count
	cb.call()


## Full colony startup (or reboot after R). Order:
##   1. World already generated (World._ready runs before Main._ready).
##   2. Pick the main landmass via largest-component.
##   3. Place the stockpile somewhere central on that landmass.
##   4. Spawn pawns, restricted to that landmass so they can reach the stockpile.
##   5. Seed initial jobs from world features.
func _bootstrap_colony() -> void:
	var main_component: int = _world.pathfinder.largest_component_id()
	if main_component < 0:
		push_error("[Main] No passable tiles in world; cannot bootstrap colony.")
		return
	WorldMeaning.recompute()
	WorldPersistence.recompute()
	# Stockpiles will be created organically by pawns through the StockpileManager
	# Starting supplies will be gathered organically by pawns from the environment
	# DEAD BRAIN REVIVED: WorldEventSeedManager initialized on boot
	if WorldEventSeedManager != null:
		WorldEventSeedManager.ensure_default_seeds()
	# DORMANT WORLD: No pre-seeded fire pits or beds — HeelKawnians build their own
	# Pioneer buff gives them 5000 ticks of cold resistance to survive
	_pawn_spawner.spawn_starters(_world, main_component)
	# DORMANT WORLD: Pre-discover stockpile area for FogOfDiscovery
	if FogOfDiscovery != null:
		FogOfDiscovery.set_world(_world)
		# Stockpiles will be created organically, so no initial discovery area needed
	_player_pawn = _first_live_pawn()
	_set_selected_pawn(null)
	_set_player_mode(PlayerMode.SPECTATOR)
	_ensure_player_pawn_assigned()
	if is_instance_valid(_world):
		_world.apply_ruins_from_persistence()
		CulturalMemory.recompute(_world)
		SettlementMemory.recompute(_world)
		_ensure_validation_session_seed_stockpile_overlaps_settlement()
		MythMemory.recompute(_world)
		SacredMemory.sync_permanent_ruins_from_settlements()
		FactionRegistry.sync_from_settlements()
		_run_heavy_refresh_once_per_tick(func() -> void:
			if is_instance_valid(_world):
				_world.refresh_pawn_historic_path_weights()
		)
		SettlementPlanner.plan(_world, self, true)
		EconomyManager.get_trade_planner().plan(_world, self, true)
		MemoryManager.flush_dirty_tiles(_world)
		_sync_pawn_inherited_cultural_reputation()
	# Spawn animals and register spawner with world for breeding
	_animal_spawner.spawn_initial(_world)
	_world.set_meta("animal_spawner", _animal_spawner)
	Main._world_stabilization_until_tick = GameManager.tick_count + WORLD_STABILIZATION_TICKS
	# DORMANT WORLD: FogOfDiscovery handles job posting as pawns discover tiles
	# Seed initial jobs only for the pre-discovered stockpile area
	_seed_jobs_for_discovered_area()
	_seed_construction_jobs()
	# Seed initial tunneling toward sealed ore before the first logical tick.
	_react_to_mining_progress()
	if _hud != null:
		_hud.bind(_world, _pawn_spawner)
	if _chronicle_ledger != null:
		_chronicle_ledger.bind(_pawn_spawner)
	if _chronicle_book != null:
		_chronicle_book.bind(_pawn_spawner)
	if FootpathMemory != null and FootpathMemory.has_method("bind_context"):
		FootpathMemory.bind_context(_world, _pawn_spawner)
	if BuildingUsageTracker != null and BuildingUsageTracker.has_method("bind_context"):
		BuildingUsageTracker.bind_context(_world, _pawn_spawner)
	if SnowAccumulation != null and SnowAccumulation.has_method("bind_world"):
		SnowAccumulation.bind_world(_world)
	if TimeLapseRecorder != null and TimeLapseRecorder.has_method("bind_context"):
		TimeLapseRecorder.bind_context(_world, _pawn_spawner, _camera)
		TimeLapseRecorder.record()
	_last_generation_tick = GameManager.tick_count
	MemoryManager.get_remnant_memory().clear()
	MemoryManager.get_age_memory().clear()
	if DiscoveryGate != null:
		DiscoveryGate.clear()
	if FogOfDiscovery != null:
		FogOfDiscovery.clear()
	if is_instance_valid(_world):
		MemoryManager.seed_births_from_current_world(_world)
		MemoryManager.recompute_intent(_world)
	# Defer only visual refresh; causal job setup stays before the first tick.
	call_deferred("_bootstrap_heavy_phase2")


## Heavy bootstrap phase 2: visual-only terrain tint refresh.
func _bootstrap_heavy_phase2() -> void:
	if not is_instance_valid(_world):
		return
	_world.refresh_terrain_scar_tint()


## Instantiate the seed Stockpile zone at the nearest main-component tile
## to the world center. Frees any previous zone first. Registers the zone
## with StockpileManager so every system (pawns, HUD) finds it through the
## same manager as player-designated zones.
##
## Note: we deliberately ship the seed zone as a 3x3 ALL-filter pile. That's
## wide enough that adjacent tiles are walkable-in from any direction
## (pawns don't have to queue through a single corner) and ALL means the
## brand-new colony has somewhere to dump anything until the player decides
## to specialize with designated zones.
func _place_stockpile(main_component: int) -> void:
	if _world.stockpile != null:
		StockpileManager.unregister(_world.stockpile)
		_world.stockpile.queue_free()
		_world.stockpile = null
	var center := Vector2i(int(WorldData.WIDTH / 2.0), int(WorldData.HEIGHT / 2.0))
	var tile: Vector2i = _world.pathfinder.find_tile_in_component_near(main_component, center)
	if tile.x < 0:
		push_warning("[Main] Could not find tile near center for stockpile - searching entire component...")
		tile = _find_any_tile_in_component(main_component)
	if tile.x < 0:
		push_error("[Main] Could not find ANY tile on the main component to place the stockpile.")
		return
	var seed_rect: Rect2i = _fit_seed_stockpile_rect(tile, main_component, 3, 3)
	var sp: Stockpile = STOCKPILE_SCENE.instantiate()
	sp.set_filter(Stockpile.Filter.ALL)
	sp.set_rect_tiles(seed_rect)
	sp.position = _world.tile_to_world(seed_rect.position)
	sp.settlement_id = 0  # Belongs to the first settlement
	add_child(sp)
	_world.stockpile = sp
	StockpileManager.register(sp)
	if OS.is_debug_build():
		print(
				"[Main] Seed stockpile placed at %s (%dx%d, ALL)" %
				[seed_rect.position, seed_rect.size.x, seed_rect.size.y]
		)


func _find_any_tile_in_component(comp_id: int) -> Vector2i:
	# Fallback: find any passable tile in the given pathfinder component
	if _world == null or _world.pathfinder == null:
		return Vector2i(-1, -1)
	var pf = _world.pathfinder
	for tx in range(WorldData.WIDTH):
		for ty in range(WorldData.HEIGHT):
			var t = Vector2i(tx, ty)
			if pf.component_of(t) == comp_id and Biome.is_passable(t):
				return t
	return Vector2i(-1, -1)


## Seed the stockpile with starting supplies so pawns don't starve or freeze
## on day 1. Gives them enough food, wood, and stone to survive and build.
func _seed_starting_supplies() -> void:
	if _world == null or _world.stockpile == null:
		return
	var sp: Stockpile = _world.stockpile
	# Starting supplies: enough for 20 pawns to survive the first days
	# Food: berries + meat for ~500 ticks of 20 pawns
	sp.add_item(Item.Type.BERRY, 40)
	sp.add_item(Item.Type.MEAT, 20)
	# Building materials: enough for initial shelters
	sp.add_item(Item.Type.WOOD, 30)
	sp.add_item(Item.Type.STONE, 20)
	# Basic tools
	sp.add_item(Item.Type.FLINT, 10)
	sp.add_item(Item.Type.STICK, 15)


## Place fire pits near the stockpile so pawns have warmth from tick 1.
## Also place beds so pawns have shelter from the start.
func _seed_initial_fire_pits(main_component: int) -> void:
	if _world == null or _world.data == null or _world.pathfinder == null:
		return
	if _world.stockpile == null:
		return
	var center: Vector2i = _world.stockpile.rect.position
	# Place 5 fire pits near the stockpile so all pioneers have warmth
	var placed: int = 0
	for r in range(1, 10):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if abs(dx) != r and abs(dy) != r:
					continue
				if placed >= 5:
					break
				var t: Vector2i = center + Vector2i(dx, dy)
				if not _world.data.in_bounds(t.x, t.y):
					continue
				if not _world.pathfinder.is_passable(t):
					continue
				var feat: int = int(_world.data.get_feature(t.x, t.y))
				if feat != TileFeature.Type.NONE and feat != TileFeature.Type.TREE:
					continue
				_world.data.features[_world.data.index(t.x, t.y)] = TileFeature.Type.FIRE_PIT
				placed += 1
			if placed >= 5:
				break
		if placed >= 5:
			break
	# Place 10 beds near the stockpile so pawns have shelter
	placed = 0
	for r in range(1, 8):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if abs(dx) != r and abs(dy) != r:
					continue
				if placed >= 10:
					break
				var t: Vector2i = center + Vector2i(dx, dy)
				if not _world.data.in_bounds(t.x, t.y):
					continue
				if not _world.pathfinder.is_passable(t):
					continue
				var feat: int = int(_world.data.get_feature(t.x, t.y))
				if feat != TileFeature.Type.NONE and feat != TileFeature.Type.TREE:
					continue
				_world.data.features[_world.data.index(t.x, t.y)] = TileFeature.Type.BED
				placed += 1
			if placed >= 10:
				break
		if placed >= 10:
			break


## Clamp a desired-size seed stockpile rectangle so it stays on the main
## component. We start at (tile - half) and shrink toward the anchor if any
## candidate tile is impassable. Guaranteed to return at least a 1x1 rect
## containing `tile`.
func _fit_seed_stockpile_rect(tile: Vector2i, main_component: int, w: int, h: int) -> Rect2i:
	var start_x: int = tile.x - int(w / 2.0)
	var start_y: int = tile.y - int(h / 2.0)
	# Pull in from edges first so the rect stays inside the world.
	start_x = clamp(start_x, 0, WorldData.WIDTH - w)
	start_y = clamp(start_y, 0, WorldData.HEIGHT - h)
	# If any candidate tile is off-component, shrink to a 1x1 fallback.
	for dy in range(h):
		for dx in range(w):
			var t := Vector2i(start_x + dx, start_y + dy)
			if _world.pathfinder.component_of(t) != main_component:
				return Rect2i(tile, Vector2i.ONE)
	return Rect2i(Vector2i(start_x, start_y), Vector2i(w, h))


## Validation sessions only (debug build + SettlementMemory.VALIDATION_SESSION_ENABLED):
## Phase 8 proof requires a designated stockpile whose rect overlaps at least one tile in a
## settlement region set. The default seed pile is centered on the map, which often shares
## no tiles with clustered settlements — relocate the seed pile onto the main landmass near
## an existing settlement anchor. Does not alter release builds or non-validation debug.
func _ensure_validation_session_seed_stockpile_overlaps_settlement() -> void:
	if not OS.is_debug_build():
		return
	if not SettlementMemory.VALIDATION_SESSION_ENABLED:
		return
	if not is_instance_valid(_world):
		return
	var sp: Stockpile = _world.stockpile
	if sp == null or not is_instance_valid(sp):
		return
	var main_component: int = _world.pathfinder.largest_component_id()
	if main_component < 0:
		return
	var st: Dictionary = _pick_validation_proof_anchor_settlement()
	if st.is_empty():
		print("[Main] VALIDATION_SESSION proof_anchor skipped reason=no_settlement_after_recompute")
		return
	var anchor: Vector2i = _validation_proof_anchor_tile_for_main_component(st, main_component)
	if anchor.x < 0:
		print(
                "[Main] VALIDATION_SESSION proof_anchor skipped reason=no_passable_tile_near_settlement_regions "
				+ "center_region=%d"
				% int(st.get("center_region", -1))
		)
		return
	var seed_rect: Rect2i = _fit_seed_stockpile_rect(anchor, main_component, 3, 3)
	sp.set_rect_tiles(seed_rect)
	sp.position = _world.tile_to_world(seed_rect.position)
	print(
            "[Main] VALIDATION_SESSION proof_anchor seed_stockpile_rect=%s size=%s settlement_center_region=%d state=%s"
			% [
				seed_rect.position,
				seed_rect.size,
				int(st.get("center_region", -1)),
				str(st.get("state", "?")),
			]
	)


func _pick_validation_proof_anchor_settlement() -> Dictionary:
	for st_any in SettlementMemory.settlements:
		if not (st_any is Dictionary):
			continue
		var st: Dictionary = st_any as Dictionary
		if int(st.get("center_region", -1)) < 0:
			continue
		if str(st.get("state", "")) == "active":
			return st
	for st_any in SettlementMemory.settlements:
		if not (st_any is Dictionary):
			continue
		var st: Dictionary = st_any as Dictionary
		if int(st.get("center_region", -1)) < 0:
			continue
		var regv: Variant = st.get("regions", PackedInt32Array())
		if regv is PackedInt32Array and not (regv as PackedInt32Array).is_empty():
			return st
	return {}


func _validation_proof_anchor_tile_for_main_component(st: Dictionary, main_component: int) -> Vector2i:
	var ordered_keys: Array[int] = []
	var rk_center: int = int(st.get("center_region", -1))
	if rk_center >= 0:
		ordered_keys.append(rk_center)
	var regv: Variant = st.get("regions", PackedInt32Array())
	if regv is PackedInt32Array:
		for rk_any in regv as PackedInt32Array:
			var rk: int = int(rk_any)
			if ordered_keys.has(rk):
				continue
			ordered_keys.append(rk)
	for rk in ordered_keys:
		var tx: int = rk & 0xFFFF
		var ty: int = (rk >> 16) & 0xFFFF
		var hint := Vector2i(tx, ty)
		var near: Vector2i = _world.pathfinder.find_tile_in_component_near(main_component, hint, 64)
		if near.x >= 0:
			return near
	return Vector2i(-1, -1)


func _sync_pawn_inherited_cultural_reputation() -> void:
	## Re-read [CulturalMemory] into each pawn’s birth cache (e.g. after load, once
	## [World.apply_ruins_from_persistence] has run).
	if _pawn_spawner == null:
		return
	for p in _pawn_spawner.pawns:
		if p == null or not is_instance_valid(p):
			continue
		if p.has_method("refresh_inherited_cultural_reputation"):
			p.call("refresh_inherited_cultural_reputation")


func _on_world_tick(tick_number: int) -> void:
	_on_game_tick(tick_number)


# OPTIMIZATION: Frame time budget constants - higher at 100x to prevent defer pileup
const FRAME_BUDGET_USEC: int = 10000  # 10ms = 100 FPS target (aggressive optimization)
const FRAME_BUDGET_SOFT_USEC: int = 8000  # 8ms soft target for 125 FPS
const DEFERRABLE_OPERATIONS: Array[String] = ["regrowth", "ambient_target", "animal_population", "observer_snapshot"]
const MAIN_FAST_MAINT_INTERVAL_TICKS: int = 10
const MAIN_MEDIUM_MAINT_INTERVAL_TICKS: int = 30
const MAIN_SLOW_MAINT_INTERVAL_TICKS: int = 120
const MAIN_DAILY_MAINT_INTERVAL_TICKS: int = 600


func _is_main_lane_tick(tick: int, interval: int, salt: int = 0) -> bool:
	if interval <= 1:
		return true
	return posmod(tick + salt, interval) == 0

func _on_game_tick(tick: int) -> void:
	if CrashTrap.trace_enabled and tick == 1:
		CrashTrap.log_tick_event("Main._on_game_tick", "tick=%d" % tick)
	if _is_simulation_worker_mode() and GameManager != null and GameManager.is_tick_benchmark_enabled():
		return

	# Playtest: log camera movement every 10 ticks
	if _playtest_recorder_ref != null and _camera != null and tick - _playtest_last_cam_tick >= 10:
		_playtest_last_cam_tick = tick
		_playtest_recorder_ref.call("record_camera_movement", _camera.position, _camera.zoom.x)

	# OPTIMIZATION: Frame budget tracking - exit early if we're over budget
	var frame_start: int = Time.get_ticks_usec()
	var frame_budget_exceeded: bool = false
	
	var section_us: Dictionary = {}
	var t0: int = Time.get_ticks_usec()
	_process_player_intent_dispatch_tick()
	section_us["intent_dispatch"] = Time.get_ticks_usec() - t0
	# Phase 4: Update meaning ambiance controller for player-readable meaning refinement
	if is_instance_valid(MeaningAmbianceController):
		MeaningAmbianceController._tick()
	if _player_input != null and _player_mode == PlayerMode.INCARNATED:
		var _player_pawn_death_detected: bool = false
		if is_instance_valid(_player_pawn) and _player_pawn.data != null and bool(_player_pawn.data.is_dead):
			_player_pawn_death_detected = true
		if not is_instance_valid(_player_pawn) or _player_pawn_death_detected:
			if _player_pawn_death_detected and IncarnationManager != null:
				var _pid: int = int(_player_pawn.data.id)
				IncarnationManager.on_player_pawn_died(_pid, "combat_or_age")
			_set_player_mode(PlayerMode.SPECTATOR)
			_player_pawn = null
			_set_selected_pawn(null)
		if is_instance_valid(_player_pawn):
			_player_input.process_next_tick(_player_pawn)
			_player_action_state = _player_input.get_last_action_state()
		else:
			_player_action_state = "no_pawn"
	elif _player_mode != PlayerMode.INCARNATED:
		_player_action_state = "spectator"
	# Refresh HUD mode badge every 200 ticks (authority rank can change)
	if tick % 200 == 0 and _player_mode == PlayerMode.INCARNATED:
		_update_hud_mode_badge()
	# First tick of post-stab window: (re)post HUNT for static wildlife skipped during [member _world_stabilization_until_tick] seed; deterministic order.
	if Main._world_stabilization_until_tick >= 0 and tick == Main._world_stabilization_until_tick:
		_post_wildlife_hunt_jobs_after_stabilization()
	if (
			_animal_spawner != null
			and _is_main_lane_tick(int(tick), AnimalSpawner.POPULATION_CHECK_TICKS, ANIMAL_POPULATION_PHASE_TICKS)
	):
		# OPTIMIZATION: Skip if over budget (deferrable operation)
		if Time.get_ticks_usec() - frame_start > FRAME_BUDGET_USEC:
			frame_budget_exceeded = true
		if not frame_budget_exceeded:
			t0 = Time.get_ticks_usec()
			_animal_spawner.update_population_dynamics(_world)
			section_us["animal_population"] = Time.get_ticks_usec() - t0
	# DORMANT WORLD: FogOfDiscovery posts jobs as pawns discover tiles (no visual refresh needed)
	# Regrowth + ambient are display/maintenance layers; they should not run
	# every sim tick in normal mode or high speeds will hitch.
	# AGGRESSIVE OPTIMIZATION: Even longer intervals for smooth FPS
	var regrowth_interval: int = _high_speed_interval(8, 30, 80)  # Was (6, 20, 60) - now 80 ticks at 100x
	if _is_main_lane_tick(tick, regrowth_interval, 3):
		# OPTIMIZATION: Skip if over budget (deferrable operation)
		if Time.get_ticks_usec() - frame_start > FRAME_BUDGET_USEC:
			frame_budget_exceeded = true
		if not frame_budget_exceeded:
			t0 = Time.get_ticks_usec()
			_process_regrowth(tick)
			section_us["regrowth"] = Time.get_ticks_usec() - t0
	var ambient_interval: int = _high_speed_interval(3, 12, 50)  # Was (2, 8, 40) - now 50 ticks at 100x
	if _is_main_lane_tick(tick, ambient_interval, 13):
		# OPTIMIZATION: Skip if over budget (deferrable operation)
		if Time.get_ticks_usec() - frame_start > FRAME_BUDGET_USEC:
			frame_budget_exceeded = true
		if not frame_budget_exceeded:
			t0 = Time.get_ticks_usec()
			_update_ambient_target()
			section_us["ambient_target"] = Time.get_ticks_usec() - t0
	# DEAD BRAIN REVIVED: WorldEventSeedManager advances seeds periodically
	if WorldEventSeedManager != null and tick % 100 == 0:
		var seed_events: Array = WorldEventSeedManager.advance_all(tick)
		if not seed_events.is_empty() and WorldEvents != null:
			for evt in seed_events:
				if evt is Dictionary:
					WorldEvents.record_pawn_action(str(evt.get("type", "seed_event")), -1)
	# Post dynamic hunt jobs less aggressively than harvest loops.
	var hunt_post_interval: int = _high_speed_interval(40, 150, 500)  # Was (30, 120, 400) - now 500 ticks at 100x
	var hunt_phase_offset: int = maxi(1, hunt_post_interval / 2)
	if (
			_is_main_lane_tick(tick, hunt_post_interval, hunt_phase_offset)
			and Main._world_stabilization_until_tick >= 0
			and tick >= Main._world_stabilization_until_tick
	):
		t0 = Time.get_ticks_usec()
		_post_hunting_jobs_for_animals()
		section_us["hunt_post"] = Time.get_ticks_usec() - t0

	# Settlement construction seeder: post build/cook/plant jobs based on
	# what each settlement actually needs (beds, walls, hearths, farms, etc.)
	if _is_main_lane_tick(tick, CONSTRUCTION_JOB_SEED_INTERVAL_TICKS, 11):
		t0 = Time.get_ticks_usec()
		_seed_construction_jobs()
		section_us["construction_seed"] = Time.get_ticks_usec() - t0

	# Flush deferred pathfinder component computation (batched from sync_tile_from_data)
	if _world != null and _world.pathfinder != null and _world.data != null:
		t0 = Time.get_ticks_usec()
		if _world.pathfinder.flush_component_dirty(_world.data):
			section_us["pf_components"] = Time.get_ticks_usec() - t0

	# Flood events: rain near rivers deposits flood silt; dry weather fades it.
	if _is_main_lane_tick(tick, 200, 19):
		_tick_flood_events(tick)
	# Erosion: decay abandoned buildings
	if _is_main_lane_tick(tick, 2000, 29):
		if _world != null and _world.has_method("_tick_erosion"):
			_world._tick_erosion(tick)
	# Blood stains: fade over time
	if _world != null and _world.has_method("_tick_blood_stains"):
		_world._tick_blood_stains(tick)
	# Doors: close timed-out open doors
	if _world != null and _world.has_method("_tick_doors"):
		_world._tick_doors(tick)
	# Settlement festivals: milestone-driven celebrations for growing colonies.
	if SettlementMemory != null and _is_main_lane_tick(tick, 200, 37) and SettlementMemory.has_method("process_festival_milestones"):
		SettlementMemory.process_festival_milestones(tick)
	# Periodic settlement merge: collapse ghost settlements (0-pawn) into neighbors
	if SettlementMemory != null and _is_main_lane_tick(tick, 300, 53) and SettlementMemory.has_method("merge_small_settlements"):
		SettlementMemory.count_pawns_per_settlement()
		SettlementMemory.merge_small_settlements()

	# Settlement leader direct construction: rulers post build jobs based on
	# settlement needs, bypassing the slow worldbox loop.
	# DORMANT WORLD: Only runs after first settlement
	if SettlementMemory != null and _is_main_lane_tick(tick, _high_speed_interval(50, 100, 300), 67) and DiscoveryGate.is_unlocked("first_settlement"):
		var total_leader_posts: int = 0
		for st_v in SettlementMemory.settlements:
			if not (st_v is Dictionary):
				continue
			var st: Dictionary = st_v as Dictionary
			var sid: int = int(st.get("center_region", -1))
			if sid < 0:
				continue
			var local_pop_l: int = int(st.get("population", 0))
			if local_pop_l < 1:
				continue
			total_leader_posts += HeelKawnianManager.leader_direct_construction(sid)
		if total_leader_posts > 0:
			print("[Main] Leader construction: posted %d build jobs" % total_leader_posts)

	# Periodic maintenance: prune old cooldown entries to bound memory.
	if GameManager != null:
		if _last_prune_tick < 0 or tick - _last_prune_tick >= PRUNE_INTERVAL_TICKS:
			_prune_job_post_cooldowns()
			_last_prune_tick = tick

	# Verbose session-level telemetry: suppression summary every 1000 ticks.
	if GameManager != null and GameManager.verbose_logs():
		if tick % 1000 == 0:
			print("[JobCooldown] Suppressed this session: %d" % [_jobs_suppressed_this_session])
	# Enemy AI and raid spawning. Keep real 100x honest; the spawner no-ops when empty.
	t0 = Time.get_ticks_usec()
	_on_enemy_tick(tick, _enemy_spawner)
	section_us["enemy_tick"] = Time.get_ticks_usec() - t0
	# Suppress hot-loop tick spam; this is a major source of debug-mode stutter.
	# Failsafe: pawns that slipped into solid tiles (rare) get nudged; log once per pawn.
	# OPTIMIZATION: Less frequent at 100x
	var sanity_interval: int = _high_speed_interval(60, 200, 600)  # Was 60 always
	if _is_main_lane_tick(tick, sanity_interval, 71) and _pawn_spawner != null:
		for p in _pawn_spawner.pawns:
			if p != null and is_instance_valid(p):
				p.sanity_check_impassable_tile()
	# WorldMemory-derived recompute: defer once so HeelKawnian/Animal (connected after Main) can record first.
	if is_instance_valid(_world) and not _world_memory_derivative_flush_queued:
		# Derivative flush recomputes meaning/persistence/culture; too-frequent calls
		# will hitch even when tick ordering is correct.
		var derivative_flush_interval: int = _high_speed_interval(8, 40, 150)  # Was (8, 12, 20) - now 150 at 100x
		if _is_main_lane_tick(tick, derivative_flush_interval, 83):
			_world_memory_derivative_flush_queued = true
			call_deferred("_flush_world_memory_derivatives")
	if is_instance_valid(_world):
		# Planning every tick at 1x causes severe frame-time spikes in large worlds.
		# Keep planning frequent, but not per-tick. AGGRESSIVE OPTIMIZATION: Longer intervals
		# DORMANT WORLD: Skip settlement-dependent systems until first settlement forms
		var planner_interval: int = _planner_interval_for_speed()
		if _is_main_lane_tick(tick, planner_interval, 97) and DiscoveryGate.is_unlocked("first_settlement"):
			# Check frame budget before heavy planning
			if Time.get_ticks_usec() - frame_start > FRAME_BUDGET_USEC:
				# Defer to next frame
				call_deferred("_deferred_settlement_planner_plan", _world, self, false)
			else:
				t0 = Time.get_ticks_usec()
				SettlementPlanner.plan(_world, self, false)
				section_us["settlement_planner"] = Time.get_ticks_usec() - t0
		# Periodic resource truth refresh — settlements need to know their stockpile state
		if _is_main_lane_tick(tick, 500, 109):
			SettlementMemory.refresh_resource_truth()
		# Spread heavy planning across adjacent ticks to reduce one-tick hitch spikes.
		# DORMANT WORLD: Trade planner only runs after first trade route
		var trade_offset: int = maxi(1, planner_interval / 3)
		if _is_main_lane_tick(tick, planner_interval, trade_offset) and DiscoveryGate.is_unlocked("first_trade"):
			# Check frame budget before heavy planning
			if Time.get_ticks_usec() - frame_start > FRAME_BUDGET_USEC:
				# Defer to next frame
				call_deferred("_deferred_trade_planner_plan", _world, self, false)
			else:
				t0 = Time.get_ticks_usec()
				EconomyManager.get_trade_planner().plan(_world, self, false)
				section_us["trade_planner"] = Time.get_ticks_usec() - t0
		# Build roads from trade routes every 2000 ticks
		if _is_main_lane_tick(tick, 2000, 113) and DiscoveryGate.is_unlocked("first_trade"):
			_build_roads_from_trade_routes()
		# OPTIMIZATION: Spread heavy settlement operations across ticks with frame budget check
		# DORMANT WORLD: Settlement operations only run after first settlement forms
		if tick % REBIRTH_CHECK_INTERVAL_TICKS == 0 and DiscoveryGate.is_unlocked("first_settlement"):
			# Check frame budget before heavy recompute
			if Time.get_ticks_usec() - frame_start > FRAME_BUDGET_USEC:
				frame_budget_exceeded = true
				# Defer to next frame
				call_deferred("_deferred_settlement_memory_recompute", _world)
			else:
				t0 = Time.get_ticks_usec()
				SettlementMemory.recompute(_world)
				section_us["rebirth_recompute"] = Time.get_ticks_usec() - t0

		# Offset SettlementRebirth.process to a different tick to spread the load
		var rebirth_offset_tick: int = (tick + REBIRTH_CHECK_INTERVAL_TICKS / 2) % REBIRTH_CHECK_INTERVAL_TICKS
		if rebirth_offset_tick == 0:
			# Check frame budget before heavy process
			if Time.get_ticks_usec() - frame_start > FRAME_BUDGET_USEC:
				frame_budget_exceeded = true
				# Defer to next frame
				call_deferred("_deferred_settlement_rebirth_process", _world, self)
			else:
				t0 = Time.get_ticks_usec()
				SettlementRebirth.process(_world, self, false)
				section_us["rebirth_recompute"] = Time.get_ticks_usec() - t0
		# Phase 4 Identity: visual decay for permanently abandoned settlements (infrequent)
		# DORMANT WORLD: Only runs after first settlement
		if GameManager.periodic_phase_due(tick, SETTLEMENT_ARCHITECT_INTERVAL_TICKS, SETTLEMENT_ARCHITECT_PHASE_OFFSET_TICKS) and DiscoveryGate.is_unlocked("first_settlement"):
			t0 = Time.get_ticks_usec()
			SettlementArchitect.process(_world, self)
			section_us["settlement_architect"] = Time.get_ticks_usec() - t0
	if GameManager.periodic_phase_due(int(tick), AGE_MEMORY_INTERVAL_TICKS, AGE_MEMORY_PHASE_OFFSET_TICKS):
		AgeMemory.recompute()
		if is_instance_valid(_world):
			MemoryManager.recompute_intent(_world)
	var can_run_mining_react: bool = _mining_react_in_progress or (tick - _last_mining_react_tick) >= MINING_REACT_MIN_INTERVAL_TICKS
	if _mining_react_pending and can_run_mining_react:
		# At high speed, skip N ticks between mining react steps to reduce per-frame load
		var step_skip: int = _mining_react_step_skip_for_speed()
		if step_skip > 0:
			_mining_react_step_skip_counter += 1
			if _mining_react_step_skip_counter <= step_skip:
				section_us["mining_react"] = 0
			else:
				_mining_react_step_skip_counter = 0
				t0 = Time.get_ticks_usec()
				var mining_react_done: bool = _react_to_mining_progress_step()
				section_us["mining_react"] = Time.get_ticks_usec() - t0
				_last_mining_react_tick = tick
				_mining_react_pending = not mining_react_done
		else:
			t0 = Time.get_ticks_usec()
			var mining_react_done: bool = _react_to_mining_progress_step()
			section_us["mining_react"] = Time.get_ticks_usec() - t0
			_last_mining_react_tick = tick
			_mining_react_pending = not mining_react_done
	t0 = Time.get_ticks_usec()
	_maybe_generational_turnover()
	section_us["generational_turnover"] = Time.get_ticks_usec() - t0
	if tick % REPRODUCTION_CHECK_INTERVAL_TICKS == 0:
		t0 = Time.get_ticks_usec()
		_process_reproduction_tick()
		section_us["reproduction"] = Time.get_ticks_usec() - t0
	if tick % INFLUENCE_UPDATE_INTERVAL_TICKS == 0:
		t0 = Time.get_ticks_usec()
		_update_pawn_influence_tick()
		section_us["influence"] = Time.get_ticks_usec() - t0
	_update_phase8_proof_bundle_preferred_center()
	# Settlement intents: scale with speed like other settlement updates
	# DORMANT WORLD: Only runs after first settlement
	var settlement_intent_interval: int = _high_speed_interval(5, 15, 30)
	if _is_main_lane_tick(tick, settlement_intent_interval, 127) and DiscoveryGate.is_unlocked("first_settlement"):
		t0 = Time.get_ticks_usec()
		SettlementMemory.update_settlement_intents(tick)
		section_us["settlement_intents"] = Time.get_ticks_usec() - t0
	# Spread settlement updates across ticks to reduce hitch spikes
	# DORMANT WORLD: Only runs after first settlement
	var settlement_update_interval: int = _high_speed_interval(30, 45, 60)
	if _is_main_lane_tick(tick, settlement_update_interval, 137) and DiscoveryGate.is_unlocked("first_settlement"):
		t0 = Time.get_ticks_usec()
		SettlementMemory.update_resource_pressures(tick)
		section_us["settlement_resource_pressure"] = Time.get_ticks_usec() - t0
	# Offset work fronts update to spread load
	var work_fronts_offset: int = maxi(1, settlement_update_interval / 2)
	if _is_main_lane_tick(tick, settlement_update_interval, work_fronts_offset) and DiscoveryGate.is_unlocked("first_settlement"):
		t0 = Time.get_ticks_usec()
		SettlementMemory.update_preferred_work_fronts(tick)
		section_us["settlement_work_fronts"] = Time.get_ticks_usec() - t0
	# DORMANT WORLD: Social rapport only runs after first settlement
	if _is_main_lane_tick(tick, _social_rapport_interval_for_speed(), 149) and DiscoveryGate.is_unlocked("first_settlement"):
		t0 = Time.get_ticks_usec()
		_accumulate_social_rapport()
		if SquadCoordinator != null:
			SquadCoordinator.recompute(_pawn_spawner)
		section_us["social_rapport"] = Time.get_ticks_usec() - t0
	_emit_pawn_divergence_summary_if_needed(tick)
	# AI observer state export: write lightweight snapshot for external tools.
	var ai_export_interval: int = _high_speed_interval(30, 60, 120)
	if _is_main_lane_tick(tick, ai_export_interval, 157):
		ObservationAPI.export_ai_state()
	if _is_simulation_worker_mode():
		_maybe_log_tick_hotspots(tick, section_us)
		return
	# HUD snapshots are CPU-expensive — only when the realm/observer panel is open.
	var obs_iv: int = _high_speed_interval(60, 45, 90)
	if (
			_observer_hud != null
			and _observer_hud.is_visible_state()
			and _is_main_lane_tick(tick, obs_iv, 163)
	):
		# OPTIMIZATION: Skip if over budget (deferrable operation)
		if Time.get_ticks_usec() - frame_start > FRAME_BUDGET_USEC:
			frame_budget_exceeded = true
		if not frame_budget_exceeded:
			t0 = Time.get_ticks_usec()
			_observer_hud.apply_snapshot(_build_observer_snapshot(tick))
			section_us["observer_snapshot"] = Time.get_ticks_usec() - t0
	# Handle recent player_inspect events for tooltip + audio feedback
	if _is_main_lane_tick(tick, _inspect_scan_interval_for_speed(), 167):
		# OPTIMIZATION: Skip if over budget
		if Time.get_ticks_usec() - frame_start <= FRAME_BUDGET_USEC:
			t0 = Time.get_ticks_usec()
			_scan_recent_inspects_and_handle()
			section_us["inspect_scan"] = Time.get_ticks_usec() - t0
	# FocusInspector snapshotting is another large allocation hotspot (see ObservationAPI — programmatic reads must stay on-demand, not per-frame).
	var focus_iv: int = _high_speed_interval(30, 24, 48)
	if _focus_inspector != null and _focus_inspector.is_visible_state() and _is_main_lane_tick(tick, focus_iv, 173):
		t0 = Time.get_ticks_usec()
		_focus_inspector.apply_snapshot(_build_focus_snapshot(tick))
		section_us["focus_snapshot"] = Time.get_ticks_usec() - t0
	if is_instance_valid(_world):
		var road_flush_interval: int = _high_speed_interval(2, 4, 8)
		if _is_main_lane_tick(tick, road_flush_interval, 181) and not _road_flush_deferred_pending:
			_road_flush_deferred_pending = true
			call_deferred("_flush_road_memory_dirty_tiles")
	if _is_main_lane_tick(tick, MAIN_FAST_MAINT_INTERVAL_TICKS, 191):
		_refresh_spatial_profile_overlay()
	
	# Auto-save every 6000 ticks (~10 in-game days at 1x)
	if tick > 0 and tick % 6000 == 0:
		var snapshot: Dictionary = _build_save_dict()
		var err: Error = GameSave.write_file(GameSave.DEFAULT_PATH.trim_suffix(".sav") + "_autosave.sav", snapshot)
		if err == OK and OS.is_debug_build():
			print("[Main] Auto-saved at tick %d" % tick)
	
	_maybe_log_tick_hotspots(tick, section_us)


func _maybe_log_tick_hotspots(tick: int, section_us: Dictionary) -> void:
	if not OS.is_debug_build():
		return
	if GameManager == null:
		return
	if GameManager.game_speed < 26.0:
		return
	var total_us: int = 0
	for k in section_us.keys():
		total_us += int(section_us.get(k, 0))
	var total_ms: float = float(total_us) / 1000.0
	if total_ms < MAIN_TICK_HOTSPOT_MIN_TOTAL_MS:
		return
	var now_ms: int = Time.get_ticks_msec()
	if now_ms - _last_tick_hotspot_log_ms < MAIN_TICK_HOTSPOT_LOG_INTERVAL_MS:
		return
	_last_tick_hotspot_log_ms = now_ms
	var keys: Array = section_us.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		return int(section_us.get(a, 0)) > int(section_us.get(b, 0))
	)
	var parts: PackedStringArray = PackedStringArray()
	var shown: int = 0
	for k in keys:
		var us: int = int(section_us.get(k, 0))
		if us <= 0:
			continue
		parts.append("%s=%.2fms" % [str(k), float(us) / 1000.0])
		shown += 1
		if shown >= 4:
			break
	print(
            "[MAIN_TICK_HOTSPOT] tick=%d speed=%.0fx total=%.2fms top=%s"
			% [tick, GameManager.game_speed, total_ms, ", ".join(parts)]
	)


func _inspect_scan_interval_for_speed() -> int:
	# Re-enabled for smooth gameplay - game was lagging too hard without throttling
	if GameManager == null:
		return INSPECT_SCAN_INTERVAL_TICKS
	var gs: float = GameManager.game_speed
	if gs >= 100.0:
		return INSPECT_SCAN_INTERVAL_TICKS * 6
	if gs >= 50.0:
		return INSPECT_SCAN_INTERVAL_TICKS * 4
	if gs >= 26.0:
		return INSPECT_SCAN_INTERVAL_TICKS * 3
	if gs >= 12.0:
		return INSPECT_SCAN_INTERVAL_TICKS * 2
	return INSPECT_SCAN_INTERVAL_TICKS


## Co-presence rapport is O(pawns²) in worst case; stretch interval at fast-forward.
func _social_rapport_interval_for_speed() -> int:
	# Re-enabled for smooth gameplay - game was lagging too hard without throttling
	if GameManager == null:
		return SOCIAL_RAPPORT_ACCUM_INTERVAL_TICKS
	var gs: float = GameManager.game_speed
	if gs >= 100.0:
		return SOCIAL_RAPPORT_ACCUM_INTERVAL_TICKS * 6
	if gs >= 50.0:
		return SOCIAL_RAPPORT_ACCUM_INTERVAL_TICKS * 4
	if gs >= 26.0:
		return SOCIAL_RAPPORT_ACCUM_INTERVAL_TICKS * 3
	if gs >= 12.0:
		return SOCIAL_RAPPORT_ACCUM_INTERVAL_TICKS * 2
	return SOCIAL_RAPPORT_ACCUM_INTERVAL_TICKS


## Fewer world rows per mining-react step at ultra speed = smaller per-tick spikes
## (pass completes over more sim ticks, which is fine under catch-up).
func _mining_react_scan_rows_for_speed() -> int:
	# Re-enabled for smooth gameplay - game was lagging too hard without throttling
	if GameManager == null:
		return MINING_REACT_SCAN_ROWS_PER_STEP
	var gs: float = GameManager.game_speed
	if gs >= 100.0:
		return maxi(1, MINING_REACT_SCAN_ROWS_PER_STEP / 4)
	if gs >= 50.0:
		return maxi(1, MINING_REACT_SCAN_ROWS_PER_STEP / 3)
	if gs >= 26.0:
		return maxi(1, MINING_REACT_SCAN_ROWS_PER_STEP / 2)
	if gs >= 12.0:
		return maxi(1, MINING_REACT_SCAN_ROWS_PER_STEP / 1.5)
	return MINING_REACT_SCAN_ROWS_PER_STEP


func _flush_road_memory_dirty_tiles() -> void:
	_road_flush_deferred_pending = false
	if is_instance_valid(_world):
		MemoryManager.flush_dirty_tiles(_world)


func _scan_recent_inspects_and_handle() -> void:
	# Find newest player_inspect event and, if unseen, show tooltip and play tone.
	var recent_events: Array = WorldMemory.get_recent_events(48)
	for i in range(recent_events.size() - 1, -1, -1):
		var ev: Dictionary = recent_events[i]
		if str(ev.get("type", "")) != "player_inspect":
			continue
		var ev_tick: int = int(ev.get("t", -1))
		if ev_tick <= _last_inspect_event_tick_shown:
			return
		_last_inspect_event_tick_shown = ev_tick
		var pid: int = int(ev.get("pawn_id", -1))
		var tile_x: int = int(ev.get("tile", {}).get("x", -1))
		var tile_y: int = int(ev.get("tile", {}).get("y", -1))
		var msg: String = "%s | pawn:%d region:%d" % [str(ev.get("meaning_label", "")), pid, int(ev.get("center_region", -1))]
		_show_inspect_tooltip(msg, pid, tile_x, tile_y)
		_play_inspect_tone()
		return


func _show_inspect_tooltip(msg: String, pawn_id: int, tile_x: int, tile_y: int) -> void:
	# Remove existing tip
	if _inspect_tooltip_node != null and is_instance_valid(_inspect_tooltip_node):
		_inspect_tooltip_node.queue_free()
		_inspect_tooltip_node = null
	var ui_root: Node = get_node_or_null("UI_Viewport")
	if ui_root == null:
		return
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "InspectTooltip"
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.7)
	style.border_color = Color(0.8, 0.7, 0.4, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	var lbl: Label = Label.new()
	lbl.text = msg + " (tile=%d,%d)" % [tile_x, tile_y]
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(0.94,0.92,0.84))
	panel.add_child(lbl)
	ui_root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(220, 40)
	_inspect_tooltip_node = panel
	# Auto-hide after 2.8 seconds
	var t = get_tree().create_timer(2.8)
	t.timeout.connect(Callable(self, "_hide_inspect_tooltip"))


func _hide_inspect_tooltip() -> void:
	if _inspect_tooltip_node != null and is_instance_valid(_inspect_tooltip_node):
		_inspect_tooltip_node.queue_free()
	_inspect_tooltip_node = null


func _ensure_inspect_audio() -> void:
	if _inspect_audio_player != null and is_instance_valid(_inspect_audio_player):
		return
	var gen: AudioStreamGenerator = AudioStreamGenerator.new()
	gen.mix_rate = 44100
	gen.buffer_length = 0.5
	var p: AudioStreamPlayer = AudioStreamPlayer.new()
	p.name = "InspectAudio"
	p.stream = gen
	add_child(p)
	_inspect_audio_player = p
	# Playback is only valid after play() on many platforms; refresh in _play_inspect_tone.
	_inspect_audio_playback = null


func _play_inspect_tone() -> void:
	_ensure_inspect_audio()
	if _inspect_audio_player == null:
		return
	var player: AudioStreamPlayer = _inspect_audio_player
	var gen: AudioStreamGenerator = player.stream as AudioStreamGenerator
	if gen == null:
		return
	var freq: float = 660.0
	var dur: float = 0.12
	var sr: int = int(gen.mix_rate)
	var samples: int = int(float(sr) * dur)
	player.play()
	var playback: AudioStreamGeneratorPlayback = player.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback == null:
		return
	_inspect_audio_playback = playback
	for i in range(samples):
		var t: float = float(i) / float(sr)
		var s: float = sin(2.0 * PI * freq * t) * 0.14
		var frame = gen.get_frame()
		frame.left = s
		frame.right = s
		playback.push_frame(frame)


func _flush_world_memory_derivatives() -> void:
	_world_memory_derivative_flush_queued = false
	if not is_instance_valid(_world) or not WorldMemory.consume_dirty():
		return
	var flush_start: int = Time.get_ticks_usec()
	const FLUSH_BUDGET_USEC: int = 4_000  # 4ms max for derivative flush
	WorldMeaning.recompute()
	WorldPersistence.recompute()
	if Time.get_ticks_usec() - flush_start > FLUSH_BUDGET_USEC:
		return
	CulturalMemory.recompute(_world)
	MythMemory.recompute(_world)
	SacredMemory.sync_permanent_ruins_from_settlements()
	MemoryManager.recompute_intent(_world)
	if Time.get_ticks_usec() - flush_start > FLUSH_BUDGET_USEC:
		return
	_run_heavy_stack_refresh_once_per_tick(func() -> void:
		if is_instance_valid(_world):
			_world.refresh_terrain_scar_tint()
			_world.apply_ruins_from_persistence()
	)
	var heavy_planner_interval: int = _heavy_planner_interval_for_speed()
	if GameManager.tick_count % heavy_planner_interval == 0:
		if Time.get_ticks_usec() - flush_start <= FLUSH_BUDGET_USEC:
			SettlementPlanner.plan(_world, self, true)
	if (GameManager.tick_count + maxi(1, heavy_planner_interval / 3)) % heavy_planner_interval == 0:
		if Time.get_ticks_usec() - flush_start <= FLUSH_BUDGET_USEC:
			EconomyManager.get_trade_planner().plan(_world, self, true)
	MemoryManager.flush_dirty_tiles(_world)
# OPTIMIZATION: Deferred heavy operations for frame budget management
func _deferred_settlement_memory_recompute(world: World) -> void:
	if is_instance_valid(world):
		SettlementMemory.recompute(world)


func _deferred_settlement_rebirth_process(world: World, main: Node) -> void:
	if is_instance_valid(world) and is_instance_valid(main):
		SettlementManager.process(world, main, false)


# OPTIMIZATION: Deferred planning functions for frame budget management
func _deferred_settlement_planner_plan(world: World, main: Node, use_cache: bool) -> void:
	if is_instance_valid(world) and is_instance_valid(main):
		SettlementPlanner.plan(world, main, use_cache)

func _deferred_trade_planner_plan(world: World, main: Node, use_cache: bool) -> void:
	if is_instance_valid(world) and is_instance_valid(main):
		EconomyManager.get_trade_planner().plan(world, main, use_cache)


func _maybe_generational_turnover() -> void:
	if _pawn_spawner == null or not is_instance_valid(_world) or _world.data == null:
		return
	var t: int = GameManager.tick_count
	if t - _last_generation_tick < GENERATION_TICKS:
		return
	# OPTIMIZATION: Use pawn count from spawner instead of iterating
	var alive: int = _pawn_spawner.pawns.size()
	if alive == 0:
		return
	var sp: Vector2i = _find_generational_spawn_tile_optimized()
	_last_generation_tick = t
	if sp.x < 0:
		return
	_pawn_spawner.spawn_generational_pawn(_world, sp, t)


func _record_social_pair_events(a: HeelKawnianData, b: HeelKawnianData, max_events: int) -> int:
	var used: int = 0
	if max_events <= 0:
		return 0
	var a_id: int = int(a.id)
	var b_id: int = int(b.id)
	var key: String = _social_pair_key(a_id, b_id)
	var now: int = GameManager.tick_count
	var last_tick: int = int(_social_meeting_last_tick_by_pair.get(key, -1))
	var rapport: int = mini(
		int(a.get_social_rapport(b_id)),
		int(b.get_social_rapport(a_id))
	)
	var meet_should_log: bool = last_tick < 0 or now - last_tick >= SOCIAL_MEETING_EVENT_COOLDOWN_TICKS
	if meet_should_log and used < max_events:
		_social_meeting_last_tick_by_pair[key] = now
		WorldMemory.record_event({
			"type": "social_meeting",
			"category": "social",
			"severity": 2,
			"tick": now,
			"a": a_id,
			"b": b_id,
			"a_name": a.display_name,
			"b_name": b.display_name,
			"rapport": rapport,
			"region": _WM._region_key(a.tile_pos.x, a.tile_pos.y),
			"tile": {"x": a.tile_pos.x, "y": a.tile_pos.y},
		})
		used += 1
	var previous_milestone: int = int(_social_rapport_milestone_by_pair.get(key, 0))
	for m in SOCIAL_RAPPORT_MILESTONES:
		if used >= max_events:
			break
		var milestone: int = int(m)
		if milestone <= previous_milestone:
			continue
		if rapport < milestone:
			continue
		_social_rapport_milestone_by_pair[key] = milestone
		WorldMemory.record_event({
			"type": "social_bond_milestone",
			"category": "social",
			"severity": 3,
			"tick": now,
			"a": a_id,
			"b": b_id,
			"a_name": a.display_name,
			"b_name": b.display_name,
			"rapport": rapport,
			"milestone": milestone,
			"region": _WM._region_key(a.tile_pos.x, a.tile_pos.y),
			"tile": {"x": a.tile_pos.x, "y": a.tile_pos.y},
		})
		used += 1
	return used


func _social_pair_key(a_id: int, b_id: int) -> String:
	var lo: int = mini(a_id, b_id)
	var hi: int = maxi(a_id, b_id)
	return "%d-%d" % [lo, hi]


func _accumulate_social_rapport() -> void:
	if _pawn_spawner == null or _world == null or _world.pathfinder == null:
		return
	const R2: float = 128.0 * 128.0
	const GAIN: int = 14
	const OPINION_GAIN: int = 2
	const CELL_SIZE: float = 160.0  # Grid cell size, slightly larger than proximity radius
	var pl: Array[HeelKawnian] = []
	for p in _pawn_spawner.pawns:
		if p != null and is_instance_valid(p) and p.data != null:
			pl.append(p)
	if pl.size() < 2:
		return
	# Spatial grid: only check pairs within the same or adjacent cells
	var grid: Dictionary = {}
	for p in pl:
		var cx: int = int(p.position.x / CELL_SIZE)
		var cy: int = int(p.position.y / CELL_SIZE)
		var key: int = cx * 10000 + cy
		if not grid.has(key):
			grid[key] = []
		grid[key].append(p)
	# OPTIMIZATION: Early exit if grid is sparse (no cell has 2+ pawns)
	var crowded_cells: Array = []
	for cell_key in grid:
		if (grid[cell_key] as Array).size() >= 2:
			crowded_cells.append(cell_key)
	if crowded_cells.is_empty():
		return  # No cells with multiple pawns, no social interactions possible
	
	var wm_budget: int = SOCIAL_WM_RECORD_BUDGET_PER_PASS
	var comp_by_id: Dictionary = {}
	for p in pl:
		comp_by_id[int(p.data.id)] = _world.pathfinder.component_of(p.data.tile_pos)
	var checked_pairs: Dictionary = {}
	
	# OPTIMIZATION: Only process crowded cells and their neighbors
	for cell_key in crowded_cells:
		var cx: int = cell_key / 10000
		var cy: int = cell_key % 10000
		# Gather pawns from this cell and 8 neighbors
		var nearby: Array[HeelKawnian] = []
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var nk: int = (cx + dx) * 10000 + (cy + dy)
				if grid.has(nk):
					nearby.append_array(grid[nk])
		# OPTIMIZATION: Skip if still not enough pawns for interaction
		if nearby.size() < 2:
			continue
		
		var cell_pawns: Array = grid[cell_key] as Array
		for pa in cell_pawns:
			var da: HeelKawnianData = pa.data
			if da == null or pa.is_sleeping():
				continue
			var da_id: int = int(da.id)
			var da_comp: int = int(comp_by_id.get(da_id, -1))
			if da_comp < 0:
				continue
			# OPTIMIZATION: Pre-filter nearby by hunger and sleep state
			for pb in nearby:
				if pb == pa:
					continue
				var db: HeelKawnianData = pb.data
				if db == null or pb.is_sleeping():
					continue
				var db_id: int = int(db.id)
				# Avoid double-processing: only process if pa.id < pb.id
				if da_id >= db_id:
					continue
				var pair_key: int = da_id * 100000 + db_id
				if checked_pairs.has(pair_key):
					continue
				checked_pairs[pair_key] = true
				# OPTIMIZATION: Early exit checks before expensive operations
				if da.hunger <= 38.0 or db.hunger <= 38.0:
					continue
				var db_comp: int = int(comp_by_id.get(db_id, -1))
				if da_comp != db_comp:
					continue
				# Distance check is already squared, no sqrt needed
				if pa.position.distance_squared_to(pb.position) > R2:
					continue
				da.add_social_rapport(db_id, GAIN)
				db.add_social_rapport(da_id, GAIN)
				da.modify_character_opinion(db_id, OPINION_GAIN)
				db.modify_character_opinion(da_id, OPINION_GAIN)
				if wm_budget > 0:
					var n: int = _record_social_pair_events(da, db, wm_budget)
					wm_budget -= n


func _process_reproduction_tick() -> void:
	if _pawn_spawner == null:
		return
	for p in _pawn_spawner.pawns:
		if p == null or not is_instance_valid(p):
			continue
		if p.attempt_reproduction():
			# Limit to one birth per check window for stability.
			return


func _update_pawn_influence_tick() -> void:
	if _pawn_spawner == null:
		return
	var living: Array[HeelKawnian] = []
	for p in _pawn_spawner.pawns:
		if p != null and is_instance_valid(p) and p.data != null:
			living.append(p)
	var population: int = living.size()
	for p in living:
		p.data.calculate_influence(population)


## Best region: max [CulturalMemory] reputation, then min [WorldPersistence] scar, then lowest region_key.
## Tile: first passable plains/forest on main landmass, row-major within that region, not occupied.
## OPTIMIZED VERSION: Sample fewer regions, early exit on good enough tile
func _find_generational_spawn_tile_optimized() -> Vector2i:
	var out: Vector2i = Vector2i(-1, -1)
	var comp: int = _world.pathfinder.largest_component_id()
	if comp < 0:
		return out
	
	# OPTIMIZATION: Sample only 25% of regions (every other in each direction)
	var nrx: int = int((WorldData.WIDTH + 15) / 16.0)
	var nry: int = int((WorldData.HEIGHT + 15) / 16.0)
	var best_rk: int = 0x7FFFFFFF
	var best_rep: int = -9999
	var best_sl: int = 9999
	
	# Randomized sampling pattern based on tick for variety
	var sample_offset: int = int(GameManager.tick_count / GENERATION_TICKS)
	for ry in range(0, nry, 2):  # Every other row
		for rx in range(0, nrx, 2):  # Every other column
			var x0: int = ((rx + sample_offset) % nrx) * 16
			var y0: int = ((ry + sample_offset) % nry) * 16
			var rk: int = _WM._region_key(x0, y0)
			var t1: Vector2i = _first_valid_gen_tile_in_block(x0, y0, comp)
			if t1.x < 0:
				continue
			var rep: int = CulturalMemory.get_region_reputation(rk)
			var sl: int = int(WorldPersistence.get_region_persistence(rk).get("scar_level", 0))
			var take: bool = false
			if rep > best_rep:
				take = true
			elif rep == best_rep and sl < best_sl:
				take = true
			elif rep == best_rep and sl == best_sl and rk < best_rk:
				take = true
			if take:
				best_rk = rk
				best_rep = rep
				best_sl = sl
				out = t1
			# EARLY EXIT: Good enough tile found (high rep, low scar)
			if rep >= 50 and sl <= 1:
				return out
	if out.x < 0:
		return Vector2i(-1, -1)
	return out


## Original full-scan version kept for reference
func _find_generational_spawn_tile() -> Vector2i:
	var out: Vector2i = Vector2i(-1, -1)
	var comp: int = _world.pathfinder.largest_component_id()
	if comp < 0:
		return out
	var nrx: int = int((WorldData.WIDTH + 15) / 16.0)
	var nry: int = int((WorldData.HEIGHT + 15) / 16.0)
	var best_rk: int = 0x7FFFFFFF
	var best_rep: int = -9999
	var best_sl: int = 9999
	for ry in range(nry):
		for rx in range(nrx):
			var x0: int = rx * 16
			var y0: int = ry * 16
			var rk: int = _WM._region_key(x0, y0)
			var t1: Vector2i = _first_valid_gen_tile_in_block(x0, y0, comp)
			if t1.x < 0:
				continue
			var rep: int = CulturalMemory.get_region_reputation(rk)
			var sl: int = int(WorldPersistence.get_region_persistence(rk).get("scar_level", 0))
			var take: bool = false
			if rep > best_rep:
				take = true
			elif rep == best_rep and sl < best_sl:
				take = true
			elif rep == best_rep and sl == best_sl and rk < best_rk:
				take = true
			if take:
				best_rk = rk
				best_rep = rep
				best_sl = sl
				out = t1
	if out.x < 0:
		return Vector2i(-1, -1)
	return out


func _first_valid_gen_tile_in_block(
		x0: int,
		y0: int,
		main_comp: int
) -> Vector2i:
	for dy in range(16):
		for dx in range(16):
			var tx: int = x0 + dx
			var ty: int = y0 + dy
			if tx >= WorldData.WIDTH or ty >= WorldData.HEIGHT:
				continue
			if not PawnSpawner.SPAWNABLE_BIOMES.has(_world.data.get_biome(tx, ty)):
				continue
			if not _world.pathfinder.is_passable(Vector2i(tx, ty)):
				continue
			if _world.pathfinder.component_of(Vector2i(tx, ty)) != main_comp:
				continue
			var c: Vector2i = Vector2i(tx, ty)
			if _is_tile_occupied_by_pawn(c):
				continue
			return c
	return Vector2i(-1, -1)


func _is_tile_occupied_by_pawn(tile: Vector2i) -> bool:
	if _pawn_spawner == null:
		return false
	for p in _pawn_spawner.pawns:
		if p != null and is_instance_valid(p) and p.data != null and p.data.tile_pos == tile:
			return true
	return false


func _init_ambient_audio() -> void:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = AMBIENT_MIX_RATE
	stream.buffer_length = 0.45
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.name = "AmbientPlayer"
	_ambient_player.stream = stream
	_ambient_player.volume_db = -19.0
	_ambient_player.bus = "Master"
	add_child(_ambient_player)
	_ambient_player.play()
	_ambient_playback = _ambient_player.get_stream_playback() as AudioStreamGeneratorPlayback


func _update_ambient_target() -> void:
	var is_night: bool = DayNightCycle.is_night_for_tick(GameManager.tick_count)
	_ambient_freq_target = 76.0 if is_night else 112.0
	_ambient_freq_target += AgeMemory.get_ambient_freq_shift()
	if _enemy_spawner != null:
		var threat: float = float(_enemy_spawner.get_enemy_count())
		_ambient_freq_target += min(28.0, threat * 1.8)
	
	# Add settlement identity depth to frequency
	var camera_tile: Vector2i = _world.world_to_tile(_camera.global_position) if _world != null and _camera != null else Vector2i(-1, -1)
	if camera_tile.x >= 0:
		var region_key: int = _WM._region_key(camera_tile.x, camera_tile.y)
		var settlement: Variant = SettlementMemory.get_settlement_at_region(region_key)
		if settlement is Dictionary:
			# Population density affects frequency (more people = slightly higher pitch)
			var population: int = int(settlement.get("population", 0))
			_ambient_freq_target += min(12.0, float(population) * 0.05)
			
			# Resource pressure adds tension to frequency
			var food_pressure: float = float(settlement.get("food_pressure", 0.0))
			if food_pressure > 0.7:
				_ambient_freq_target += 8.0  # Tense, higher pitch when food is scarce


func _get_meaning_ambient_mood_target() -> float:
	if not is_instance_valid(_world) or _camera == null or _world.data == null:
		_meaning_style_bias = 0.0
		return 0.5
	var t: Vector2i = _world.world_to_tile(_camera.global_position)
	if t.x < 0:
		_meaning_style_bias = 0.0
		return 0.5
	var rk: int = _WM._region_key(t.x, t.y)
	var m: float
	var sv: Variant = SettlementMemory.get_settlement_at_region(rk)
	var st_here: String = ""
	var intent_here: int = IntentMemory.INTENT_HOLD
	if sv is Dictionary:
		_meaning_style_bias = SettlementPlanner.get_culture_audio_bias_for_settlement(sv as Dictionary)
		st_here = str((sv as Dictionary).get("state", ""))
		var ckr_here: int = int((sv as Dictionary).get("center_region", -1))
		intent_here = int(IntentMemory.settlement_intent.get(ckr_here, IntentMemory.INTENT_HOLD))
		
		# Settlement identity depth: mood reflects settlement vitality
		var work_focus: String = str((sv as Dictionary).get("work_focus_phase", "unknown"))
		var specialization_score: float = float((sv as Dictionary).get("work_focus_confidence", 0.0))
		
		if st_here == "permanently_abandoned":
			m = 0.0
		elif st_here == "abandoned":
			m = 0.15
		elif st_here == "revivable":
			m = 0.92
		elif st_here == "dormant":
			m = 0.46
		else:
			# Active settlement: mood reflects specialization and work focus
			m = 0.5
			# Higher specialization = more confident, positive mood
			m += specialization_score * 0.3
			# Adjust based on work focus
			match work_focus:
				"forage":
					m += 0.05  # Gathering food = content
				"build":
					m += 0.08  # Building = purposeful
				"defend":
					m -= 0.1  # Defense = tense
				"trade":
					m += 0.12  # Trade = prosperous
				"worship":
					m += 0.07  # Worship = spiritual
			m = clampf(m, 0.0, 1.0)
	else:
		_meaning_style_bias = 0.0
		var sl: int = int(WorldPersistence.get_region_persistence(rk).get("scar_level", 0))
		if sl >= 3:
			m = 0.12
		elif sl <= 1:
			m = 0.72
		else:
			m = 0.4
	if st_here != "permanently_abandoned":
		if intent_here == IntentMemory.INTENT_GROW:
			m = lerpf(m, 1.0, 0.08)
		elif intent_here == IntentMemory.INTENT_ABANDON:
			m = lerpf(m, 0.0, 0.12)
	var rep: int = CulturalMemory.get_region_reputation(rk)
	if rep <= -2:
		m = lerpf(m, 0.1, 0.38)
	var myth_s: int = MythMemory.get_region_myth_state(rk)
	if myth_s == 1:
		m = lerpf(m, 0.0, 0.1)
	elif myth_s == -1:
		m = lerpf(m, 1.0, 0.12)
	return m


func _update_camera_meaning_bias(delta: float) -> void:
	if GameManager.is_paused or not is_instance_valid(_world) or _camera == null or _world.data == null:
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		return
	# Throttle: camera bias changes slowly, no need to recalculate every frame
	_meaning_cam_bias_timer += delta
	if _meaning_cam_bias_timer < 0.2:
		return
	_meaning_cam_bias_timer = 0.0
	var vel: Vector2 = Vector2.ZERO
	for s in SettlementMemory.settlements:
		if s is not Dictionary:
			continue
		var d: Dictionary = s as Dictionary
		var st: String = str(d.get("state", ""))
		if st != "revivable" and st != "abandoned" and st != "permanently_abandoned":
			continue
		var ckr: int = int(d.get("center_region", -1))
		if ckr < 0:
			continue
		var tcx: int = (ckr & 0xFFFF) * 16 + 8
		var tcy: int = ((ckr >> 16) & 0xFFFF) * 16 + 8
		var target: Vector2 = _world.tile_to_world(Vector2i(tcx, tcy))
		var to_t: Vector2 = target - _camera.global_position
		var intent_s: int = int(IntentMemory.settlement_intent.get(ckr, IntentMemory.INTENT_HOLD))
		if st == "revivable":
			var attract: float = MEANING_CAM_REVIV_P
			if intent_s == IntentMemory.INTENT_GROW:
				attract *= 1.14
			elif intent_s == IntentMemory.INTENT_ABANDON:
				attract *= 0.88
			vel += to_t * attract
		elif st == "permanently_abandoned":
			var repel_perm: float = MEANING_CAM_PERM_ABAND_P
			if intent_s == IntentMemory.INTENT_ABANDON:
				repel_perm *= 1.12
			vel -= to_t * repel_perm
		else:
			var repel_ab: float = MEANING_CAM_ABAND_P
			if intent_s == IntentMemory.INTENT_ABANDON:
				repel_ab *= 1.1
			elif intent_s == IntentMemory.INTENT_GROW:
				repel_ab *= 0.92
			vel -= to_t * repel_ab
	var t0: Vector2i = _world.world_to_tile(_camera.global_position)
	if t0.x >= 0:
		var rk0: int = _WM._region_key(t0.x, t0.y)
		var rxc: int = (rk0 & 0xFFFF) * 16 + 8
		var ryc: int = ((rk0 >> 16) & 0xFFFF) * 16 + 8
		var rcenter: Vector2 = _world.tile_to_world(Vector2i(rxc, ryc))
		var cam0: Vector2 = _camera.global_position
		var sc: int = int(WorldPersistence.get_region_persistence(rk0).get("scar_level", 0))
		if sc >= 3:
			vel += (cam0 - rcenter) * MEANING_CAM_SCAR3_P
		elif sc <= 1:
			vel += (rcenter - cam0) * MEANING_CAM_LOSCAR_P
		var cr: int = CulturalMemory.get_region_reputation(rk0)
		if cr <= -2:
			vel += (cam0 - rcenter) * (0.0002 * (float(mini(8, -2 - cr)) / 6.0))
		var msc: int = MythMemory.get_region_myth_state(rk0)
		if msc == 1:
			vel += (cam0 - rcenter) * 0.00011
		elif msc == -1:
			vel += (rcenter - cam0) * 0.00009
	var spd: float = clampf(float(GameManager.game_speed), 1.0, 26.0)
	vel *= 1.0 / sqrt(spd)
	vel = vel.limit_length(MEANING_CAM_VEL_MAX)
	_camera.position += vel * delta


func _update_ambient_audio(delta: float) -> void:
	if _ambient_playback == null and _ambient_player != null and is_instance_valid(_ambient_player):
		if not _ambient_player.playing:
			_ambient_player.play()
		_ambient_playback = _ambient_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if _ambient_playback == null:
		return
	var frames: int = _ambient_playback.get_frames_available()
	if frames <= 0:
		return
	# Cap work per update to keep CPU bound.
	frames = min(frames, MAX_AMBIENT_AUDIO_FRAMES_PER_UPDATE)
	var interp: float = min(1.0, delta * 2.6)
	_ambient_freq_current = lerpf(_ambient_freq_current, _ambient_freq_target, interp)
	var mood: float = _meaning_ambient_mood
	var style_mix: float = clampf(_meaning_style_bias, -0.28, 0.28)
	var base_layer: float = lerpf(0.84, 0.60, 1.0 - mood) + style_mix * -0.22
	var otone_layer: float = lerpf(0.14, 0.38, mood) + style_mix * 0.26
	base_layer = clampf(base_layer, 0.48, 0.92)
	otone_layer = clampf(otone_layer, 0.08, 0.44)
	var amp: float = AMBIENT_BASE_AMP * lerpf(0.58, 1.06, mood)
	if GameManager.is_paused:
		amp *= 0.45
	if _ambient_player != null:
		_ambient_player.volume_db = lerpf(-26.0, -17.2, mood)
	for _i in range(frames):
		_ambient_phase += TAU * _ambient_freq_current / float(AMBIENT_MIX_RATE)
		if _ambient_phase > TAU:
			_ambient_phase -= TAU
		var base: float = sin(_ambient_phase)
		var overtone: float = sin(_ambient_phase * 0.5 + 0.4)
		var s: float = (base * base_layer + overtone * otone_layer) * amp
		_ambient_playback.push_frame(Vector2(s, s))


func _on_speed_changed(speed: float, paused: bool) -> void:
	if not OS.is_debug_build():
		return
	if paused:
		print("[Main] PAUSED")
	else:
		print("[Main] Speed: %.1fx" % speed)


func _unhandled_key_input(event: InputEvent) -> void:
	if not _hotkeys_enabled:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	# When the F10 creator menu is open, number keys are used for report labels.
	# Ignore global gameplay hotkeys so menu interaction never changes sim speed.
	if _creator_debug_menu != null and _creator_debug_menu.visible:
		return
	# ESC toggles settings panel (takes priority over other hotkeys)
	if event.keycode == Key.KEY_ESCAPE:
		if _settings_panel != null:
			_settings_panel.toggle()
		return
	match event.keycode:
		Key.KEY_QUOTELEFT:
			_toggle_play_chrome()
		Key.KEY_G:
			if _selected_pawn != null and is_instance_valid(_selected_pawn):
				_camera_follow_selected = not _camera_follow_selected
				if OS.is_debug_build():
					print("[Main] Camera follow selection: %s" % _camera_follow_selected)
			else:
				_camera_follow_selected = false
		Key.KEY_EQUAL:
			if _hud != null:
					_hud.toggle_hud_verbose()
		Key.KEY_KP_ADD:
			if _hud != null:
				_hud.toggle_hud_verbose()
		Key.KEY_SPACE:
			GameManager.toggle_pause()
		# PHASE 6: Speed controls disabled when incarnated (pawns can't control time)
		Key.KEY_1:
			if _is_player_incarnated():
				print("[Main] Speed controls disabled during incarnation (pawns can't control time)")
				return
			if ALLOW_SPEED_NUMBER_HOTKEYS:
				GameManager.set_speed_index(0)
		Key.KEY_2:
			if _is_player_incarnated():
				print("[Main] Speed controls disabled during incarnation")
				return
			if ALLOW_SPEED_NUMBER_HOTKEYS:
				GameManager.set_speed_index(1)
		Key.KEY_3:
			if _is_player_incarnated():
				print("[Main] Speed controls disabled during incarnation")
				return
			if ALLOW_SPEED_NUMBER_HOTKEYS:
				GameManager.set_speed_index(2)
		Key.KEY_4:
			if _is_player_incarnated():
				print("[Main] Speed controls disabled during incarnation")
				return
			if ALLOW_SPEED_NUMBER_HOTKEYS:
				GameManager.set_speed_index(3)
		Key.KEY_5:
			if _is_player_incarnated():
				print("[Main] Speed controls disabled during incarnation")
				return
			if ALLOW_SPEED_NUMBER_HOTKEYS:
				GameManager.set_speed_index(4)
		Key.KEY_6:
			if _is_player_incarnated():
				print("[Main] Speed controls disabled during incarnation")
				return
			if ALLOW_SPEED_NUMBER_HOTKEYS:
				GameManager.set_speed_index(5)
		Key.KEY_7:
			if _is_player_incarnated():
				print("[Main] Speed controls disabled during incarnation")
				return
			if ALLOW_SPEED_NUMBER_HOTKEYS:
				GameManager.set_speed_index(6)
		Key.KEY_R:
			if OS.is_debug_build():
				_reroll_world()
		Key.KEY_K:
			_toggle_avatar_panel()
		Key.KEY_T:
			_pawn_spawner.print_stats()
		Key.KEY_J:
			_toggle_settlement_mind_panel()
		Key.KEY_I:
			_print_stockpile()
		Key.KEY_D:
			_toggle_draft_mode()
		Key.KEY_F5:
			_colony_save()
		Key.KEY_F8:
			if event.shift_pressed:
				_colony_load()
			elif TimeLapseRecorder != null and TimeLapseRecorder.has_method("toggle_mode"):
				TimeLapseRecorder.toggle_mode()
			else:
				_colony_load()
		Key.KEY_F9:
			# PHASE 6: Observer HUD disabled when incarnated (pawns don't see omniscient HUD)
			if _is_player_incarnated():
				print("[Main] Observer HUD disabled during incarnation (pawns don't have omniscient view)")
				return
			if event.shift_pressed:
				_cycle_realm_crown_max_settlements()
				if _observer_hud != null and _observer_hud.is_visible_state():
					_observer_hud.apply_snapshot(_build_observer_snapshot(GameManager.tick_count))
				return
			_toggle_observer_hud()
		Key.KEY_F10:
			# PHASE 6: Debug menu disabled when incarnated (pawns don't have debug menus)
			if _is_player_incarnated():
				print("[Main] F10 debug menu disabled during incarnation")
				return
			if _creator_debug_menu != null:
				_creator_debug_menu.toggle_menu()
		Key.KEY_F6:
			_toggle_focus_inspector()
		Key.KEY_F11:
			if _kernel_diagnostic != null and _kernel_diagnostic.has_method("start_settlement_truth_verification"):
				_kernel_diagnostic.call("start_settlement_truth_verification")
		Key.KEY_F12:
			_debug_capture_resource_truth()
			# F7: export chronicle
		Key.KEY_F7:
			_export_chronicle()
		# F3: debug grant Krond (25)
		Key.KEY_F3:
			if OS.is_debug_build():
				_debug_grant_krond()
		Key.KEY_M:
			ColonySimServices.cycle_labor_stance()
		KEY_C:
			if _chronicle_feed != null:
				_chronicle_feed.toggle()
		Key.KEY_P:
			request_incarnation_entry()
		Key.KEY_BACKSPACE:
			request_spectator_return()
		Key.KEY_ENTER:
			if _incarnation_picker != null and is_instance_valid(_incarnation_picker) and _incarnation_picker.visible:
				_on_incarnation_entry_confirmed(int(_incarnation_picker.call("get_selected_pawn_id")))
		Key.KEY_ESCAPE:
			if _creator_debug_menu != null and _creator_debug_menu.visible:
				_creator_debug_menu.visible = false
				return
			if _incarnation_picker != null and is_instance_valid(_incarnation_picker) and _incarnation_picker.visible:
				_incarnation_picker.call("close_picker")
				return
			if _player_mode == PlayerMode.INCARNATED:
				if OS.is_debug_build():
					print("[Main] Esc ignored while incarnated; use Backspace to return to spectator")
				return
			# Esc clears either a drag-in-progress, an active build mode, or
			# a pawn selection (in that priority order). Each extra Esc peels
			# off the next layer.
			if _hud != null:
				_hud.hide_tile_history()
			if _is_dragging:
				_cancel_drag()
			elif _designation_mode != DesignationMode.NONE:
				_set_designation_mode(DesignationMode.NONE)
			elif _selected_pawn != null:
				_set_selected_pawn(null)
		Key.KEY_HOME:
			if _camera != null and _camera.has_method("reset_to_world_bounds"):
				_camera.call("reset_to_world_bounds", _world)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key: InputEventKey = event
		if key.pressed:
			_handle_key_input(key)
			return
	# Watch mode is intentionally non-interactive with the simulation layer.
	# Camera/navigation can still work in dedicated camera scripts.
	if _is_watch_mode():
		if event is InputEventMouseButton:
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion:
		_update_hover_tile(event.position)
		# Safety net: if the toolbar / HUD swallowed the mouse-release (e.g.
		# the player ended a drag over a UI button), we never got
		# _on_left_release. Detect it here by polling the raw button state
		# and cancel instead of leaving the drag stuck forever.
		if _is_dragging and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			_cancel_drag()
			return
		if _is_dragging:
			_drag_current = _hover_tile
			if _designation_mode == DesignationMode.BUILD_WALL:
				_update_wall_path_preview()
			_queue_designation_redraw()
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		match mb.button_index:
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_on_left_press()
				else:
					_on_left_release()
			MOUSE_BUTTON_RIGHT:
				if mb.pressed:
					_on_right_press()

	# Physics fallback for pawn selection
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return

	var screen_pos: Vector2 = mb.position
	var world_pos: Vector2 = get_global_mouse_position()

	var query := PhysicsPointQueryParameters2D.new()
	query.position = world_pos
	query.collide_with_areas = true
	query.collide_with_bodies = true

	var results: Array = get_world_2d().direct_space_state.intersect_point(query, 32)

	last_click_screen_position = screen_pos
	last_click_world_position = world_pos
	last_click_method = "physics_query_fallback"
	last_click_candidates_count = results.size()

	var found_pawn: Node = null
	for hit in results:
		if not (hit is Dictionary):
			continue
		var collider: Object = hit.get("collider", null)
		if collider == null:
			continue
		var n: Node = collider as Node
		if n == null:
			continue

		if n.name == "ClickArea" and n.get_parent() != null:
			found_pawn = n.get_parent()
			break

		var p: Node = n
		while p != null:
			if p.has_method("visual_truth_snapshot") or p.is_in_group("pawns") or p.is_in_group("heelkawnians"):
				found_pawn = p
				break
			p = p.get_parent()
		if found_pawn != null:
			break

	if found_pawn != null:
		_record_pawn_click_selection(found_pawn, "physics_query_fallback", screen_pos, world_pos, results.size())
	else:
		last_selection_success = false
		selection_manual_click_proven = false
		last_selected_pawn_id = -1
		last_selected_pawn_path = "none"
		last_selection_failure_reason = "no_live_physics_candidate"


func _handle_key_input(key: InputEventKey) -> void:
	if _is_watch_mode():
		var allow_watch_transition: bool = (
			(key.keycode == KEY_T and key.ctrl_pressed)
			or (key.keycode == KEY_G and key.ctrl_pressed)
			or (key.keycode == KEY_O)
			or (key.keycode == KEY_ESCAPE)
		)
		if not allow_watch_transition:
			return
	match key.keycode:
		KEY_I:
			_toggle_region_inspector()
		KEY_T:
			if key.ctrl_pressed:
				_toggle_incarnation_mode()
			else:
				_toggle_timeline_controls()
		KEY_R:
			_toggle_trade_overview()
		KEY_O:
			_open_incarnation_picker()
		KEY_L:
			_toggle_chronicle_ledger()
		KEY_TAB:
			_toggle_inventory()
		KEY_B:
			_toggle_build_mode()
		KEY_K:
			_toggle_pawn_ai_inspector()
		KEY_U:
			_toggle_trait_shop()
		KEY_N:
			_toggle_consciousness_panel()
		KEY_H:
			_toggle_dialogue_panel()
		Key.KEY_ESCAPE:
			_handle_cancel_action()
		KEY_F12:
			_toggle_debug_panel()
		KEY_Z:
			if key.ctrl_pressed and _command_mode != null:
				_cycle_zone_type()
		KEY_G:
			if key.ctrl_pressed:
				_toggle_observer_mode()
			elif key.shift_pressed and _command_mode != null:
				_command_mode.set_zone_type(1)  # FORAGE_ZONE
			elif _selected_pawn != null and is_instance_valid(_selected_pawn):
				_camera_follow_selected = not _camera_follow_selected
				if OS.is_debug_build():
					print("[Main] Camera follow selection: %s" % _camera_follow_selected)
			else:
				_camera_follow_selected = false


func _toggle_inventory() -> void:
	if _inventory_ui != null:
		if _inventory_ui.has_method("toggle_inventory"):
			_inventory_ui.call("toggle_inventory")
		else:
			_inventory_ui.visible = not _inventory_ui.visible


func _toggle_build_mode() -> void:
	# Toggle between NONE and BUILD_BED as starting build mode
	if _designation_mode == DesignationMode.NONE:
		_set_designation_mode(DesignationMode.BUILD_BED)
	else:
		_set_designation_mode(DesignationMode.NONE)


func _toggle_debug_panel() -> void:
	if _debug_panel == null or not is_instance_valid(_debug_panel):
		_ensure_debug_panel()
	if _debug_panel != null and is_instance_valid(_debug_panel):
		_debug_panel.visible = not _debug_panel.visible


func _handle_cancel_action() -> void:
	if _settlement_mind_panel != null and is_instance_valid(_settlement_mind_panel) and _settlement_mind_panel.visible:
		_settlement_mind_panel.close_panel()
		return
	if _dialogue_panel != null and is_instance_valid(_dialogue_panel) and _dialogue_panel.visible:
		_dialogue_panel.close_panel()
		return
	if _is_dragging:
		_cancel_drag()
		return
	if _designation_mode != DesignationMode.NONE:
		_set_designation_mode(DesignationMode.NONE)
		return
	if _selected_pawn != null:
		_set_selected_pawn(null)
		if _hud != null:
			_hud.hide_tile_history()
		return
	# If nothing else to cancel, maybe open pause menu (legacy)
	pass
		

## Debug: export chronicle to user://exports/chronicle_<tick>.json
func _export_chronicle() -> void:
	var tick: int = 0
	if Engine.has_singleton("GameManager") and GameManager != null:
		tick = GameManager.tick_count
	var dir_path: String = "user://exports"
	var da := DirAccess.open("user://")
	if da != null:
		da.make_dir_recursive("exports")
	var file_path: String = "%s/chronicle_%d.json" % [dir_path, tick]
	var ok: bool = false
	if WorldMemory != null and WorldMemory.has_method("export_chronicle"):
		ok = WorldMemory.export_chronicle(file_path)
	if OS.is_debug_build():
		print("[Main] Chronicle export -> %s  ok=%s" % [file_path, str(ok)])
	if ok and _chronicle_ledger != null:
		_chronicle_ledger.queue_free()

## Cycle through zone designation types (Ctrl+Z)
func _cycle_zone_type() -> void:
	if _command_mode == null:
		return
	var current: int = _command_mode._zone_type
	var next: int = (current + 1) % 5  # NONE, FORAGE, BUILD, DEFEND, STORAGE
	_command_mode.set_zone_type(next)
	var names: PackedStringArray = ["None", "Forage Zone", "Build Zone", "Defend Zone", "Storage Zone"]
	if next == 0:  # NONE
		_set_designation_mode(DesignationMode.NONE)
	elif next == 4:  # STORAGE_ZONE
		_set_designation_mode(DesignationMode.DESIGNATE_ZONE)
	if OS.is_debug_build():
		print("[Main] Zone type: %s" % names[next])


## Handler for zone_painted signal — triggers overlay redraw
func _on_zone_painted(_zone_type: String, _rect: Rect2i) -> void:
	_queue_designation_redraw()


func _on_structure_type_requested(structure_type: String) -> void:
	if OS.is_debug_build():
		print("[Main] Build structure requested: %s" % structure_type)
	
	match structure_type:
		"bed": _set_designation_mode(DesignationMode.BUILD_BED)
		"wall_wood", "wall_stone": _set_designation_mode(DesignationMode.BUILD_WALL)
		"door_wood": _set_designation_mode(DesignationMode.BUILD_DOOR)
		"shelter": _set_designation_mode(DesignationMode.BUILD_SHELTER)
		"storage_hut": _set_designation_mode(DesignationMode.BUILD_STORAGE_HUT)
		"fire_pit": _set_designation_mode(DesignationMode.BUILD_FIRE_PIT)
		"workshop": _set_designation_mode(DesignationMode.BUILD_WORKSHOP)


## Visual feedback when a command is issued to a pawn
func _on_command_issued(pawn: HeelKawnian, order_type: String, target_tile: Vector2i) -> void:
	if _command_indicator != null and _command_indicator.has_method("show_indicator"):
		_command_indicator.show_indicator(target_tile, order_type)
	var tick: int = 0
	if Engine.has_singleton("GameManager") and GameManager != null:
		tick = GameManager.tick_count
	var dir_path: String = "user://exports"
	var da := DirAccess.open("user://")
	if da != null:
		# create exports directory under user://
		da.make_dir_recursive("exports")
	var file_path: String = "%s/chronicle_%d.json" % [dir_path, tick]
	var ok: bool = false
	if WorldMemory != null and WorldMemory.has_method("export_chronicle"):
		ok = WorldMemory.export_chronicle(file_path)
	if OS.is_debug_build():
		print("[Main] Chronicle export -> %s  ok=%s" % [file_path, str(ok)])
	# notify ledger/UI if present
	if ok and _chronicle_ledger != null:
		_chronicle_ledger.queue_free() # force ledger refresh on next open


func _debug_grant_krond(amount: float = 25.0) -> void:
	if not OS.is_debug_build():
		return
	if _player_pawn == null or not is_instance_valid(_player_pawn):
		print("[Main] No player pawn to grant Krond to")
		return
	_player_pawn.data.grant_krond(amount)
	print("[Main] Granted %g Kr to pawn %s" % [amount, str(_player_pawn.data.id)])
	if _hud != null:
		_hud._refresh()


func _toggle_trait_shop() -> void:
	if _trait_shop != null and is_instance_valid(_trait_shop):
		# toggle visibility
		_trait_shop.visible = not _trait_shop.visible
		return
	# instantiate and attach (load at runtime to avoid circular preloads)
	var trait_script := ResourceLoader.load(TRAIT_SHOP_PATH) as Script
	if trait_script == null:
		print("[Main] Trait shop script not found")
		return
	var shop := trait_script.new() as Control
	if shop == null:
		print("[Main] Failed to instantiate TraitShop")
		return
	_trait_shop = shop
	$UI_Viewport.add_child(_trait_shop)
	_trait_shop.open_shop(_player_pawn)


func _set_hotkeys_enabled(enabled: bool) -> void:
	_hotkeys_enabled = enabled
	if OS.is_debug_build():
		print("[Main] Hotkeys enabled: %s" % str(_hotkeys_enabled))


func _toggle_region_inspector() -> void:
	if _region_inspector != null:
		_region_inspector.visible = not _region_inspector.visible
		if _region_inspector.visible and _world != null:
			var center_tile: Vector2i = Vector2i(WorldData.WIDTH >> 1, WorldData.HEIGHT >> 1)
			var region_key: int = _WM._region_key(center_tile.x, center_tile.y)
			_region_inspector.set_region(region_key)


func _toggle_timeline_controls() -> void:
	if _timeline_controls != null:
		_timeline_controls.visible = not _timeline_controls.visible


func _toggle_chronicle_ledger() -> void:
	if _chronicle_book != null:
		_chronicle_book._toggle_visibility()
	elif _chronicle_ledger != null:
		_chronicle_ledger._toggle_visibility()


func _toggle_trade_overview() -> void:
	if _trade_overview == null:
		var trade_overview_script: Script = load("res://scripts/ui/TradeOverviewPanel.gd") as Script
		if trade_overview_script == null:
			return
		_trade_overview = trade_overview_script.new() as CanvasLayer
		add_child(_trade_overview)
	_trade_overview.toggle()


func _on_seed_gallery_seed_selected(seed: int) -> void:
	if WorldRNG != null and WorldRNG.has_method("configure_from_seed"):
		WorldRNG.configure_from_seed(seed)
	if FootpathMemory != null and FootpathMemory.has_method("clear"):
		FootpathMemory.clear()
	if BuildingUsageTracker != null and BuildingUsageTracker.has_method("clear"):
		BuildingUsageTracker.clear()
	if SnowAccumulation != null and SnowAccumulation.has_method("clear"):
		SnowAccumulation.clear()
	if TimeLapseRecorder != null and TimeLapseRecorder.has_method("reset_session"):
		TimeLapseRecorder.reset_session()
	_reroll_world()
	_set_player_mode(PlayerMode.SPECTATOR)
	_update_hud_mode_badge()
	if TimeLapseRecorder != null and TimeLapseRecorder.has_method("record"):
		TimeLapseRecorder.record()
	if _main_menu != null:
		_main_menu.hide_menu()


func _on_seed_gallery_closed() -> void:
	if _main_menu != null:
		_main_menu.show_menu()


func _toggle_pawn_ai_inspector() -> void:
	if _pawn_ai_inspector != null:
		_pawn_ai_inspector._toggle_visibility()


func _open_incarnation_picker() -> void:
	if _incarnation_picker == null:
		return
	
	# Generate candidate pawns from existing pawns
	var candidates: Array = _generate_incarnation_candidates()
	var mode_label: String = "SPECTATOR" if _player_mode == PlayerMode.SPECTATOR else "INCARNATED"
	_incarnation_picker.open_with_candidates(candidates, mode_label)


func _generate_incarnation_candidates() -> Array:
	var candidates: Array = []
	var pawns: Array[HeelKawnian] = _pawn_spawner.get_all_pawns() if _pawn_spawner != null else PawnSpawner.find_pawns()

	for pawn in pawns:
		if not is_instance_valid(pawn):
			continue
		if pawn.data == null:
			continue
		
		var candidate: Dictionary = {
			"pawn_id": int(pawn.data.id),
			"name": str(pawn.data.display_name),
			"age": int(pawn.data.age),
			"region": _WM._region_key(pawn.data.tile_pos.x, pawn.data.tile_pos.y),
			"profession": str(pawn.data.profession),
			"state": "alive" if pawn.data.health > 0 else "dead",
			"role": "citizen",
			"priority_score": int(pawn.data.level * 10 + pawn.data.health),
			"priority_reason": "level and health",
			"hunger": pawn.data.hunger,
			"rest": pawn.data.rest,
			"mood": pawn.data.mood
		}
		
		# Only include living pawns
		if pawn.data.health > 0:
			candidates.append(candidate)
	
	# Sort by priority score (descending)
	candidates.sort_custom(func(a, b): return int(b.priority_score) - int(a.priority_score))
	
	# Return top 20 candidates
	return candidates.slice(0, 20)


func _init_phase8_proof_overlay() -> void:
	if not OS.is_debug_build():
		return
	if _phase8_proof_overlay_layer != null and is_instance_valid(_phase8_proof_overlay_layer):
		return
	_phase8_proof_overlay_layer = CanvasLayer.new()
	_phase8_proof_overlay_layer.name = "Phase8ProofOverlay"
	_phase8_proof_overlay_layer.layer = 30
	add_child(_phase8_proof_overlay_layer)
	_phase8_proof_overlay_text = RichTextLabel.new()
	_phase8_proof_overlay_text.name = "Phase8ProofOverlayText"
	# bbcode_enabled disabled for runtime stability
	# _phase8_proof_overlay_text.bbcode_enabled = false
	_phase8_proof_overlay_text.fit_content = false
	_phase8_proof_overlay_text.scroll_active = true
	_phase8_proof_overlay_text.selection_enabled = false
	_phase8_proof_overlay_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phase8_proof_overlay_text.position = Vector2(8, 56)
	_phase8_proof_overlay_text.size = Vector2(1240, 96)
	_phase8_proof_overlay_text.add_theme_font_size_override("normal_font_size", 13)
	_phase8_proof_overlay_layer.add_child(_phase8_proof_overlay_text)
	if not SettlementMemory.phase8_proof_bundle_emitted.is_connected(_on_phase8_proof_bundle_emitted):
		SettlementMemory.phase8_proof_bundle_emitted.connect(_on_phase8_proof_bundle_emitted)
	var terminal_line: String = SettlementMemory.get_phase8_proof_terminal_line()
	var last_line: String = ""
	if terminal_line != "":
		last_line = terminal_line
	else:
		last_line = SettlementMemory.get_phase8_proof_latest_bundle_line()
	if last_line == "":
		last_line = "[PHASE8_PROOF_BUNDLE] waiting_for_first_resource_truth_tick..."
	_phase8_proof_overlay_text.text = last_line
	_spatial_profile_overlay_text = RichTextLabel.new()
	_spatial_profile_overlay_text.name = "SpatialProfileOverlayText"
	# bbcode_enabled disabled for runtime stability
	# _spatial_profile_overlay_text.bbcode_enabled = false
	_spatial_profile_overlay_text.fit_content = false
	_spatial_profile_overlay_text.scroll_active = false
	_spatial_profile_overlay_text.selection_enabled = false
	_spatial_profile_overlay_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_spatial_profile_overlay_text.position = Vector2(8, 156)
	_spatial_profile_overlay_text.size = Vector2(1240, 88)
	_spatial_profile_overlay_text.add_theme_font_size_override("normal_font_size", 12)
	_phase8_proof_overlay_layer.add_child(_spatial_profile_overlay_text)
	_refresh_phase8_proof_overlay_style()
	_refresh_spatial_profile_overlay()


func _refresh_phase8_proof_overlay_style() -> void:
	if _phase8_proof_overlay_text == null or not is_instance_valid(_phase8_proof_overlay_text):
		return
	var terminal_line: String = SettlementMemory.get_phase8_proof_terminal_line()
	if terminal_line != "":
		_phase8_proof_overlay_text.add_theme_font_size_override("normal_font_size", 16)
	else:
		_phase8_proof_overlay_text.add_theme_font_size_override("normal_font_size", 13)


func _on_phase8_proof_bundle_emitted(bundle_line: String) -> void:
	if _phase8_proof_overlay_text == null or not is_instance_valid(_phase8_proof_overlay_text):
		return
	var terminal_line: String = SettlementMemory.get_phase8_proof_terminal_line()
	if terminal_line != "":
		_phase8_proof_overlay_text.text = terminal_line
	else:
		_phase8_proof_overlay_text.text = bundle_line
	_refresh_phase8_proof_overlay_style()
	_refresh_spatial_profile_overlay()


func _refresh_spatial_profile_overlay() -> void:
	if not OS.is_debug_build():
		return
	if _spatial_profile_overlay_text == null or not is_instance_valid(_spatial_profile_overlay_text):
		return


func _init_performance_monitor() -> void:
	# Create performance monitor overlay (toggle with F4)
	var pm_script := load("res://tools/diagnose/PerformanceMonitor.gd") as Script
	if pm_script != null:
		_performance_monitor = pm_script.new() as PerformanceMonitorUI
		if _performance_monitor != null:
			add_child(_performance_monitor)
			_performance_monitor.set_visible_custom(false)  # Start hidden


func _center_tile_from_region_key(center_region: int) -> Vector2i:
	if center_region < 0:
		return Vector2i(-1, -1)
	var rx: int = center_region & 0xFFFF
	var ry: int = (center_region >> 16) & 0xFFFF
	if rx & 0x8000:
		rx = -(0x10000 - rx)
	if ry & 0x8000:
		ry = -(0x10000 - ry)
	return Vector2i(rx * 16 + 8, ry * 16 + 8)


func _research_particle_color(settlement_id: int, tech_id: String, completed: bool) -> Color:
	var alpha: float = 0.80 if completed else 0.55
	match tech_id:
		"stone_knapping":
			return Color(0.58, 0.58, 0.58, alpha) # Stone = Gray
		"agriculture":
			return Color(0.38, 0.70, 0.38, alpha) # Agriculture = Green
		"masonry":
			return Color(0.46, 0.33, 0.20, alpha) # Masonry = Brown
		"metallurgy":
			return Color(0.86, 0.48, 0.17, alpha) # Metallurgy = Orange
		_:
			return Color(0.72, 0.72, 0.72, alpha)


func _spawn_research_particles(settlement_id: int, tech_id: String, completed: bool, progress: float) -> void:
	if _preview_layer == null or not is_instance_valid(_preview_layer):
		return
	var settlement_tile: Vector2i = _center_tile_from_region_key(settlement_id)
	if settlement_tile.x < 0 or _world == null:
		return
	if _research_particle_texture == null:
		var img: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		_research_particle_texture = ImageTexture.create_from_image(img)
	var particles: GPUParticles2D = GPUParticles2D.new()
	particles.name = "ResearchBurst_%s_%d" % [tech_id, GameManager.tick_count]
	particles.texture = _research_particle_texture
	particles.one_shot = true
	particles.emitting = false
	particles.amount = 10 if completed else 6
	particles.lifetime = 0.55 if completed else 0.35
	particles.explosiveness = 1.0
	particles.preprocess = 0.0
	particles.local_coords = false
	particles.position = _world.tile_to_world(settlement_tile)
	particles.z_index = 20
	var material: ParticleProcessMaterial = ParticleProcessMaterial.new()
	material.direction = Vector3(0.0, -1.0, 0.0)
	material.spread = 180.0
	material.gravity = Vector3(0.0, -10.0, 0.0)
	material.initial_velocity_min = 8.0 if completed else 5.0
	material.initial_velocity_max = 20.0 if completed else 12.0
	material.scale_min = 0.25
	material.scale_max = 0.60 if completed else 0.45
	particles.process_material = material
	particles.modulate = _research_particle_color(settlement_id, tech_id, completed)
	_preview_layer.add_child(particles)
	particles.emitting = true
	var cleanup: Timer = Timer.new()
	cleanup.one_shot = true
	cleanup.wait_time = 0.75 if completed else 0.50
	cleanup.timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free()
	)
	particles.add_child(cleanup)
	cleanup.start()


func _on_research_started(settlement_id: int, tech_id: String, _started_tick: int) -> void:
	# Keep start/progress handlers connected for future ambient pulses, but do not
	# emit particles here (completion-only burst by spec).
	_refresh_spatial_profile_overlay()


func _on_research_progressed(settlement_id: int, tech_id: String, _spent_points: int, _cost: int, progress: float) -> void:
	# Completion-only visual burst; no per-progress particle spam.
	_refresh_spatial_profile_overlay()


func _on_research_completed(settlement_id: int, tech_id: String, _cost: int) -> void:
	_spawn_research_particles(settlement_id, tech_id, true, 1.0)
	_refresh_spatial_profile_overlay()


func _update_phase8_proof_bundle_preferred_center() -> void:
	var preferred_center: int = -1
	if _selected_pawn != null and is_instance_valid(_selected_pawn) and _selected_pawn.data != null:
		var srk: int = _WM._region_key(_selected_pawn.data.tile_pos.x, _selected_pawn.data.tile_pos.y)
		preferred_center = SettlementMemory.get_center_region_for_region(srk)
	if preferred_center < 0:
		var focus: Dictionary = _observer_focus_settlement()
		var sdata: Dictionary = focus.get("settlement_data", {})
		preferred_center = int(sdata.get("center_region", -1))
	SettlementMemory.set_phase8_proof_preferred_center_region(preferred_center)


func _debug_capture_resource_truth() -> void:
	if not OS.is_debug_build():
		return
	var preferred_center: int = -1
	# Prefer settlement already in focus via current selection.
	if _selected_pawn != null and is_instance_valid(_selected_pawn) and _selected_pawn.data != null:
		var srk: int = _WM._region_key(_selected_pawn.data.tile_pos.x, _selected_pawn.data.tile_pos.y)
		preferred_center = SettlementMemory.get_center_region_for_region(srk)
	# Otherwise prefer observer/player focus if available.
	if preferred_center < 0:
		var focus: Dictionary = _observer_focus_settlement()
		var sdata: Dictionary = focus.get("settlement_data", {})
		preferred_center = int(sdata.get("center_region", -1))
	SettlementMemory.print_resource_truth_capture(preferred_center, "Main.F12")


## Left-click press handler. Branches on the active designation mode:
##   - any build/zone mode: start click-drag rectangle.
##   - no mode: try to select the pawn under the cursor.
func _on_left_press() -> void:
	if _hud != null:
		_hud.hide_tile_history()
	_update_hover_tile(get_viewport().get_mouse_position())
	if _designation_mode != DesignationMode.NONE:
		if _hover_tile.x < 0:
			return
		_is_dragging = true
		_drag_start = _hover_tile
		_drag_current = _hover_tile
		_queue_designation_redraw()
		get_viewport().set_input_as_handled()
	elif _command_mode != null and _command_mode._zone_type != 0:  # NONE
		if _hover_tile.x < 0:
			return
		_is_dragging = true
		_drag_start = _hover_tile
		_drag_current = _hover_tile
		_queue_designation_redraw()
		get_viewport().set_input_as_handled()
	else:
		_handle_select_click_at(get_global_mouse_position())
		get_viewport().set_input_as_handled()


## Left-click release handler. If a drag was in progress, commit it.
## A same-tile press+release commits a single-tile rect, so the old click-
## to-place behavior is preserved.
func _on_left_release() -> void:
	if _is_dragging:
		_commit_drag()
		get_viewport().set_input_as_handled()


## Right-click press: cancel whatever's active. Priority mirrors Esc so the
## two keys feel consistent: drag > build mode > draft move (if pawn selected)
## > deselect (only if there was a selection / stale ref).
func _on_right_press() -> void:
	if _is_dragging:
		_cancel_drag()
		get_viewport().set_input_as_handled()
		return
	if _designation_mode != DesignationMode.NONE:
		_set_designation_mode(DesignationMode.NONE)
		get_viewport().set_input_as_handled()
		return
	# Command mode: if a pawn is selected, right-click issues a command
	if _selected_pawn != null and is_instance_valid(_selected_pawn):
		if _command_mode != null:
			_command_mode.set_selected_pawn(_selected_pawn)
			var world_pos: Vector2 = get_global_mouse_position()
			if _command_mode.handle_right_click(world_pos):
				get_viewport().set_input_as_handled()
				return
	var t: Vector2i = _world.world_to_tile(get_global_mouse_position())
	if t.x >= 0 and t.y >= 0:
		inspect_tile(t)
		get_viewport().set_input_as_handled()
		return
	if _selected_pawn != null:
		_set_selected_pawn(null)
		get_viewport().set_input_as_handled()
	# Off-map: leave unhandled (camera / future UI may use it).


func inspect_tile(tile_pos: Vector2i) -> void:
	if _hud == null:
		return
	var events: Array[Dictionary] = WorldMemory.get_events_for_tile(tile_pos)
	_hud.show_tile_history(tile_pos, events)


# ---------- drag-to-stamp: commit / cancel ----------

func _cancel_drag() -> void:
	_is_dragging = false
	_drag_start = Vector2i(-1, -1)
	_drag_current = Vector2i(-1, -1)
	_queue_designation_redraw()


## Finalize the current drag based on the active designation mode. Build
## modes stamp one job per tile in the rect; zone mode creates one Stockpile
## covering the whole rect.
func _commit_drag() -> void:
	var start: Vector2i = _drag_start
	var end: Vector2i = _drag_current
	_is_dragging = false
	_drag_start = Vector2i(-1, -1)
	_drag_current = Vector2i(-1, -1)
	if start.x < 0 or end.x < 0:
		_queue_designation_redraw()
		return
	var rect: Rect2i = _normalize_rect(start, end)
	# CommandMode zone painting takes priority
	if _command_mode != null and _command_mode._zone_type != 0:  # NONE
		if _command_mode._zone_type == 4:  # STORAGE_ZONE
			_commit_zone_rect(rect)
		else:
			_command_mode._paint_start = start
			_command_mode._paint_current = end
			_command_mode.commit_zone_paint()
		_command_mode.set_zone_type(0)  # NONE
		_queue_designation_redraw()
		return
	match _designation_mode:
		DesignationMode.DESIGNATE_ZONE:
			_commit_zone_rect(rect)
		DesignationMode.BUILD_BED, DesignationMode.BUILD_WALL, DesignationMode.BUILD_DOOR:
			_commit_build_rect(rect)
	_queue_designation_redraw()


## Create a Stockpile zone from the drag rect. Skips silently if the rect
## is out-of-bounds, too big, or has no reachable tiles.
func _commit_zone_rect(rect: Rect2i) -> void:
	if rect.size.x * rect.size.y > ZONE_MAX_AREA:
		if OS.is_debug_build():
			print("[Main] Zone too big (%dx%d, max area %d) -- dropped" %
					[rect.size.x, rect.size.y, ZONE_MAX_AREA])
		return
	if _count_passable_in_rect(rect) == 0:
		if OS.is_debug_build():
			print("[Main] Zone has no passable tiles @%s -- dropped" % str(rect))
		return
	var sp: Stockpile = STOCKPILE_SCENE.instantiate()
	sp.set_filter(_zone_next_filter)
	sp.set_rect_tiles(rect)
	sp.position = _world.tile_to_world(rect.position)
	add_child(sp)
	StockpileManager.register(sp)
	if OS.is_debug_build():
		print(
				"[Main] Zone %s designated at %s (%dx%d)" % [
					Stockpile.FILTER_NAME.get(_zone_next_filter, "?"),
					rect.position, rect.size.x, rect.size.y
				]
		)


## Post one build job per tile in the rect, filtered by the active build
## mode's validity predicate. Invalid tiles (mountain, water, existing
## feature, off-component) are silently skipped -- player can drag a wide
## rect without worrying about overlaps.
func _commit_build_rect(rect: Rect2i) -> void:
	var tile_count: int = rect.size.x * rect.size.y
	if tile_count > BUILD_DRAG_MAX_TILES:
		if OS.is_debug_build():
			print(
					"[Main] Build drag too big (%d tiles, max %d) -- dropped" %
					[tile_count, BUILD_DRAG_MAX_TILES]
			)
		return
	var posted: int = 0
	var skipped: int = 0
	for dy in range(rect.size.y):
		for dx in range(rect.size.x):
			var t := Vector2i(rect.position.x + dx, rect.position.y + dy)
			if _try_apply_designation_at(t):
				posted += 1
			else:
				skipped += 1
	if posted > 0:
		if OS.is_debug_build():
			print(
					"[Main] Drag-stamped %s: %d placed%s" % [
						_designation_action_label(_designation_mode),
						posted,
						"" if skipped == 0 else ", %d skipped" % skipped
					]
			)
	elif skipped > 0:
		if OS.is_debug_build():
			print("[Main] Drag-stamp: no valid tiles (%d skipped)" % skipped)


## Return a Rect2i with non-negative size from two corner tiles (either order).
static func _normalize_rect(a: Vector2i, b: Vector2i) -> Rect2i:
	var min_x: int = min(a.x, b.x)
	var min_y: int = min(a.y, b.y)
	var max_x: int = max(a.x, b.x)
	var max_y: int = max(a.y, b.y)
	return Rect2i(Vector2i(min_x, min_y), Vector2i(max_x - min_x + 1, max_y - min_y + 1))


func _count_passable_in_rect(rect: Rect2i) -> int:
	var count: int = 0
	for dy in range(rect.size.y):
		for dx in range(rect.size.x):
			var t := Vector2i(rect.position.x + dx, rect.position.y + dy)
			if not _world.data.in_bounds(t.x, t.y):
				continue
			if Biome.is_passable(_world.data.get_biome(t.x, t.y)) \
					and _world.data.get_feature(t.x, t.y) != TileFeature.Type.WALL:
				count += 1
	return count


## Cycle through the Stockpile.Filter enum in declaration order. Wraps.
func _cycle_zone_filter() -> void:
	# .values() is the portable way -- .size() on an enum literal works on
	# current Godot 4 but is less guaranteed across minor versions.
	var n: int = Stockpile.Filter.values().size()
	_zone_next_filter = (_zone_next_filter + 1) % n
	_push_zone_filter_label_to_toolbar()
	if OS.is_debug_build():
		print(
				"[Main] Next-zone filter: %s" %
				Stockpile.FILTER_NAME.get(_zone_next_filter, "?")
		)


func _push_zone_filter_label_to_toolbar() -> void:
	if _toolbar != null:
		_toolbar.set_zone_filter_label(Stockpile.FILTER_NAME.get(_zone_next_filter, "?"))


## Unregister and free every stockpile zone currently in the scene. Called
## on reroll so a fresh world starts with only the seeded zone.
func _tear_down_all_zones() -> void:
	var snapshot: Array[Stockpile] = StockpileManager.zones().duplicate()
	StockpileManager.clear_all()
	for z in snapshot:
		if is_instance_valid(z):
			z.queue_free()
	_world.stockpile = null


func _toggle_designation_mode(mode: int) -> void:
	if not _can_player_place():
		return
	if _designation_mode == mode:
		_set_designation_mode(DesignationMode.NONE)
	else:
		_set_designation_mode(mode)


func _set_designation_mode(mode: int) -> void:
	if not _can_player_place():
		mode = DesignationMode.NONE
	if _designation_mode == mode:
		return
	# Switching modes mid-drag is ambiguous (is the drag for the old mode or
	# the new one?) so we just drop the in-progress rect. Player can re-drag.
	if _is_dragging:
		_cancel_drag()
	_designation_mode = mode
	if _hud != null:
		_hud.set_designation_mode(_designation_mode_label(mode))
	if _toolbar != null:
		_toolbar.set_active_mode(mode)
	if OS.is_debug_build():
		if mode == DesignationMode.NONE:
			print("[Main] Designation mode: off")
		else:
			print(
					"[Main] Designation mode: %s  (left-click to place, right-click / Esc to cancel)" %
					_designation_action_label(mode)
			)
	_update_wall_path_preview()
	_queue_designation_redraw()


static func _designation_mode_label(mode: int) -> String:
	match mode:
		DesignationMode.BUILD_BED:         return "Bed"
		DesignationMode.BUILD_WALL:        return "Wall"
		DesignationMode.BUILD_DOOR:        return "Door"
		DesignationMode.BUILD_SHELTER:     return "Shelter"
		DesignationMode.BUILD_STORAGE_HUT: return "Storage Hut"
		DesignationMode.BUILD_FIRE_PIT:    return "Fire Pit"
		DesignationMode.BUILD_WORKSHOP:    return "Workshop"
		DesignationMode.DESIGNATE_ZONE:    return "Zone"
	return ""


func _designation_action_label(mode: int) -> String:
	var base_label: String = _designation_mode_label(mode)
	if mode == DesignationMode.BUILD_WALL:
		var suffix: String = _designation_style_suffix_for_current_focus()
		var family_label: String = _designation_material_family_for_current_focus()
		return "Constructing %s Wall%s" % [family_label, suffix]
	if mode == DesignationMode.BUILD_DOOR:
		return "Constructing %s Door%s" % [_designation_material_family_for_current_focus(), _designation_style_suffix_for_current_focus()]
	if mode == DesignationMode.BUILD_BED:
		return "Constructing Bed%s" % _designation_style_suffix_for_current_focus()
	if mode in [DesignationMode.BUILD_SHELTER, DesignationMode.BUILD_STORAGE_HUT, DesignationMode.BUILD_FIRE_PIT, DesignationMode.BUILD_WORKSHOP]:
		return "Constructing %s" % base_label
	return base_label


func _designation_style_suffix_for_current_focus() -> String:
	if CulturalStyleManager == null:
		return ""
	var center_region: int = _designation_center_region_for_style()
	if center_region < 0:
		return ""
	var style_label: String = str(CulturalStyleManager.call("describe_settlement_style", center_region))
	if style_label.strip_edges().is_empty():
		return ""
	return " [%s Style]" % style_label


func _designation_material_family_for_current_focus() -> String:
	if CulturalStyleManager == null:
		return "Wood"
	var center_region: int = _designation_center_region_for_style()
	if center_region < 0:
		return "Wood"
	var family: String = str(CulturalStyleManager.call("get_build_material_family", center_region)).to_lower()
	match family:
		"stone":
			return "Stone"
		_:
			return "Wood"


func _designation_center_region_for_style() -> int:
	if _selected_pawn != null and is_instance_valid(_selected_pawn) and _selected_pawn.data != null:
		var prk: int = _WM._region_key(_selected_pawn.data.tile_pos.x, _selected_pawn.data.tile_pos.y)
		return SettlementMemory.get_center_region_for_region(prk)
	var focus: Dictionary = _observer_focus_settlement()
	var sdata: Dictionary = focus.get("settlement_data", {})
	return int(sdata.get("center_region", -1))


func _handle_select_click_at(world_pos: Vector2) -> void:
	# Pick the visually-closest pawn within SELECT_PICK_RADIUS_PX. We use
	# the pawn's actual global_position (not data.tile_pos) so a pawn that
	# is currently between tiles is still selectable.
	if _pawn_spawner == null:
		_set_selected_pawn(null)
		return
	var best: HeelKawnian = null
	var best_d_sq: float = SELECT_PICK_RADIUS_PX * SELECT_PICK_RADIUS_PX
	for p in _pawn_spawner.pawns:
		if p == null or not is_instance_valid(p):
			continue
		var d_sq: float = p.global_position.distance_squared_to(world_pos)
		if d_sq <= best_d_sq:
			best = p
			best_d_sq = d_sq
	
	if _draft_mode_active and best != null:
		_handle_draft_click(best)
	else:
		_set_selected_pawn(best)


func select_pawn_from_pickable(pawn: HeelKawnian) -> void:
	if pawn == null or not is_instance_valid(pawn):
		return
	if _draft_mode_active:
		_handle_draft_click(pawn)
	else:
		_set_selected_pawn(pawn)
		_record_pawn_click_selection(pawn, "area_input_event", get_global_mouse_position(), get_global_mouse_position(), 1)


func _record_pawn_click_selection(pawn: Node, method: String, screen_pos: Vector2, world_pos: Vector2, candidates_count: int = 1) -> void:
	last_click_screen_position = screen_pos
	last_click_world_position = world_pos
	last_click_method = method
	last_click_candidates_count = candidates_count

	if pawn == null:
		last_selected_pawn_id = -1
		last_selected_pawn_path = "none"
		last_selection_success = false
		selection_manual_click_proven = false
		last_selection_failure_reason = "pawn_null"
		return

	var pawn_id: int = -1
	if pawn.has_method("get_pawn_id"):
		pawn_id = int(pawn.call("get_pawn_id"))
	elif "pawn_id" in pawn:
		pawn_id = int(pawn.get("pawn_id"))
	elif "id" in pawn:
		pawn_id = int(pawn.get("id"))

	last_selected_pawn_id = pawn_id
	last_selected_pawn_path = str(pawn.get_path())
	last_selection_success = true
	selection_manual_click_proven = true
	last_selection_failure_reason = ""

	if has_method("select_pawn"):
		call("select_pawn", pawn)
	elif has_method("_select_pawn"):
		call("_select_pawn", pawn)
	elif has_method("set_selected_pawn"):
		call("set_selected_pawn", pawn)
	elif "selected_pawn" in self:
		set("selected_pawn", pawn)


func _set_selected_pawn(p: HeelKawnian) -> void:
	if _player_mode == PlayerMode.INCARNATED and p != null and _player_pawn != null and p != _player_pawn:
		if OS.is_debug_build():
			print("[Main] Incarnation locked to pawn #%d; ignore selection of #%d" % [get_player_pawn_id(), int(p.data.id) if p.data != null else -1])
		return
	if _selected_pawn == p:
		return
	if _selected_pawn != null and is_instance_valid(_selected_pawn):
		_selected_pawn.is_selected = false
		_selected_pawn.queue_redraw()
	_selected_pawn = p
	if _pawn_ai_inspector != null:
		_pawn_ai_inspector.set_selected_pawn(_selected_pawn)
	# Observer-first: selection is inspection only. Incarnation/control remains explicit via picker.
	if _selected_pawn != null:
		_player_pawn = _selected_pawn
		_camera_follow_selected = true
		if _command_mode != null:
			_command_mode.set_selected_pawn(_selected_pawn)
		if _pawn_name_labels != null:
			_pawn_name_labels.set_selected_pawn(_selected_pawn)
	elif _player_mode != PlayerMode.INCARNATED:
		if _player_pawn == null or not is_instance_valid(_player_pawn) or _player_pawn.data == null:
			_player_pawn = _first_live_pawn()
		_camera_follow_selected = false
	_sync_player_context_ui()
	if _hud != null:
		_hud.set_player_control_refs(_player_input, _player_pawn)
	if _selected_pawn != null:
		_selected_pawn.is_selected = true
		_selected_pawn.queue_redraw()
		if OS.is_debug_build():
			print("[Main] Selected %s" % _selected_pawn.data.describe())
	else:
		if OS.is_debug_build():
			print("[Main] Selection cleared")
	if _info_panel != null:
		_info_panel.bind_pawn(_selected_pawn)
	# Playtest recording: log pawn selection
	if _selected_pawn != null and _selected_pawn.data != null:
		var _pr: Node = get_node_or_null("/root/PlaytestRecorder")
		if _pr != null and _pr.has_method("record_pawn_selection"):
			_pr.record_pawn_selection(int(_selected_pawn.data.id), _selected_pawn.data.display_name, _selected_pawn.data.tile_pos)


func _sync_play_chrome() -> void:
	if _hud != null:
		_hud.visible = _play_chrome_visible
	if _toolbar != null:
		_toolbar.visible = _play_chrome_visible
	if _observer_hud != null and not _play_chrome_visible:
		_observer_hud.visible = false
	if _focus_inspector != null and not _play_chrome_visible:
		_focus_inspector.visible = false
	if _info_panel != null:
		_info_panel.set_overlay_suppressed(not _play_chrome_visible)


func _toggle_play_chrome() -> void:
	_play_chrome_visible = not _play_chrome_visible
	_sync_play_chrome()
	if OS.is_debug_build():
		print("[Main] Play chrome: %s" % ("on" if _play_chrome_visible else "off (map only)"))


func _ensure_player_pawn_assigned(force: bool = false) -> void:
	if _pawn_spawner == null:
		return
	if not force and _player_mode != PlayerMode.INCARNATED:
		return
	if _player_pawn != null and is_instance_valid(_player_pawn) and _player_pawn.data != null:
		return
	for p in _pawn_spawner.pawns:
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		_set_selected_pawn(p)
		return


func _find_pawn_by_id(pawn_id: int) -> HeelKawnian:
	if _pawn_spawner == null or pawn_id < 0:
		return null
	for p in _pawn_spawner.pawns:
		if p != null and is_instance_valid(p) and p.data != null and int(p.data.id) == pawn_id:
			return p
	return null


func _first_live_pawn() -> HeelKawnian:
	if _pawn_spawner == null:
		return null
	for p in _pawn_spawner.pawns:
		if p != null and is_instance_valid(p) and p.data != null:
			return p
	return null


func _restore_player_state(player_mode_value: int, player_pawn_id: int) -> void:
	if player_mode_value == PlayerMode.SPECTATOR:
		_set_selected_pawn(null)
		_set_player_mode(PlayerMode.SPECTATOR)
		return
	var restored: HeelKawnian = _find_pawn_by_id(player_pawn_id)
	if restored != null:
		_set_selected_pawn(restored)
		_camera_follow_selected = true
		_set_player_mode(PlayerMode.INCARNATED)
		return
	_ensure_player_pawn_assigned(true)
	if _player_pawn != null and is_instance_valid(_player_pawn) and _player_pawn.data != null:
		_camera_follow_selected = true
		_set_player_mode(PlayerMode.INCARNATED)
	else:
		_set_selected_pawn(null)
		_set_player_mode(PlayerMode.SPECTATOR)


func get_player_queue_size() -> int:
	if _player_input == null:
		return 0
	return _player_input.get_queue_size()


func get_player_action_state() -> String:
	return _player_action_state


func get_chronicler_pin_zone_id() -> String:
	return _player_intent_pin_zone_id


func get_player_pawn() -> HeelKawnian:
	if _player_pawn != null and is_instance_valid(_player_pawn):
		return _player_pawn
	return null


## HUD selection (clicked pawn). Not necessarily the incarnation body.
func get_selected_pawn() -> HeelKawnian:
	if _selected_pawn != null and is_instance_valid(_selected_pawn):
		return _selected_pawn
	return null


func get_visual_selection_truth() -> Dictionary:
	var living: Array[HeelKawnian] = []
	if _pawn_spawner != null:
		if _pawn_spawner.has_method("get_alive_pawns"):
			living = _pawn_spawner.get_alive_pawns()
		else:
			for p in _pawn_spawner.pawns:
				if p != null and is_instance_valid(p) and p.data != null and not bool(p.data.is_dead):
					living.append(p)
	var with_sprite: int = 0
	var with_texture: int = 0
	var visible_count: int = 0
	var clickable_count: int = 0
	var fail_ids: Array[int] = []
	var sample_paths: Array[String] = []
	for p in living:
		if p == null or not is_instance_valid(p):
			continue
		var snap: Dictionary = p.visual_truth_snapshot() if p.has_method("visual_truth_snapshot") else {}
		var pawn_id: int = int(snap.get("pawn_id", int(p.data.id) if p.data != null else -1))
		var ok_sprite: bool = bool(snap.get("sprite_node_exists", false))
		var ok_texture: bool = bool(snap.get("texture_non_null", false))
		var ok_visible: bool = bool(snap.get("visible", false)) and float(snap.get("effective_alpha", 0.0)) > 0.0
		var ok_position: bool = bool(snap.get("world_position_valid", false))
		var ok_clickable: bool = bool(snap.get("clickable", false))
		var canvas_ok: bool = int(snap.get("canvas_layer", -999)) == 0
		var z_ok: bool = int(snap.get("z_index", -999)) >= 0
		if ok_sprite:
			with_sprite += 1
			if sample_paths.size() < 4:
				sample_paths.append(str(snap.get("sprite_path", "")))
		if ok_texture:
			with_texture += 1
		if ok_visible and ok_position and z_ok:
			visible_count += 1
		if ok_clickable:
			clickable_count += 1
		if not (ok_sprite and ok_texture and ok_visible and ok_position and ok_clickable and canvas_ok and z_ok):
			fail_ids.append(pawn_id)
	var selected_id: int = -1
	if _selected_pawn != null and is_instance_valid(_selected_pawn) and _selected_pawn.data != null:
		selected_id = int(_selected_pawn.data.id)
	return {
		"report": "VISUAL_SELECTION_TRUTH",
		"living_pawns": living.size(),
		"pawns_with_sprite_node": with_sprite,
		"pawns_with_texture": with_texture,
		"pawns_visible": visible_count,
		"pawns_clickable": clickable_count,
		"selected_pawn_id": selected_id,
		"topmost_control_blocking_mouse": _topmost_control_blocking_mouse_label(),
		"FAIL": fail_ids,
		"sample_sprite_paths": sample_paths,
		"pick_radius_px": SELECT_PICK_RADIUS_PX,
	}


func _topmost_control_blocking_mouse_label() -> String:
	var vp: Viewport = get_viewport()
	if vp == null:
		return "no_viewport"
	var c: Control = vp.gui_get_hovered_control()
	while c != null:
		if c.visible and c.is_visible_in_tree() and c.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			var filter_name: String = "STOP" if c.mouse_filter == Control.MOUSE_FILTER_STOP else "PASS"
			return "%s mouse_filter=%s" % [str(c.get_path()), filter_name]
		c = c.get_parent_control()
	return "none"


func get_colony_truth() -> Dictionary:
	var formal: int = SettlementMemory.get_formal_settlement_count() if SettlementMemory != null else 0
	var proto: int = SettlementMemory.get_proto_sites().size() if SettlementMemory != null else 0
	var zones: int = StockpileManager.zone_count() if StockpileManager != null and StockpileManager.has_method("zone_count") else 0
	var total_food_stockpile: int = StockpileManager.total_food() if StockpileManager != null and StockpileManager.has_method("total_food") else 0
	var food_hands: int = _food_in_pawn_hands()
	var beds: int = _world.bed_count() if _world != null and _world.has_method("bed_count") else 0
	var fire_pits: int = _feature_count(TileFeature.Type.FIRE_PIT)
	var housing_pressure: float = ColonySimServices.get_housing_pressure() if ColonySimServices != null else 0.0
	var food_pressure: float = ColonySimServices.get_food_pressure() if ColonySimServices != null else 0.0
	var warnings: Array[String] = []
	var living: int = PawnSpawner.find_alive_pawns().size()
	if living > 0 and beds <= 0 and housing_pressure < 0.75:
		warnings.append("housing_pressure_low_with_no_beds")
	if living > 0 and beds >= living and housing_pressure > 0.05:
		warnings.append("housing_pressure_high_despite_enough_beds")
	var all_food: int = total_food_stockpile + food_hands
	if living > 0 and all_food <= 0 and food_pressure < 0.90:
		warnings.append("food_pressure_low_with_no_food_material")
	if all_food >= living * 2 and food_pressure > 0.75:
		warnings.append("food_pressure_high_despite_food_material")
	var civ_warn: String = _civilization_material_warning(formal, zones, beds, fire_pits)
	if not civ_warn.is_empty():
		warnings.append(civ_warn)
	return {
		"report": "COLONY_TRUTH",
		"formal_settlements": formal,
		"proto_sites": proto,
		"stockpile_zones": zones,
		"beds": beds,
		"fire_pits": fire_pits,
		"total_food_stockpile": total_food_stockpile,
		"food_in_pawn_hands": food_hands,
		"housing_pressure": housing_pressure,
		"food_pressure": food_pressure,
		"warnings": warnings,
	}


func _food_in_pawn_hands() -> int:
	var total: int = 0
	if _pawn_spawner == null:
		return total
	for p in _pawn_spawner.get_alive_pawns():
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		if p.data.is_carrying() and Item.is_food(int(p.data.carrying)):
			total += int(p.data.carrying_qty)
	return total


func _feature_count(feature_type: int) -> int:
	if _world == null or not _world.has_method("get_feature_counts"):
		return 0
	var counts: Dictionary = _world.get_feature_counts()
	return int(counts.get(feature_type, 0))


func _civilization_material_warning(formal: int, zones: int, beds: int, fire_pits: int) -> String:
	if CivilizationStage == null:
		return ""
	var snap: Dictionary = CivilizationStage.get_world_stage_snapshot()
	var stage: int = int(snap.get("stage", 0))
	if stage >= CivilizationStage.STAGE_IRON_AGE and formal <= 0 and zones <= 0 and beds <= 0 and fire_pits <= 0:
		return "civilization_stage_material_mismatch: stage=%s score=%d but settlements=0 stockpile_zones=0 beds=0 fire_pits=0" % [
			str(snap.get("stage_name", "Unknown")),
			int(snap.get("score", 0)),
		]
	return ""




func get_player_profession_name() -> String:
	if _player_pawn == null or not is_instance_valid(_player_pawn) or _player_pawn.data == null:
		return "None"
	return _player_pawn.data.profession_name()


func get_player_profession_xp() -> int:
	if _player_pawn == null or not is_instance_valid(_player_pawn) or _player_pawn.data == null:
		return 0
	return int(_player_pawn.data.profession_progress_xp())


func get_player_governance_profile() -> Dictionary:
	if _player_pawn == null or not is_instance_valid(_player_pawn) or _player_pawn.data == null:
		return {"type": "anarchy", "ruler_name": "None", "player_status": "None", "edicts_unlocked": false}
	var rk: int = _WM._region_key(_player_pawn.data.tile_pos.x, _player_pawn.data.tile_pos.y)
	var gov: Dictionary = SettlementMemory.get_governance_profile_for_region(rk)
	var gtype: String = str(gov.get("type", "anarchy"))
	var rid: int = int(gov.get("ruler_id", -1))
	var ruler_name: String = "None"
	if rid >= 0:
		for p in get_visible_pawns():
			if p != null and is_instance_valid(p) and p.data != null and int(p.data.id) == rid:
				ruler_name = p.data.display_name
				break
		if ruler_name == "None" and is_player_incarnated():
			ruler_name = "Unknown"
	var status: String = "Rebel"
	var pid: int = int(_player_pawn.data.id)
	if rid < 0:
		status = "Rebel"
	elif rid == pid:
		status = "Ruler"
	else:
		status = "Loyalist"
	return {
		"type": gtype,
		"ruler_name": ruler_name,
		"player_status": status,
		"edicts_unlocked": status == "Ruler",
	}


func get_player_war_profile() -> Dictionary:
	if _player_pawn == null or not is_instance_valid(_player_pawn) or _player_pawn.data == null:
		return {"state": "peace", "target_settlement_id": -1, "votes": []}
	var rk: int = _WM._region_key(_player_pawn.data.tile_pos.x, _player_pawn.data.tile_pos.y)
	return SettlementMemory.get_war_profile_for_region(rk)


func get_player_military_rank() -> String:
	if _player_pawn == null or not is_instance_valid(_player_pawn) or _player_pawn.data == null:
		return "grunt"
	return str(_player_pawn.data.military_rank_legacy)


func get_wildlife_snapshot_for_diagnostic() -> Dictionary:
	if _animal_spawner == null:
		return {"rabbit": 0, "deer": 0, "total": 0}
	return _animal_spawner.get_live_wildlife_snapshot()


## Display-only: camera tile region → settlement revival + rebirth gate (no writes).
## If the camera is not over any cluster tile, falls back to the nearest settlement by center-tile distance.
func get_camera_settlement_revival_digest() -> Dictionary:
	var out_empty: Dictionary = {
		"has_settlement": false,
		"region_key": -1,
		"camera_region_key": -1,
		"profile_region_key": -1,
		"digest_source": "none",
		"state": "",
		"revival_score": 0,
		"peace_threshold_ticks": 0,
		"peace_since_conflict_ticks": 0,
		"revival_ready": false,
		"rebirth_ok": false,
		"rebirth_reason": "",
	}
	if not is_instance_valid(_world) or _camera == null or _world.data == null:
		return out_empty
	var cam_tile: Vector2i = _world.world_to_tile(_camera.global_position)
	if is_player_incarnated() and _player_pawn != null and is_instance_valid(_player_pawn) and _player_pawn.data != null:
		cam_tile = _player_pawn.data.tile_pos
	if cam_tile.x < 0:
		out_empty["region_key"] = -2
		out_empty["camera_region_key"] = -2
		return out_empty
	var cam_rk: int = _WM._region_key(cam_tile.x, cam_tile.y)
	out_empty["region_key"] = cam_rk
	out_empty["camera_region_key"] = cam_rk
	var d_cam: Dictionary = _revival_digest_for_cluster_region(_world, cam_rk)
	if bool(d_cam.get("has_settlement", false)):
		d_cam["digest_source"] = "cam"
		d_cam["camera_region_key"] = cam_rk
		d_cam["profile_region_key"] = cam_rk
		return d_cam
	var near_ckr: int = _nearest_settlement_center_region_key(cam_tile)
	if near_ckr < 0:
		return out_empty
	var d_near: Dictionary = _revival_digest_for_cluster_region(_world, near_ckr)
	d_near["digest_source"] = "nearest" if bool(d_near.get("has_settlement", false)) else "none"
	d_near["camera_region_key"] = cam_rk
	d_near["profile_region_key"] = near_ckr
	d_near["region_key"] = cam_rk
	return d_near


func _nearest_settlement_center_region_key(cam_tile: Vector2i) -> int:
	var best_ckr: int = -1
	var best_d: int = 1_000_000_000
	for s in SettlementMemory.settlements:
		if not (s is Dictionary):
			continue
		var ckr: int = int((s as Dictionary).get("center_region", -1))
		if ckr < 0:
			continue
		var ct: Vector2i = _center_tile_from_region_key(ckr)
		var manh: int = absi(cam_tile.x - ct.x) + absi(cam_tile.y - ct.y)
		if manh < best_d:
			best_d = manh
			best_ckr = ckr
	return best_ckr


func _revival_digest_for_cluster_region(world: World, region_key: int) -> Dictionary:
	var out1: Dictionary = {
		"has_settlement": false,
		"region_key": region_key,
		"camera_region_key": region_key,
		"profile_region_key": region_key,
		"digest_source": "none",
		"state": "",
		"revival_score": 0,
		"peace_threshold_ticks": 0,
		"peace_since_conflict_ticks": 0,
		"revival_ready": false,
		"rebirth_ok": false,
		"rebirth_reason": "",
	}
	var prof: Dictionary = SettlementMemory.get_settlement_profile(region_key)
	var state_now: String = str(prof.get("state", ""))
	if state_now == "":
		return out1
	out1["has_settlement"] = true
	out1["state"] = state_now
	out1["revival_score"] = int(prof.get("revival_score", 0))
	out1["peace_threshold_ticks"] = int(prof.get("peace_threshold_ticks", 0))
	var now: int = GameManager.tick_count
	var last_d: int = int(prof.get("last_pawn_death_tick", -1))
	var peace_ticks: int = 1_000_000_000 if last_d < 0 else maxi(0, now - last_d)
	out1["peace_since_conflict_ticks"] = peace_ticks
	out1["revival_ready"] = bool(prof.get("revival_ready", false))
	var sv: Variant = SettlementMemory.get_settlement_at_region(region_key)
	if state_now == "revivable" and sv is Dictionary:
		var gate: Dictionary = SettlementManager.get_rebirth_eligibility(world, sv as Dictionary)
		out1["rebirth_ok"] = bool(gate.get("ok", false))
		out1["rebirth_reason"] = str(gate.get("reason", ""))
	elif sv is not Dictionary:
		out1["rebirth_reason"] = "no_settlement_dict"
	return out1


func get_camera_revival_digest_bbcode() -> String:
	return _format_camera_revival_digest_bbcode(get_camera_settlement_revival_digest())


func get_camera_revival_digest_plain() -> String:
	return _format_camera_revival_digest_plain(get_camera_settlement_revival_digest())


func _format_camera_revival_digest_plain(d: Dictionary) -> String:
	if not bool(d.get("has_settlement", false)):
		var rk: int = int(d.get("region_key", -1))
		if rk == -2:
			return "camera_revival: (no world)"
		return "camera_revival: vacant cam_rk=%d" % int(d.get("camera_region_key", rk))
	var src: String = str(d.get("digest_source", "cam"))
	var cam_rk_p: int = int(d.get("camera_region_key", int(d.get("region_key", -1))))
	var prof_rk: int = int(d.get("profile_region_key", cam_rk_p))
	var prefix: String = "camera_revival" if src == "cam" else "camera_revival nearest"
	var loc_note: String = "" if src == "cam" else " cam_rk=%d profile_rk=%d" % [cam_rk_p, prof_rk]
	var pt: int = int(d.get("peace_threshold_ticks", 0))
	var pc: int = int(d.get("peace_since_conflict_ticks", 0))
	var pc_show: String = "inf" if pc >= 999_000_000 else str(pc)
	var st_plain: String = str(d.get("state", ""))
	var rs_p: int = int(d.get("revival_score", 0))
	if st_plain == "revivable":
		var rb: String = str(d.get("rebirth_reason", ""))
		var rdy: String = "Y" if bool(d.get("revival_ready", false)) else "N"
		var ok: String = "Y" if bool(d.get("rebirth_ok", false)) else "N"
		return (
			"%s: %s rs=%d peace=%s/%s rdy=%s rebirth_ok=%s rb=%s%s"
			% [prefix, st_plain, rs_p, pc_show, str(pt), rdy, ok, rb, loc_note]
		)
	return "%s: %s rs=%d peace=%s/%s rebirth=n/a%s" % [prefix, st_plain, rs_p, pc_show, str(pt), loc_note]


func _format_camera_revival_digest_bbcode(d: Dictionary) -> String:
	if not bool(d.get("has_settlement", false)):
		var rk2: int = int(d.get("region_key", -1))
		var crk: int = int(d.get("camera_region_key", rk2))
		if rk2 == -2:
			return "[color=#9e9e9e]🏚 Cam settlement: (no world)[/color]"
		return "[color=#9e9e9e]🏚 Cam vacant rk=%d[/color]" % crk
	var src2: String = str(d.get("digest_source", "cam"))
	var cam_rk2: int = int(d.get("camera_region_key", int(d.get("region_key", -1))))
	var prof_rk2: int = int(d.get("profile_region_key", cam_rk2))
	var head: String = (
		"[color=#c9b37c]🏚 Cam:[/color]"
		if src2 == "cam"
		else (
			"[color=#c9b37c]🏚 Near[/color] [color=#888](cam rk=%d · profile rk=%d)[/color]"
			% [cam_rk2, prof_rk2]
		)
	)
	var pt2: int = int(d.get("peace_threshold_ticks", 0))
	var pc2: int = int(d.get("peace_since_conflict_ticks", 0))
	var pc_label: String = "inf" if pc2 >= 999_000_000 else str(pc2)
	var stc: String = str(d.get("state", ""))
	var rs: int = int(d.get("revival_score", 0))
	if stc == "revivable":
		var rdy_b: bool = bool(d.get("revival_ready", false))
		var ok_b: bool = bool(d.get("rebirth_ok", false))
		var rb2: String = str(d.get("rebirth_reason", ""))
		var rdy_s: String = "[color=#a5d6a7]Y[/color]" if rdy_b else "[color=#bdbdbd]N[/color]"
		var rb_ok_s: String = (
			"[color=#a5d6a7]%s[/color]" % rb2
			if ok_b
			else "[color=#ffcc80]%s[/color]" % rb2
		)
		return (
			"%s [b]%s[/b]  rs:%d  peace:%s/%s  revivable:%s  rebirth:%s"
			% [head, stc, rs, pc_label, str(pt2), rdy_s, rb_ok_s]
		)
	return (
		"%s [b]%s[/b]  rs:%d  peace:%s/%s  [color=#888888](rebirth n/a)[/color]"
		% [head, stc, rs, pc_label, str(pt2)]
	)


func _ensure_meaning_vignette() -> void:
	if _meaning_vignette_rect != null and is_instance_valid(_meaning_vignette_rect):
		return
	var cl: CanvasLayer = CanvasLayer.new()
	cl.name = "MeaningVignetteLayer"
	cl.layer = 4
	var cr: ColorRect = ColorRect.new()
	cr.name = "MeaningVignette"
	cr.set_anchors_preset(Control.PRESET_FULL_RECT)
	cr.offset_left = 0.0
	cr.offset_top = 0.0
	cr.offset_right = 0.0
	cr.offset_bottom = 0.0
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cr.color = Color(0, 0, 0, 0)
	cl.add_child(cr)
	add_child(cl)
	_meaning_vignette_rect = cr


func _update_meaning_vignette() -> void:
	if _meaning_vignette_rect == null or not is_instance_valid(_meaning_vignette_rect):
		return
	var mood: float = clampf(_meaning_ambient_mood, 0.0, 1.0)
	var a: float = lerpf(0.028, 0.0, mood) + absf(_meaning_style_bias) * 0.01
	_meaning_vignette_rect.color = Color(0, 0, 0, clampf(a, 0.0, 0.065))


func is_kernel_diagnostic_complete() -> bool:
	return _kernel_diagnostic != null and _kernel_diagnostic.is_complete()


func _update_hover_tile(_screen_pos: Vector2) -> void:
	if _world == null:
		return
	# Built-in handles camera transform + zoom for us.
	var t: Vector2i = _world.world_to_tile(get_global_mouse_position())
	if t == _hover_tile:
		return
	_hover_tile = t
	_update_wall_path_preview()
	if _designation_mode != DesignationMode.NONE:
		_queue_designation_redraw()


## While wall mode is active, mark preview cells as A* solid so pawns detour
## (mirrors the wall jobs that have not been posted over invalid/red tiles).
func _update_wall_path_preview() -> void:
	if _world == null or _designation_mode != DesignationMode.BUILD_WALL:
		if _world != null and _world.pathfinder != null and _world.data != null:
			_world.pathfinder.set_preview_wall_tiles([], _world.data)
		return
	var a: Vector2i = _drag_start if _is_dragging else _hover_tile
	var b: Vector2i = _drag_current if _is_dragging else _hover_tile
	if a.x < 0 or b.x < 0:
		_world.pathfinder.set_preview_wall_tiles([], _world.data)
		return
	var rect: Rect2i = _normalize_rect(a, b)
	var main_component: int = _world.pathfinder.largest_component_id()
	var plan: Array = []
	for dy in range(rect.size.y):
		for dx in range(rect.size.x):
			var t2 := Vector2i(rect.position.x + dx, rect.position.y + dy)
			if _preview_tile_valid(t2, main_component):
				plan.append(t2)
	_world.pathfinder.set_preview_wall_tiles(plan, _world.data)


## Post a single build job at the given tile if it's a valid site for the
## current designation mode. Returns true if a job was posted, false if the
## tile was skipped. Used both by single-click stamps and by the per-tile
## loop inside drag commits; the quiet failure path is essential for drag
## stamps because a wide rect almost always includes some invalid tiles
## (mountain, water, existing features) and we don't want a log line per
## skipped tile.
func _try_apply_designation_at(tile: Vector2i) -> bool:
	if tile.x < 0:
		return false
	if not _world.data.in_bounds(tile.x, tile.y):
		return false
	var main_component: int = _world.pathfinder.largest_component_id()
	match _designation_mode:
		DesignationMode.BUILD_BED:
			if not _is_valid_bed_site(tile, main_component):
				return false
			JobManager.post(Job.Type.BUILD_BED, tile,
				BUILD_BED_PRIORITY, BUILD_BED_WORK_TICKS)
			return true
		DesignationMode.BUILD_WALL:
			var work_tile: Vector2i = _find_main_component_neighbor(tile, main_component)
			if work_tile.x < 0 or not _is_valid_build_site(tile, main_component):
				return false
			var job: Job = JobManager.post(Job.Type.BUILD_WALL, tile,
				BUILD_WALL_PRIORITY, BUILD_WALL_WORK_TICKS)
			if job == null:
				return false
			job.work_tile = work_tile
			# Treat future wall cells as blocked for A*; shove pawns who stand on them.
			_world.pathfinder.set_job_construction_reservation(
				tile.x, tile.y, true, _world.data
			)
			_world.kick_occupants_off_reserved_build_tile(tile.x, tile.y)
			_world.notify_pawns_nav_changed()
			return true
		DesignationMode.BUILD_DOOR:
			if not _is_valid_door_site(tile, main_component):
				return false
			var fdoor: int = _world.data.get_feature(tile.x, tile.y)
			var wtd: Vector2i
			if fdoor == TileFeature.Type.WALL:
				wtd = _find_main_component_neighbor(tile, main_component)
				if wtd.x < 0:
					return false
			else:
				wtd = tile
			var jdoor: Job = JobManager.post(Job.Type.BUILD_DOOR, tile,
				BUILD_DOOR_PRIORITY, BUILD_DOOR_WORK_TICKS)
			if jdoor == null:
				return false
			jdoor.work_tile = wtd
			return true
	return false


## True if a tile is inside any stockpile zone (including the 3x3 seed pile).
func _tile_covered_by_any_stockpile(t: Vector2i) -> bool:
	for z in StockpileManager.zones():
		if z.contains_tile(t):
			return true
	return false


## Same predicate used by every player-stampable build (walls, doors, ad-hoc
## beds outside the auto-placer). Tile must be on the main landmass, passable
## right now, empty of other features, and not already in the job queue.
func _is_valid_build_site(t: Vector2i, main_component: int) -> bool:
	if not _world.data.in_bounds(t.x, t.y):
		return false
	if _tile_covered_by_any_stockpile(t):
		return false
	if not _world.pathfinder.is_passable(t):
		return false
	if _world.pathfinder.component_of(t) != main_component:
		return false
	if _world.data.get_feature(t.x, t.y) != TileFeature.Type.NONE:
		return false
	if JobManager.has_job_at(t):
		return false
	return true


## Door on empty passable land, OR door-to-replace (existing WALL). Wall
## tiles read as impassable in the pathfinder, so we do NOT require
## is_passable(t) for WALL — instead we require a passable work neighbor on
## the main landmass (worker stands there), same as wall construction.
func _is_valid_door_site(t: Vector2i, main_component: int) -> bool:
	if not _world.data.in_bounds(t.x, t.y):
		return false
	if _tile_covered_by_any_stockpile(t):
		return false
	if JobManager.has_job_at(t):
		return false
	if not Biome.is_passable(_world.data.get_biome(t.x, t.y)):
		return false
	var f: int = _world.data.get_feature(t.x, t.y)
	if f == TileFeature.Type.WALL:
		return _find_main_component_neighbor(t, main_component).x >= 0
	if f != TileFeature.Type.NONE:
		return false
	if not _world.pathfinder.is_passable(t):
		return false
	if _world.pathfinder.component_of(t) != main_component:
		return false
	return true


func _queue_designation_redraw() -> void:
	if _preview_layer != null and is_instance_valid(_preview_layer):
		_preview_layer.queue_redraw()


## Called from BuildPreviewOverlay (above the world sprite) so previews show.
func draw_designation_previews_on(ci: CanvasItem) -> void:
	if _world == null or ci == null:
		return
	# Always draw registered zone overlays (even when not in designation mode)
	_draw_registered_zones(ci)
	if _designation_mode == DesignationMode.NONE:
		return
	# Resolve the rect we're previewing. During an active drag it's
	# drag_start..drag_current; otherwise it's a 1x1 cursor hint at the
	# currently hovered tile so the player can see where a drag would start.
	var a: Vector2i = _drag_start if _is_dragging else _hover_tile
	var b: Vector2i = _drag_current if _is_dragging else _hover_tile
	if a.x < 0 or b.x < 0:
		return
	var rect: Rect2i = _normalize_rect(a, b)
	if _designation_mode == DesignationMode.DESIGNATE_ZONE:
		_draw_zone_preview(rect, ci)
	else:
		_draw_build_preview(rect, ci)


## Draw registered zone overlays so the player can see designated areas.
func _draw_registered_zones(ci: CanvasItem) -> void:
	if ZoneRegistry == null:
		return
	var zone_colors: Dictionary = {
		ZoneRegistry.ZoneType.FORAGE: Color(0.3, 0.85, 0.3, 0.18),
		ZoneRegistry.ZoneType.BUILD: Color(0.85, 0.7, 0.2, 0.18),
		ZoneRegistry.ZoneType.DEFEND: Color(0.85, 0.3, 0.3, 0.18),
	}
	var border_colors: Dictionary = {
		ZoneRegistry.ZoneType.FORAGE: Color(0.3, 0.85, 0.3, 0.55),
		ZoneRegistry.ZoneType.BUILD: Color(0.85, 0.7, 0.2, 0.55),
		ZoneRegistry.ZoneType.DEFEND: Color(0.85, 0.3, 0.3, 0.55),
	}
	for zt: int in zone_colors:
		for r: Rect2i in ZoneRegistry.zones_of_type(zt):
			var area: Rect2 = _tiles_rect_to_world_rect(r)
			ci.draw_rect(area, zone_colors[zt], true)
			ci.draw_rect(area.grow(0.5), border_colors[zt], false, 1.0)


## Tinted solid rectangle for a pending Stockpile zone.
func _draw_zone_preview(rect: Rect2i, ci: CanvasItem) -> void:
	var area: Rect2 = _tiles_rect_to_world_rect(rect)
	var fill: Color = Stockpile.FILTER_FILL.get(_zone_next_filter, Color(0.9, 0.8, 0.3, 0.35))
	fill.a = 0.45
	ci.draw_rect(area, fill, true)
	ci.draw_rect(area.grow(0.5), Color(1, 1, 1, 0.90), false, 1.2)


## Per-tile blueprint preview for Bed / Wall / Door drags. We tint each tile
## individually (green if it's a valid site, red if not) so the player can
## see which squares in a wide rect will actually become jobs.
func _draw_build_preview(rect: Rect2i, ci: CanvasItem) -> void:
	var feature: int = _blueprint_feature_for_mode()
	var base_fill: Color = TileFeature.COLORS[feature]
	var main_component: int = _world.pathfinder.largest_component_id()
	var tile_size := Vector2(World.TILE_PIXELS, World.TILE_PIXELS)
	var half: Vector2 = tile_size * 0.5
	for dy in range(rect.size.y):
		for dx in range(rect.size.x):
			var t := Vector2i(rect.position.x + dx, rect.position.y + dy)
			var center: Vector2 = _world.tile_to_world(t)
			var tile_rect := Rect2(center - half, tile_size)
			var valid: bool = _preview_tile_valid(t, main_component)
			var fill: Color = base_fill if valid else Color(0.85, 0.25, 0.25)
			fill.a = 0.55 if valid else 0.35
			ci.draw_rect(tile_rect, fill, true)
	# Bright outline around the whole drag so the extents pop, plus a thin
	# outline only on the perimeter if we're dragging so the bounds are
	# readable even when every cell is tinted.
	var area: Rect2 = _tiles_rect_to_world_rect(rect)
	ci.draw_rect(area.grow(0.5), Color(1, 1, 1, 0.85), false, 1.0)


## True if a tile in a build-mode drag rect would accept a job. Mirrors the
## checks done during commit, lightweight enough to run every frame during
## a drag (we cap drag size at BUILD_DRAG_MAX_TILES).
func _preview_tile_valid(t: Vector2i, main_component: int) -> bool:
	if not _world.data.in_bounds(t.x, t.y):
		return false
	match _designation_mode:
		DesignationMode.BUILD_BED:
			return _is_valid_bed_site(t, main_component)
		DesignationMode.BUILD_WALL:
			if _find_main_component_neighbor(t, main_component).x < 0:
				return false
			return _is_valid_build_site(t, main_component)
		DesignationMode.BUILD_DOOR:
			return _is_valid_door_site(t, main_component)
		DesignationMode.BUILD_FIRE_PIT, DesignationMode.BUILD_STORAGE_HUT, \
		DesignationMode.BUILD_SHELTER, DesignationMode.BUILD_WORKSHOP:
			return _is_valid_build_site(t, main_component)
	return false


## Convert a tile-space Rect2i into a world-space Rect2 bounding box. We
## subtract half a tile because World.tile_to_world returns the TILE CENTER.
func _tiles_rect_to_world_rect(rect: Rect2i) -> Rect2:
	var tile_size := Vector2(World.TILE_PIXELS, World.TILE_PIXELS)
	var half: Vector2 = tile_size * 0.5
	var top_left_world: Vector2 = _world.tile_to_world(rect.position) - half
	return Rect2(top_left_world, Vector2(rect.size.x * World.TILE_PIXELS, rect.size.y * World.TILE_PIXELS))


func _blueprint_feature_for_mode() -> int:
	match _designation_mode:
		DesignationMode.BUILD_BED:         return TileFeature.Type.BED
		DesignationMode.BUILD_WALL:        return TileFeature.Type.WALL
		DesignationMode.BUILD_DOOR:        return TileFeature.Type.DOOR
		DesignationMode.BUILD_FIRE_PIT:    return TileFeature.Type.FIRE_PIT
		DesignationMode.BUILD_STORAGE_HUT: return TileFeature.Type.STORAGE_HUT
		DesignationMode.BUILD_SHELTER:     # No feature for complex buildings yet, use a ghost color?
			return TileFeature.Type.NONE
		DesignationMode.BUILD_WORKSHOP:
			return TileFeature.Type.NONE
	return TileFeature.Type.NONE


func _reroll_world() -> void:
	JobManager.clear_all()
	SettlementRegistry.clear()
	SettlementMemory.clear_persisted_governance_forms()
	FragmentationManager.clear()
	SchismManager.clear()
	WorldMemory.clear()
	MythMemory.clear()
	SacredMemory.clear()
	PlayerIntentQueue.clear()
	if FootpathMemory != null and FootpathMemory.has_method("clear"):
		FootpathMemory.clear()
	if BuildingUsageTracker != null and BuildingUsageTracker.has_method("clear"):
		BuildingUsageTracker.clear()
	if SnowAccumulation != null and SnowAccumulation.has_method("clear"):
		SnowAccumulation.clear()
	if TimeLapseRecorder != null and TimeLapseRecorder.has_method("clear"):
		TimeLapseRecorder.clear()
	_reset_player_intent_observer_routing()
	FactionRegistry.clear()
	ChronicleLog.clear()
	RoadMemory.clear()
	TradeMemory.clear()
	IntentMemory.clear()
	MemoryManager.get_age_memory().clear()
	WorldPersistence.clear()
	WorldMeaning.recompute()
	WorldPersistence.recompute()
	_set_designation_mode(DesignationMode.NONE)
	# The current selection is about to be invalidated when pawns are freed.
	# Drop it now so the panel hides cleanly instead of poking dead nodes.
	_set_selected_pawn(null)
	# Wipe every registered zone + free the Node2Ds. Pawns holding a
	# reference to a zone via _target_zone will fall back to nearest-
	# reachable via StockpileManager on the next tick.
	_tear_down_all_zones()
	_world.generate(WorldRNG.stream_seed(&"manual_world_reroll", GameManager.tick_count))
	if is_instance_valid(_world):
		_world.apply_ruins_from_persistence()
		CulturalMemory.recompute(_world)
		SettlementMemory.recompute(_world)
		MythMemory.recompute(_world)
		_run_heavy_refresh_once_per_tick(func() -> void:
			if is_instance_valid(_world):
				_world.refresh_pawn_historic_path_weights()
		)
	var main_component: int = _world.pathfinder.largest_component_id()
	# Place the stockpile BEFORE respawning pawns, so every pawn sees a valid
	# stockpile reference the first time it ticks.
	_place_stockpile(main_component)
	_ensure_validation_session_seed_stockpile_overlaps_settlement()
	_pawn_spawner.respawn(_world, main_component)
	_ensure_player_pawn_assigned()
	Main._world_stabilization_until_tick = GameManager.tick_count + WORLD_STABILIZATION_TICKS
	# DORMANT WORLD: FogOfDiscovery handles job posting
	_seed_jobs_for_discovered_area()
	_react_to_mining_progress()
	if _hud != null:
		_hud.bind(_world, _pawn_spawner)
	if _chronicle_ledger != null:
		_chronicle_ledger.bind(_pawn_spawner)
	if _chronicle_book != null:
		_chronicle_book.bind(_pawn_spawner)
	if FootpathMemory != null and FootpathMemory.has_method("bind_context"):
		FootpathMemory.bind_context(_world, _pawn_spawner)
	if BuildingUsageTracker != null and BuildingUsageTracker.has_method("bind_context"):
		BuildingUsageTracker.bind_context(_world, _pawn_spawner)
	if SnowAccumulation != null and SnowAccumulation.has_method("bind_world"):
		SnowAccumulation.bind_world(_world)
	if TimeLapseRecorder != null and TimeLapseRecorder.has_method("bind_context"):
		TimeLapseRecorder.bind_context(_world, _pawn_spawner, _camera)
		TimeLapseRecorder.record()
	_last_generation_tick = GameManager.tick_count
	_world.set_meta("animal_spawner", _animal_spawner)
	if is_instance_valid(_world):
		MemoryManager.recompute_intent(_world)
		SettlementPlanner.plan(_world, self, true)
		EconomyManager.get_trade_planner().plan(_world, self, true)
		MemoryManager.flush_dirty_tiles(_world)
		MemoryManager.get_remnant_memory().clear()
		MemoryManager.seed_births_from_current_world(_world)
	# Defer only visual refresh; causal job setup stays before the next tick.
	call_deferred("_reroll_heavy_phase2")


## Heavy reroll phase 2: visual-only terrain tint refresh.
func _reroll_heavy_phase2() -> void:
	if not is_instance_valid(_world):
		return
	_world.refresh_terrain_scar_tint()


## DORMANT WORLD: Seed jobs only for the pre-discovered stockpile area.
## Uses per-capita needs limits — not every resource gets a job.
func _seed_jobs_for_discovered_area() -> void:
	if FogOfDiscovery == null or _world == null or _world.data == null:
		return
	# Per-capita limits: enough jobs to sustain the population
	var pop: int = PawnSpawner.find_pawns().size()
	var max_forage: int = maxi(int(ceil(float(pop) * FogOfDiscovery.FOOD_JOBS_PER_PAWN * 0.7)), 3)
	var max_hunt: int = maxi(int(ceil(float(pop) * FogOfDiscovery.FOOD_JOBS_PER_PAWN * 0.3)), 1)
	var max_fish: int = maxi(int(ceil(float(pop) * FogOfDiscovery.FOOD_JOBS_PER_PAWN * 0.2)), 1)
	var max_chop: int = maxi(int(ceil(float(pop) * FogOfDiscovery.WOOD_JOBS_PER_PAWN)), 2)
	var max_mine: int = maxi(int(ceil(float(pop) * FogOfDiscovery.STONE_JOBS_PER_PAWN)), 1)
	var forage_posted: int = 0
	var hunt_posted: int = 0
	var fish_posted: int = 0
	var chop_posted: int = 0
	var mine_posted: int = 0
	for y in range(WorldData.HEIGHT):
		for x in range(WorldData.WIDTH):
			if not FogOfDiscovery.is_discovered(x, y):
				continue
			var feature: int = _world.data.get_feature(x, y)
			var tile: Vector2i = Vector2i(x, y)
			if feature == TileFeature.Type.FERTILE_SOIL:
				if forage_posted < max_forage and not JobManager.has_job_at(tile):
					if JobManager.post(Job.Type.FORAGE, tile) != null:
						forage_posted += 1
			elif feature == TileFeature.Type.ORE_VEIN:
				if mine_posted < max_mine and not JobManager.has_job_at(tile):
					if JobManager.post(Job.Type.MINE, tile) != null:
						mine_posted += 1
			elif feature == TileFeature.Type.TREE:
				if chop_posted < max_chop and not JobManager.has_job_at(tile):
					if JobManager.post(Job.Type.CHOP, tile) != null:
						chop_posted += 1
			elif TileFeature.is_wildlife(feature):
				if hunt_posted < max_hunt and not JobManager.has_job_at(tile):
					if JobManager.post(Job.Type.HUNT, tile) != null:
						hunt_posted += 1
			elif feature == TileFeature.Type.RIVER:
				if fish_posted < max_fish and not JobManager.has_job_at(tile):
					if JobManager.post(Job.Type.FISH, tile) != null:
						fish_posted += 1


## Walk the world's feature grid and post initial jobs. Only features on the
## main landmass are considered -- unreachable ones stay dormant until a
## future designation UI lets the player explicitly queue them.
## MINE jobs resolve a work_tile: the passable neighbor the pawn stands on
## while mining. Ore with no reachable neighbor is skipped.
func _seed_jobs_from_world() -> void:
	var main_component: int = _world.pathfinder.largest_component_id()
	var forage_tiles: Array[Vector2i] = []
	var mine_tiles: Array[Vector2i] = []
	var chop_tiles: Array[Vector2i] = []
	var hunt_tiles: Array[Vector2i] = []
	var fishing_tiles: Array[Vector2i] = []
	for y in range(WorldData.HEIGHT):
		for x in range(WorldData.WIDTH):
			var f: int = _world.data.get_feature(x, y)
			if f == TileFeature.Type.FERTILE_SOIL:
				forage_tiles.append(Vector2i(x, y))
			elif f == TileFeature.Type.ORE_VEIN:
				mine_tiles.append(Vector2i(x, y))
			elif f == TileFeature.Type.TREE:
				chop_tiles.append(Vector2i(x, y))
			elif TileFeature.is_wildlife(f):
				hunt_tiles.append(Vector2i(x, y))
			elif f == TileFeature.Type.RIVER:
				fishing_tiles.append(Vector2i(x, y))
	_sort_tiles_by_seeded_order(forage_tiles, &"seed_jobs:forage")
	_sort_tiles_by_seeded_order(mine_tiles, &"seed_jobs:mine")
	_sort_tiles_by_seeded_order(chop_tiles, &"seed_jobs:chop")
	_sort_tiles_by_seeded_order(hunt_tiles, &"seed_jobs:hunt")
	_sort_tiles_by_seeded_order(fishing_tiles, &"seed_jobs:fish")
	var forage_posted: int = 0
	var forage_skipped: int = 0
	var mine_posted: int = 0
	var mine_skipped: int = 0
	var chop_posted: int = 0
	var chop_skipped: int = 0
	var hunt_posted: int = 0
	var hunt_skipped: int = 0
	var fish_posted: int = 0
	for tile in forage_tiles:
		if forage_posted >= MAX_FORAGE_JOBS:
			break
		if _world.pathfinder.component_of(tile) != main_component:
			forage_skipped += 1
			continue
		if not _can_post_job_at(tile):
			forage_skipped += 1
			_jobs_suppressed_this_session += 1
			if GameManager != null and GameManager.verbose_logs():
				var expiry_f: int = int(_job_post_cooldowns.get(_tile_job_key(tile), 0))
				var rem_f: int = expiry_f - GameManager.tick_count
				print("[JobCooldown] Suppressed %s at tile %s (cooldown remaining: %d)" % [Job.describe_type(Job.Type.FORAGE), tile, rem_f])
			continue
		var fj: Job = JobManager.post(Job.Type.FORAGE, tile, FORAGE_PRIORITY, FORAGE_WORK_TICKS)
		if fj != null:
			_set_job_post_cooldown(tile)
			forage_posted += 1
	for tile in mine_tiles:
		if mine_posted >= MAX_MINE_JOBS:
			break
		var work_tile: Vector2i = _world.pathfinder.find_adjacent_passable(tile)
		if work_tile.x < 0 or _world.pathfinder.component_of(work_tile) != main_component:
			mine_skipped += 1
			continue
		if not _can_post_job_at(tile):
			mine_skipped += 1
			_jobs_suppressed_this_session += 1
			if GameManager != null and GameManager.verbose_logs():
				var expiry_m: int = int(_job_post_cooldowns.get(_tile_job_key(tile), 0))
				var rem_m: int = expiry_m - GameManager.tick_count
				print("[JobCooldown] Suppressed %s at tile %s (cooldown remaining: %d)" % [Job.describe_type(Job.Type.MINE), tile, rem_m])
			continue
		var job: Job = JobManager.post(Job.Type.MINE, tile, MINE_PRIORITY, MINE_WORK_TICKS)
		if job == null:
			continue
		job.work_tile = work_tile
		_set_job_post_cooldown(tile)
		mine_posted += 1
	# CHOP: trees stand on passable tiles, so work_tile = the tree tile itself
	# (forage-style). The pawn walks onto the tree to chop it.
	for tile in chop_tiles:
		if chop_posted >= MAX_CHOP_JOBS:
			break
		if _world.pathfinder.component_of(tile) != main_component:
			chop_skipped += 1
			continue
		if _can_post_job_at(tile):
			var cj: Job = JobManager.post(Job.Type.CHOP, tile, CHOP_PRIORITY, CHOP_WORK_TICKS)
			if cj != null:
				_set_job_post_cooldown(tile)
				chop_posted += 1
		else:
			chop_skipped += 1
			_jobs_suppressed_this_session += 1
			if GameManager != null and GameManager.verbose_logs():
				var expiry_c: int = int(_job_post_cooldowns.get(_tile_job_key(tile), 0))
				var rem_c: int = expiry_c - GameManager.tick_count
				print("[JobCooldown] Suppressed %s at tile %s (cooldown remaining: %d)" % [Job.describe_type(Job.Type.CHOP), tile, rem_c])
	# HUNT: animals also stand on passable tiles -- the pawn walks onto the
	# tile to hunt them, like CHOP. work_tile defaults to tile (Job.gd default).
	if (
			Main._world_stabilization_until_tick >= 0
			and GameManager.tick_count >= Main._world_stabilization_until_tick
			and _should_post_more_hunt_jobs()
	):
		var live_seed: Dictionary = _live_wildlife_counts()
		var hunt_cap_seed: int = mini(MAX_DYNAMIC_HUNT_JOBS_PER_PASS, _dynamic_hunt_job_budget())
		for tile in hunt_tiles:
			if hunt_posted >= hunt_cap_seed:
				break
			if _world.pathfinder.component_of(tile) != main_component:
				hunt_skipped += 1
				continue
			var feat: int = _world.data.get_feature(tile.x, tile.y)
			var species_seed: int = Animal.Type.DEER if feat == TileFeature.Type.DEER else Animal.Type.RABBIT
			var live_now_seed: int = int(live_seed.get(species_seed, 0))
			if live_now_seed <= _hunt_reserve_for_species(species_seed):
				continue
			if _can_post_job_at(tile):
				var hj: Job = JobManager.post(Job.Type.HUNT, tile, HUNT_PRIORITY, _hunt_ticks_for(feat))
				if hj != null:
					_set_job_post_cooldown(tile)
					live_seed[species_seed] = maxi(0, live_now_seed - 1)
					hunt_posted += 1
			else:
				hunt_skipped += 1
				_jobs_suppressed_this_session += 1
				if GameManager != null and GameManager.verbose_logs():
					var expiry_hs: int = int(_job_post_cooldowns.get(_tile_job_key(tile), 0))
					var rem_hs: int = expiry_hs - GameManager.tick_count
					print("[JobCooldown] Suppressed %s at tile %s (cooldown remaining: %d)" % [Job.describe_type(Job.Type.HUNT), tile, rem_hs])
	# FISH: river tiles -- pawn stands on or next to river
	for tile in fishing_tiles:
		if fish_posted >= MAX_FISH_JOBS:
			break
		if _world.pathfinder.component_of(tile) != main_component:
			continue
		if _can_post_job_at(tile):
			var fj: Job = JobManager.post(Job.Type.FISH, tile, FISH_PRIORITY, FISH_WORK_TICKS)
			if fj != null:
				_set_job_post_cooldown(tile)
				fish_posted += 1
	if OS.is_debug_build():
		print(
				"[Main] Seeded jobs: %d forage, %d mine, %d chop, %d hunt, %d fish  (pool: %d fertile / %d ore / %d tree / %d wildlife / %d river; skipped: F%d M%d C%d H%d off-mainland)" %
				[forage_posted, mine_posted, chop_posted, hunt_posted, fish_posted,
					forage_tiles.size(), mine_tiles.size(), chop_tiles.size(), hunt_tiles.size(), fishing_tiles.size(),
					forage_skipped, mine_skipped, chop_skipped, hunt_skipped]
		)


func _sort_tiles_by_seeded_order(tiles: Array[Vector2i], stream_name: StringName) -> void:
	tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var key_a: int = _tile_seeded_order_key(a, stream_name)
		var key_b: int = _tile_seeded_order_key(b, stream_name)
		if key_a == key_b:
			return a.y * WorldData.WIDTH + a.x < b.y * WorldData.WIDTH + b.x
		return key_a < key_b
	)


## Periodic construction job seeder: posts build/cook/plant jobs based on
## what each settlement actually needs. Runs every ~200 ticks so pawns
## build farms, walls, hearths, beds, etc. instead of only foraging.
var _last_construction_seed_tick: int = -10000
var _nav_dirty: bool = false  # batched nav notification for construction seed
var _construction_seed_posts_since_log: int = 0
var _last_construction_seed_log_tick: int = -10000
var _construction_seed_cursor: int = 0

func _count_pending_jobs_near(job_type: int, center: Vector2i, radius: int, cached_jobs: Array = []) -> int:
	if JobManager == null:
		return 0
	var n: int = 0
	var jobs: Array = cached_jobs if cached_jobs.size() > 0 else (JobManager.get_active_jobs_union() if JobManager.has_method("get_active_jobs_union") else [])
	for jv in jobs:
		if not (jv is Job):
			continue
		var j: Job = jv as Job
		if job_type >= 0 and j.type != job_type:
			continue
		if maxi(absi(j.tile.x - center.x), absi(j.tile.y - center.y)) <= radius:
			n += 1
	return n


func _seed_construction_jobs() -> void:
	if _world == null or _world.data == null:
		return
	var tick: int = GameManager.tick_count
	if Main._world_stabilization_until_tick >= 0 and tick < Main._world_stabilization_until_tick:
		return
	var interval: int = _high_speed_interval(60, 120, 300)
	if tick - _last_construction_seed_tick < interval:
		return
	_last_construction_seed_tick = tick
	var budget_usec: int = 6_000  # small per-frame budget; scheduler continues next pass
	var start_usec: int = Time.get_ticks_usec()
	var pending_counts: Dictionary = JobManager.get_pending_counts() if JobManager != null and JobManager.has_method("get_pending_counts") else {}
	# Cache active jobs union once — avoids re-scanning all jobs per _count_pending_jobs_near call
	var _cached_active_jobs: Array = JobManager.get_active_jobs_union() if JobManager != null and JobManager.has_method("get_active_jobs_union") else []
	var stock_wood: int = StockpileManager.total_count_of(Item.Type.WOOD) if StockpileManager != null else 0
	var stock_stone: int = StockpileManager.total_count_of(Item.Type.STONE) if StockpileManager != null else 0
	var materials_crisis: bool = stock_wood <= 2 or stock_stone <= 2

	var posted: int = 0
	var settlements: Array = SettlementMemory.get_formal_settlements()
	if settlements.is_empty():
		return
	var max_settlements_this_pass: int = 1 if GameManager.game_speed >= 50.0 else 2
	var settlements_seen: int = 0
	var start_idx: int = _construction_seed_cursor % settlements.size()
	for step in range(settlements.size()):
		if settlements_seen >= max_settlements_this_pass:
			break
		var s = settlements[(start_idx + step) % settlements.size()]
		if Time.get_ticks_usec() - start_usec >= budget_usec:
			break
		if not (s is Dictionary):
			continue
		var sd: Dictionary = s as Dictionary
		var state: String = str(sd.get("state", ""))
		if state == "abandoned" or state == "permanently_abandoned":
			continue
		var center_rk: int = int(sd.get("center_region", -1))
		if center_rk < 0:
			continue
		# Convert region key to center tile
		var crx: int = center_rk & 0xFFFF
		var cry: int = (center_rk >> 16) & 0xFFFF
		var center_tile: Vector2i = Vector2i(crx * 16 + 8, cry * 16 + 8)
		# Use settlement-maintained population value to avoid O(settlements * pawns) scans every seed pass.
		var local_pop: int = int(sd.get("population", 0))
		if local_pop < 1:
			continue
		settlements_seen += 1
		# Quick check: if this settlement already has many pending jobs, skip the expensive scan
		var nearby_pending: int = _count_pending_jobs_near(-1, center_tile, 8, _cached_active_jobs)
		if nearby_pending >= 5:
			continue
		# Scan local features (beds, walls, hearths, etc.) — reduced radius for budget
		var features: Dictionary = HeelKawnianManager._scan_local_features(center_tile, 4)
		var beds: int = int(features.get("bed", 0))
		var walls: int = int(features.get("wall", 0))
		var doors: int = int(features.get("door", 0))
		var hearths: int = int(features.get("hearth", 0))
		var storage_huts: int = int(features.get("storage_hut", 0))
		# Phase 6: new building counts
		var farms: int = int(features.get("farm", 0))
		var workshops: int = int(features.get("workshop", 0))
		var granaries: int = int(features.get("granary", 0))
		var apothecaries: int = int(features.get("apothecary", 0))
		var libraries: int = int(features.get("library", 0))
		var markets: int = int(features.get("market", 0))
		var barracks: int = int(features.get("barracks", 0))
		var cellars: int = int(features.get("cellar", 0))
		# Ensure settlement has a stockpile zone — pawns need a local drop point
		# Deferred: stockpile creation (add_child) is expensive in rendered mode
		if not _settlement_has_nearby_stockpile(center_tile):
			call_deferred("_ensure_settlement_stockpile", center_tile)
		# Post a handful of jobs per settlement per cycle; this is a scheduler, not a flood-fill.
		var jobs_this_settlement: int = 0
		var job_cap: int = 4 if materials_crisis else 7
		# Priority 0: Beds when housing crisis is critical
		if ColonySimServices != null and ColonySimServices.get_housing_pressure() > 0.8 and jobs_this_settlement < job_cap:
			var need_beds_crisis: int = maxi(3, int(ceil(float(local_pop) * 0.75)))
			var pending_beds_crisis: int = _count_pending_jobs_near(Job.Type.BUILD_BED, center_tile, 10, _cached_active_jobs)
			var beds_posted_this_cycle: int = 0
			if beds + pending_beds_crisis < need_beds_crisis:
				var house_posts: int = _post_house_blueprint_jobs(center_tile, mini(4, need_beds_crisis - beds - pending_beds_crisis), job_cap - jobs_this_settlement)
				posted += house_posts
				jobs_this_settlement += house_posts
				beds_posted_this_cycle += mini(house_posts, 4)
			while beds + pending_beds_crisis + beds_posted_this_cycle < need_beds_crisis and beds_posted_this_cycle < 2 and jobs_this_settlement < job_cap:
				var t: Vector2i = _find_build_tile_near(center_tile, 4)
				if t.x >= 0 and not JobManager.has_job_at(t):
					var j: Job = JobManager.post(Job.Type.BUILD_BED, t, 8, 10)
					if j != null:
						posted += 1
						jobs_this_settlement += 1
						beds_posted_this_cycle += 1
						pending_counts[Job.Type.BUILD_BED] = int(pending_counts.get(Job.Type.BUILD_BED, 0)) + 1
					else:
						break
				else:
					break
		# Budget check after housing crisis (most expensive priority)
		if Time.get_ticks_usec() - start_usec >= budget_usec:
			break
		# Priority 1: Fire pit — need 1 per 4 pawns for warmth
		var hearths_needed: int = maxi(1, local_pop / 4)
		if hearths < hearths_needed and jobs_this_settlement < job_cap:
			var pending_fire_pits: int = _count_pending_jobs_near(Job.Type.BUILD_FIRE_PIT, center_tile, 10, _cached_active_jobs)
			if pending_fire_pits == 0:
				var t: Vector2i = _find_build_tile_near(center_tile, 4)
				if t.x >= 0 and not JobManager.has_job_at(t):
					var j: Job = JobManager.post(Job.Type.BUILD_FIRE_PIT, t, 7, 12)
					if j != null:
						posted += 1
						jobs_this_settlement += 1
						pending_counts[Job.Type.BUILD_FIRE_PIT] = int(pending_counts.get(Job.Type.BUILD_FIRE_PIT, 0)) + 1
		# Priority 2: Storage hut if none
		var storage_needed: int = maxi(1, local_pop / 5)
		if storage_huts < storage_needed and local_pop >= 1 and jobs_this_settlement < job_cap:
			var pending_storage: int = _count_pending_jobs_near(Job.Type.BUILD_STORAGE_HUT, center_tile, 10, _cached_active_jobs)
			if pending_storage == 0:
				var t: Vector2i = _find_build_tile_near(center_tile, 4)
				if t.x >= 0 and not JobManager.has_job_at(t):
					var j: Job = JobManager.post(Job.Type.BUILD_STORAGE_HUT, t, 6, 15)
					if j != null:
						posted += 1
						jobs_this_settlement += 1
						pending_counts[Job.Type.BUILD_STORAGE_HUT] = int(pending_counts.get(Job.Type.BUILD_STORAGE_HUT, 0)) + 1
		# Priority 3: Beds if not enough
		var need_beds: int = maxi(2, int(ceil(float(local_pop) * 0.75)))
		var pending_beds: int = _count_pending_jobs_near(Job.Type.BUILD_BED, center_tile, 10, _cached_active_jobs)
		var beds_posted_p3: int = 0
		while beds + pending_beds + beds_posted_p3 < need_beds and beds_posted_p3 < 2 and jobs_this_settlement < job_cap:
			var t: Vector2i = _find_build_tile_near(center_tile, 4)
			if t.x >= 0 and not JobManager.has_job_at(t):
				var j: Job = JobManager.post(Job.Type.BUILD_BED, t, 6, 10)
				if j != null:
					posted += 1
					jobs_this_settlement += 1
					beds_posted_p3 += 1
					pending_counts[Job.Type.BUILD_BED] = int(pending_counts.get(Job.Type.BUILD_BED, 0)) + 1
				else:
					break
			else:
				break
		# Budget check after P3
		if Time.get_ticks_usec() - start_usec >= budget_usec:
			break
		# Priority 4: Connected wall perimeter ring + door
		var pending_walls: int = _count_pending_jobs_near(Job.Type.BUILD_WALL, center_tile, 12, _cached_active_jobs)
		var pending_doors: int = _count_pending_jobs_near(Job.Type.BUILD_DOOR, center_tile, 12, _cached_active_jobs)
		if local_pop >= 1 and not materials_crisis and jobs_this_settlement < job_cap:
			# Scale ring radius and target walls with population
			var ring_radius: int = 3 + mini(2, local_pop / 3)  # 3 for 1-2 pop, 4 for 3-5, 5 for 6+
			var target_walls: int = 8 + local_pop * 2  # 10-20+ walls depending on pop
			if walls + pending_walls < target_walls:
				var max_walls_this_cycle: int = mini(1, target_walls - walls - pending_walls)
				var ring_posted: int = _post_wall_ring_jobs(center_tile, ring_radius, max_walls_this_cycle, job_cap - jobs_this_settlement)
				posted += ring_posted
				jobs_this_settlement += ring_posted
				if ring_posted > 0:
					pending_counts[Job.Type.BUILD_WALL] = int(pending_counts.get(Job.Type.BUILD_WALL, 0)) + ring_posted
			# Post a door if walls exist but no door yet
			if walls + pending_walls >= 3 and doors + pending_doors <= 0 and jobs_this_settlement < job_cap:
				var door_side: Vector2i = center_tile + Vector2i(0, ring_radius)
				if _world.data.in_bounds(door_side.x, door_side.y) and not JobManager.has_job_at(door_side):
					var dj: Job = JobManager.post(Job.Type.BUILD_DOOR, door_side, 5, 8)
					if dj != null:
						posted += 1
						jobs_this_settlement += 1
						pending_counts[Job.Type.BUILD_DOOR] = int(pending_counts.get(Job.Type.BUILD_DOOR, 0)) + 1
		# Budget check: break early if we've exceeded time budget
		if Time.get_ticks_usec() - start_usec >= budget_usec:
			break
		# Priority 5: Plant seeds on nearby fertile soil
		if jobs_this_settlement < job_cap:
			var ft: Vector2i = _find_fertile_tile_near(center_tile, 5)
			if ft.x >= 0 and not JobManager.has_job_at(ft):
				var j: Job = JobManager.post(Job.Type.PLANT_SEEDS, ft, 4, 6)
				if j != null:
					posted += 1
					jobs_this_settlement += 1
					pending_counts[Job.Type.PLANT_SEEDS] = int(pending_counts.get(Job.Type.PLANT_SEEDS, 0)) + 1
		# Budget check after P5
		if Time.get_ticks_usec() - start_usec >= budget_usec:
			break
		# Priority 6: Cook food if fire pit exists and raw food available
		if hearths > 0 and jobs_this_settlement < job_cap:
			var meat_count: int = StockpileManager.total_count_of(Item.Type.MEAT)
			var fish_count: int = StockpileManager.total_count_of(Item.Type.FISH)
			var berry_count: int = StockpileManager.total_count_of(Item.Type.BERRY)
			if meat_count > 0:
				var t: Vector2i = _find_hearth_tile_near(center_tile, 5)
				if t.x >= 0 and not JobManager.has_job_at(t):
					var j: Job = JobManager.post(Job.Type.COOK_MEAT, t, 4, 8)
					if j != null:
						posted += 1
						jobs_this_settlement += 1
						pending_counts[Job.Type.COOK_MEAT] = int(pending_counts.get(Job.Type.COOK_MEAT, 0)) + 1
			elif fish_count > 0:
				var t: Vector2i = _find_hearth_tile_near(center_tile, 5)
				if t.x >= 0 and not JobManager.has_job_at(t):
					var j: Job = JobManager.post(Job.Type.COOK_FISH, t, 4, 6)
					if j != null:
						posted += 1
						jobs_this_settlement += 1
						pending_counts[Job.Type.COOK_FISH] = int(pending_counts.get(Job.Type.COOK_FISH, 0)) + 1
			elif berry_count >= 2:
				var t: Vector2i = _find_hearth_tile_near(center_tile, 5)
				if t.x >= 0 and not JobManager.has_job_at(t):
					var j: Job = JobManager.post(Job.Type.COOK_BERRIES, t, 3, 5)
					if j != null:
						posted += 1
						jobs_this_settlement += 1
						pending_counts[Job.Type.COOK_BERRIES] = int(pending_counts.get(Job.Type.COOK_BERRIES, 0)) + 1
		# Priority 6b: Preserve built life and at-risk knowledge.
		if jobs_this_settlement < job_cap and BuildingUsageTracker != null and BuildingUsageTracker.has_method("get_due_maintenance_jobs"):
			for due in BuildingUsageTracker.get_due_maintenance_jobs(2):
				if jobs_this_settlement >= job_cap:
					break
				var mt: Vector2i = due.get("tile", Vector2i(-1, -1))
				if mt.x < 0 or maxi(absi(mt.x - center_tile.x), absi(mt.y - center_tile.y)) > 12:
					continue
				if JobManager.has_job_at(mt):
					continue
				var mj: Job = JobManager.post(Job.Type.MAINTAIN_STRUCTURE, mt, int(due.get("priority", 5)), 8)
				if mj != null:
					posted += 1
					jobs_this_settlement += 1
		if jobs_this_settlement < job_cap and KnowledgeSystem != null and KnowledgeSystem.has_method("get_at_risk_knowledge_types"):
			var at_risk_knowledge: Array = KnowledgeSystem.get_at_risk_knowledge_types()
			if not at_risk_knowledge.is_empty() and int(pending_counts.get(Job.Type.TEACH_SKILL, 0)) < 2:
				var tj: Job = JobManager.post(Job.Type.TEACH_SKILL, center_tile, 7, 10)
				if tj != null:
					posted += 1
					jobs_this_settlement += 1
					pending_counts[Job.Type.TEACH_SKILL] = int(pending_counts.get(Job.Type.TEACH_SKILL, 0)) + 1
		if materials_crisis:
			var recovery_posts: int = _post_material_recovery_jobs(center_tile, job_cap - jobs_this_settlement)
			posted += recovery_posts
			jobs_this_settlement += recovery_posts
			continue
		# Budget check before Phase 6 building priorities
		if Time.get_ticks_usec() - start_usec >= budget_usec:
			break
		# Priority 7: Farm if none and enough population
		if farms <= 0 and local_pop >= 2 and jobs_this_settlement < job_cap:
			var pending_farms: int = int(pending_counts.get(Job.Type.BUILD_FARM_WHEAT, 0))
			if pending_farms == 0:
				var t: Vector2i = _find_fertile_tile_near(center_tile, 5)
				if t.x >= 0 and not JobManager.has_job_at(t):
					var j: Job = JobManager.post(Job.Type.BUILD_FARM_WHEAT, t, 5, 30)
					if j != null:
						posted += 1
						jobs_this_settlement += 1
						pending_counts[Job.Type.BUILD_FARM_WHEAT] = int(pending_counts.get(Job.Type.BUILD_FARM_WHEAT, 0)) + 1
		# Priority 8: Workshop if none and enough population
		if workshops <= 0 and local_pop >= 3 and jobs_this_settlement < job_cap:
			var pending_workshops: int = int(pending_counts.get(Job.Type.BUILD_WORKSHOP, 0))
			if pending_workshops == 0:
				var t: Vector2i = _find_build_tile_near(center_tile, 4)
				if t.x >= 0 and not JobManager.has_job_at(t):
					var j: Job = JobManager.post(Job.Type.BUILD_WORKSHOP, t, 5, 40)
					if j != null:
						posted += 1
						jobs_this_settlement += 1
						pending_counts[Job.Type.BUILD_WORKSHOP] = int(pending_counts.get(Job.Type.BUILD_WORKSHOP, 0)) + 1
		# Priority 9: Granary if farms exist but no granary
		if granaries <= 0 and farms >= 1 and local_pop >= 2 and jobs_this_settlement < job_cap:
			var pending_granaries: int = int(pending_counts.get(Job.Type.BUILD_GRANARY, 0))
			if pending_granaries == 0:
				var t: Vector2i = _find_build_tile_near(center_tile, 4)
				if t.x >= 0 and not JobManager.has_job_at(t):
					var j: Job = JobManager.post(Job.Type.BUILD_GRANARY, t, 5, 35)
					if j != null:
						posted += 1
						jobs_this_settlement += 1
						pending_counts[Job.Type.BUILD_GRANARY] = int(pending_counts.get(Job.Type.BUILD_GRANARY, 0)) + 1
		# Budget check after P9
		if Time.get_ticks_usec() - start_usec >= budget_usec:
			break
		# Priority 10: Apothecary if none and enough population
		if apothecaries <= 0 and local_pop >= 3 and jobs_this_settlement < job_cap:
			var pending_apothecaries: int = int(pending_counts.get(Job.Type.BUILD_APOTHECARY, 0))
			if pending_apothecaries == 0:
				var t: Vector2i = _find_build_tile_near(center_tile, 4)
				if t.x >= 0 and not JobManager.has_job_at(t):
					var j: Job = JobManager.post(Job.Type.BUILD_APOTHECARY, t, 5, 40)
					if j != null:
						posted += 1
						jobs_this_settlement += 1
						pending_counts[Job.Type.BUILD_APOTHECARY] = int(pending_counts.get(Job.Type.BUILD_APOTHECARY, 0)) + 1
		# Priority 11: Market if farms exist and enough population
		if markets <= 0 and farms >= 1 and local_pop >= 4 and jobs_this_settlement < job_cap:
			var pending_markets: int = int(pending_counts.get(Job.Type.BUILD_MARKET, 0))
			if pending_markets == 0:
				var t: Vector2i = _find_build_tile_near(center_tile, 4)
				if t.x >= 0 and not JobManager.has_job_at(t):
					var j: Job = JobManager.post(Job.Type.BUILD_MARKET, t, 6, 40)
					if j != null:
						posted += 1
						jobs_this_settlement += 1
						pending_counts[Job.Type.BUILD_MARKET] = int(pending_counts.get(Job.Type.BUILD_MARKET, 0)) + 1
		# Budget check before late building priorities
		if Time.get_ticks_usec() - start_usec >= budget_usec:
			break
		# Priority 12: Library if enough population and writing exists
		if libraries <= 0 and local_pop >= 4 and jobs_this_settlement < job_cap:
			var pending_libraries: int = int(pending_counts.get(Job.Type.BUILD_LIBRARY, 0))
			if pending_libraries == 0:
				var t: Vector2i = _find_build_tile_near(center_tile, 4)
				if t.x >= 0 and not JobManager.has_job_at(t):
					var j: Job = JobManager.post(Job.Type.BUILD_LIBRARY, t, 6, 45)
					if j != null:
						posted += 1
						jobs_this_settlement += 1
						pending_counts[Job.Type.BUILD_LIBRARY] = int(pending_counts.get(Job.Type.BUILD_LIBRARY, 0)) + 1
		# Priority 13: Barracks if walled settlement with enough population
		if barracks <= 0 and walls >= 4 and local_pop >= 4 and jobs_this_settlement < job_cap:
			var pending_barracks: int = int(pending_counts.get(Job.Type.BUILD_BARRACKS, 0))
			if pending_barracks == 0:
				var t: Vector2i = _find_build_tile_near(center_tile, 4)
				if t.x >= 0 and not JobManager.has_job_at(t):
					var j: Job = JobManager.post(Job.Type.BUILD_BARRACKS, t, 6, 45)
					if j != null:
						posted += 1
						jobs_this_settlement += 1
						pending_counts[Job.Type.BUILD_BARRACKS] = int(pending_counts.get(Job.Type.BUILD_BARRACKS, 0)) + 1
		# Budget check after P13
		if Time.get_ticks_usec() - start_usec >= budget_usec:
			break
		# Priority 14: Cellar if granary exists and enough population
		if cellars <= 0 and granaries >= 1 and local_pop >= 3 and jobs_this_settlement < job_cap:
			var pending_cellars: int = int(pending_counts.get(Job.Type.BUILD_CELLAR, 0))
			if pending_cellars == 0:
				var t: Vector2i = _find_build_tile_near(center_tile, 4)
				if t.x >= 0 and not JobManager.has_job_at(t):
					var j: Job = JobManager.post(Job.Type.BUILD_CELLAR, t, 6, 35)
					if j != null:
						posted += 1
						jobs_this_settlement += 1
						pending_counts[Job.Type.BUILD_CELLAR] = int(pending_counts.get(Job.Type.BUILD_CELLAR, 0)) + 1
		# Priority 15: Watchtower if enough population
		if int(features.get("watchtower", 0)) <= 0 and local_pop >= 3 and jobs_this_settlement < job_cap:
			var pending_watchtowers: int = int(pending_counts.get(Job.Type.BUILD_WATCHTOWER, 0))
			if pending_watchtowers == 0:
				var t: Vector2i = _find_build_tile_near(center_tile, 4)
				if t.x >= 0 and not JobManager.has_job_at(t):
					var j: Job = JobManager.post(Job.Type.BUILD_WATCHTOWER, t, 6, 40)
					if j != null:
						posted += 1
						jobs_this_settlement += 1
						pending_counts[Job.Type.BUILD_WATCHTOWER] = int(pending_counts.get(Job.Type.BUILD_WATCHTOWER, 0)) + 1
		# Priority 16: School if library exists
			# Budget check after P15
		if Time.get_ticks_usec() - start_usec >= budget_usec:
			break
		if int(features.get("school", 0)) <= 0 and libraries >= 1 and local_pop >= 4 and jobs_this_settlement < job_cap:
			var pending_schools: int = int(pending_counts.get(Job.Type.BUILD_SCHOOL, 0))
			if pending_schools == 0:
				var t: Vector2i = _find_build_tile_near(center_tile, 4)
				if t.x >= 0 and not JobManager.has_job_at(t):
					var j: Job = JobManager.post(Job.Type.BUILD_SCHOOL, t, 6, 40)
					if j != null:
						posted += 1
						jobs_this_settlement += 1
						pending_counts[Job.Type.BUILD_SCHOOL] = int(pending_counts.get(Job.Type.BUILD_SCHOOL, 0)) + 1
		# Priority 17: Trading post if market exists
		if int(features.get("trading_post", 0)) <= 0 and markets >= 1 and local_pop >= 4 and jobs_this_settlement < job_cap:
			var pending_trading_posts: int = int(pending_counts.get(Job.Type.BUILD_TRADING_POST, 0))
			if pending_trading_posts == 0:
				var t: Vector2i = _find_build_tile_near(center_tile, 4)
				if t.x >= 0 and not JobManager.has_job_at(t):
					var j: Job = JobManager.post(Job.Type.BUILD_TRADING_POST, t, 5, 40)
					if j != null:
						posted += 1
						jobs_this_settlement += 1
						pending_counts[Job.Type.BUILD_TRADING_POST] = int(pending_counts.get(Job.Type.BUILD_TRADING_POST, 0)) + 1
		# Budget check before expensive road scan
		if Time.get_ticks_usec() - start_usec >= budget_usec:
			break
		# Priority 18: Local paths — post BUILD_ROAD along high-traffic tiles within settlement
		if jobs_this_settlement < job_cap and local_pop >= 2:
			var pending_roads: int = int(pending_counts.get(Job.Type.BUILD_ROAD, 0))
			if pending_roads < 3:
				var roads_posted: int = 0
				for ry in range(center_tile.y - 4, center_tile.y + 5):
					for rx in range(center_tile.x - 4, center_tile.x + 5):
						if not _world.data.in_bounds(rx, ry):
							continue
						var trav: int = RoadMemory.get_traversal(rx, ry)
						if trav < RoadMemory.ROAD_T1:
							continue
						if _world.data.get_feature(rx, ry) == TileFeature.Type.ROAD:
							continue
						if _world.data.get_feature(rx, ry) != TileFeature.Type.NONE:
							continue
						if not _world.pathfinder.is_passable(Vector2i(rx, ry)):
							continue
						if JobManager.has_job_at(Vector2i(rx, ry)):
							continue
						var j: Job = JobManager.post(Job.Type.BUILD_ROAD, Vector2i(rx, ry), 5, 8)
						if j != null:
							posted += 1
							jobs_this_settlement += 1
							roads_posted += 1
							pending_counts[Job.Type.BUILD_ROAD] = int(pending_counts.get(Job.Type.BUILD_ROAD, 0)) + 1
						if roads_posted >= 2:
							break
					if roads_posted >= 2:
						break
	_construction_seed_cursor = (start_idx + max(1, settlements_seen)) % maxi(1, settlements.size())
	# Micro-profile log: show which sections took the most time
	var total_usec: int = Time.get_ticks_usec() - start_usec
	if total_usec > 10000 and OS.is_debug_build():
		print("[CONSTRUCTION_SEED] WARNING: took %dus (budget=%dus) settlements_seen=%d posted=%d" % [total_usec, budget_usec, settlements_seen, posted])
	# Batched nav notification — only call once after all wall rings processed
	if _nav_dirty and _world != null:
		_world.notify_pawns_nav_changed()
		_nav_dirty = false
	if posted > 0:
		_construction_seed_posts_since_log += posted
		if tick - _last_construction_seed_log_tick >= 1000:
			print("[Main] Construction seed: posted %d build jobs (last %d ticks)" % [_construction_seed_posts_since_log, tick - _last_construction_seed_log_tick])
			_construction_seed_posts_since_log = 0
			_last_construction_seed_log_tick = tick


## Build roads along trade routes — places ROAD tiles on the world map.
## Called periodically from the tick loop.
func _build_roads_from_trade_routes() -> void:
	if _world == null or _world.data == null:
		return
	if TradeMemory == null:
		return
	var routes: Array[Dictionary] = TradeMemory.get_active_routes()
	for r in routes:
		var from_rk: int = int(r.get("from_settlement", -1))
		var to_rk: int = int(r.get("to_settlement", -1))
		if from_rk < 0 or to_rk < 0:
			continue
		# Convert region keys to center tiles
		var frx: int = from_rk & 0xFFFF
		var fry: int = (from_rk >> 16) & 0xFFFF
		var trx: int = to_rk & 0xFFFF
		var try_: int = (to_rk >> 16) & 0xFFFF
		var from_tile: Vector2i = Vector2i(frx * 16 + 8, fry * 16 + 8)
		var to_tile: Vector2i = Vector2i(trx * 16 + 8, try_ * 16 + 8)
		# Use pathfinder to find path, then place roads along it
		if _world.pathfinder != null:
			var path: Array[Vector2i] = _world.pathfinder.find_path(from_tile, to_tile)
			for i in range(path.size()):
				var tile: Vector2i = path[i]
				if _world.data.in_bounds(tile.x, tile.y):
					var idx: int = _world.data.index(tile.x, tile.y)
					var feat: int = _world.data.features[idx]
					if feat == TileFeature.Type.NONE and Biome.is_passable(_world.data.biome_at(tile.x, tile.y)):
						_world.data.features[idx] = TileFeature.Type.ROAD
	# Refresh world texture so roads appear on the map
	if is_instance_valid(_world):
		_world.refresh_terrain_scar_tint()


## Find an empty passable tile near center for building.
## Allows tiles with clearable features (TREE, FERTILE_SOIL, ORE_VEIN, RUIN)
## since set_feature overwrites them on build completion.


## Post walls in a connected rectangular ring around a settlement center.
## Leaves a 1-tile gap on the south side for a door. Returns walls posted.
func _post_wall_ring_jobs(center: Vector2i, ring_radius: int, max_walls: int, max_jobs: int) -> int:
	if _world == null or _world.data == null or _world.pathfinder == null:
		return 0
	var main_component: int = _world.pathfinder.largest_component_id()
	var posted_walls: int = 0
	var total_jobs: int = 0
	var reserved_tiles: Array[Vector2i] = []
	# Iterate all 4 sides of the rectangular ring
	for side in range(4):
		if posted_walls >= max_walls or total_jobs >= max_jobs:
			break
		for i in range(-ring_radius, ring_radius + 1):
			if posted_walls >= max_walls or total_jobs >= max_jobs:
				break
			# Leave a 2-tile gap on the south side (side==1) for the door
			if side == 1 and abs(i) <= 0:
				continue
			var dx: int = 0
			var dy: int = 0
			match side:
				0: dx = i; dy = -ring_radius   # top
				1: dx = i; dy = ring_radius     # bottom
				2: dx = -ring_radius; dy = i    # left
				3: dx = ring_radius; dy = i     # right
			var t: Vector2i = center + Vector2i(dx, dy)
			var work_tile: Vector2i = _find_main_component_neighbor(t, main_component)
			if work_tile.x < 0 or not _is_valid_build_site(t, main_component):
				continue
			if JobManager.has_job_at(t):
				continue
			var job: Job = JobManager.post(Job.Type.BUILD_WALL, t, BUILD_WALL_PRIORITY, BUILD_WALL_WORK_TICKS)
			if job != null:
				job.work_tile = work_tile
				reserved_tiles.append(t)
				posted_walls += 1
				total_jobs += 1
	if not reserved_tiles.is_empty():
		_world.pathfinder.set_job_construction_reservations_batch(reserved_tiles, true, _world.data, "settlement_wall_ring")
		for wt in reserved_tiles:
			_world.kick_occupants_off_reserved_build_tile(wt.x, wt.y)
		# Defer nav notification — caller batches it at end of seed pass
		_nav_dirty = true
	return posted_walls


func _post_house_blueprint_jobs(center: Vector2i, needed_beds: int, max_jobs: int) -> int:
	if _world == null or _world.data == null or JobManager == null:
		return 0
	if max_jobs <= 0 or needed_beds <= 0:
		return 0
	var anchor: Vector2i = _find_build_tile_near(center + Vector2i(1, 1), 4)
	if anchor.x < 0:
		return 0
	var posted: int = 0
	var interior: Array[Vector2i] = [
		anchor,
		anchor + Vector2i(1, 0),
		anchor + Vector2i(0, 1),
		anchor + Vector2i(1, 1),
	]
	for i in range(mini(needed_beds, interior.size())):
		if posted >= max_jobs:
			return posted
		var bt: Vector2i = interior[i]
		if _world.data.in_bounds(bt.x, bt.y) and not JobManager.has_job_at(bt):
			var bj: Job = JobManager.post(Job.Type.BUILD_BED, bt, 8, 8)
			if bj != null:
				posted += 1
	if posted >= max_jobs:
		return posted
	var hearth_tile: Vector2i = anchor + Vector2i(2, 1)
	if _world.data.in_bounds(hearth_tile.x, hearth_tile.y) and not JobManager.has_job_at(hearth_tile):
		var hj: Job = JobManager.post(Job.Type.BUILD_FIRE_PIT, hearth_tile, 7, 12)
		if hj != null:
			posted += 1
	if posted >= max_jobs:
		return posted
	var wall_tiles: Array[Vector2i] = [
		anchor + Vector2i(-1, -1), anchor + Vector2i(0, -1), anchor + Vector2i(1, -1), anchor + Vector2i(2, -1),
		anchor + Vector2i(-1, 0), anchor + Vector2i(2, 0),
		anchor + Vector2i(-1, 1), anchor + Vector2i(2, 1),
		anchor + Vector2i(-1, 2), anchor + Vector2i(0, 2), anchor + Vector2i(2, 2),
	]
	var wall_budget: int = mini(max_jobs - posted, 3)
	posted += _post_wall_tiles_batch(wall_tiles, wall_budget)
	var door_tile: Vector2i = anchor + Vector2i(1, 2)
	if posted < max_jobs and _world.data.in_bounds(door_tile.x, door_tile.y) and not JobManager.has_job_at(door_tile):
		var dj: Job = JobManager.post(Job.Type.BUILD_DOOR, door_tile, 7, 6)
		if dj != null:
			posted += 1
	return posted


func _post_wall_tiles_batch(tiles: Array[Vector2i], max_jobs: int) -> int:
	if _world == null or _world.data == null or _world.pathfinder == null:
		return 0
	var main_component: int = _world.pathfinder.largest_component_id()
	var reserved_tiles: Array[Vector2i] = []
	for t in tiles:
		if reserved_tiles.size() >= max_jobs:
			break
		var work_tile: Vector2i = _find_main_component_neighbor(t, main_component)
		if work_tile.x < 0 or not _is_valid_build_site(t, main_component):
			continue
		if JobManager.has_job_at(t):
			continue
		var job: Job = JobManager.post(Job.Type.BUILD_WALL, t, BUILD_WALL_PRIORITY, BUILD_WALL_WORK_TICKS)
		if job == null:
			continue
		job.work_tile = work_tile
		reserved_tiles.append(t)
	if not reserved_tiles.is_empty():
		_world.pathfinder.set_job_construction_reservations_batch(reserved_tiles, true, _world.data, "house_blueprint")
		for wt in reserved_tiles:
			_world.kick_occupants_off_reserved_build_tile(wt.x, wt.y)
		_world.notify_pawns_nav_changed()
	return reserved_tiles.size()


func _post_material_recovery_jobs(center: Vector2i, max_jobs: int) -> int:
	if max_jobs <= 0 or _world == null or _world.data == null:
		return 0
	var posted: int = 0
	var tree_tile: Vector2i = _find_feature_tile_near(center, TileFeature.Type.TREE, 5)
	if tree_tile.x >= 0 and not JobManager.has_job_at(tree_tile):
		if JobManager.post(Job.Type.CHOP, tree_tile, 7, CHOP_WORK_TICKS) != null:
			posted += 1
	if posted >= max_jobs:
		return posted
	var ore_tile: Vector2i = _find_feature_tile_near(center, TileFeature.Type.ORE_VEIN, 6)
	if ore_tile.x >= 0 and not JobManager.has_job_at(ore_tile):
		var work_tile: Vector2i = _world.pathfinder.find_adjacent_passable(ore_tile)
		if work_tile.x < 0:
			return posted
		var mj: Job = JobManager.post(Job.Type.MINE, ore_tile, 7, MINE_WORK_TICKS)
		if mj != null:
			mj.work_tile = work_tile
			posted += 1
	return posted


func _find_feature_tile_near(center: Vector2i, feature_type: int, radius: int) -> Vector2i:
	if _world == null or _world.data == null:
		return Vector2i(-1, -1)
	for r in range(1, radius + 1):
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if abs(x) != r and abs(y) != r:
					continue
				var t: Vector2i = center + Vector2i(x, y)
				if not _world.data.in_bounds(t.x, t.y):
					continue
				if int(_world.data.get_feature(t.x, t.y)) == feature_type:
					return t
	return Vector2i(-1, -1)


## Find an empty passable tile near center for building.
## Allows tiles with clearable features (TREE, FERTILE_SOIL, ORE_VEIN, RUIN)
## since set_feature overwrites them on build completion.
func _find_build_tile_near(center: Vector2i, radius: int) -> Vector2i:
	if _world == null or _world.data == null or _world.pathfinder == null:
		return Vector2i(-1, -1)
	# Prefer feature-free tiles first, then allow clearable features
	for pass_n in range(2):
		for r in range(1, radius + 1):
			for y in range(-r, r + 1):
				for x in range(-r, r + 1):
					if abs(x) != r and abs(y) != r:
						continue
					var t: Vector2i = center + Vector2i(x, y)
					if not _world.data.in_bounds(t.x, t.y):
						continue
					if not _world.pathfinder.is_passable(t):
						continue
					var feat: int = int(_world.data.get_feature(t.x, t.y))
					if pass_n == 0:
						# First pass: only feature-free tiles
						if feat != TileFeature.Type.NONE:
							continue
					else:
						# Second pass: allow clearable features (tree, fertile soil, sticks, flint)
						if feat == TileFeature.Type.WALL or feat == TileFeature.Type.DOOR \
							or feat == TileFeature.Type.BED or feat == TileFeature.Type.FIRE_PIT \
							or feat == TileFeature.Type.STORAGE_HUT or feat == TileFeature.Type.MARKER_STONE \
							or feat == TileFeature.Type.SHRINE or feat == TileFeature.Type.GRAVE_MARKER \
							or feat == TileFeature.Type.KNOWLEDGE_STONE or feat == TileFeature.Type.LEDGER_STONE:
							continue  # Don't build over existing structures
					return t
	return Vector2i(-1, -1)


## Find a fertile soil tile near center for planting.
func _find_fertile_tile_near(center: Vector2i, radius: int) -> Vector2i:
	if _world == null or _world.data == null:
		return Vector2i(-1, -1)
	for r in range(1, radius + 1):
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if abs(x) != r and abs(y) != r:
					continue
				var t: Vector2i = center + Vector2i(x, y)
				if not _world.data.in_bounds(t.x, t.y):
					continue
				var feat: int = int(_world.data.get_feature(t.x, t.y))
				if feat == TileFeature.Type.FERTILE_SOIL:
					return t
	return Vector2i(-1, -1)


## Find a fire pit / hearth tile near center for cooking.
func _find_hearth_tile_near(center: Vector2i, radius: int) -> Vector2i:
	if _world == null or _world.data == null:
		return Vector2i(-1, -1)
	for r in range(1, radius + 1):
		for y in range(-r, r + 1):
			for x in range(-r, r + 1):
				if abs(x) != r and abs(y) != r:
					continue
				var t: Vector2i = center + Vector2i(x, y)
				if not _world.data.in_bounds(t.x, t.y):
					continue
				var feat: int = int(_world.data.get_feature(t.x, t.y))
				if feat == TileFeature.Type.FIRE_PIT:
					return t
	return Vector2i(-1, -1)


## Check if any stockpile zone covers a tile within 16 tiles of center.
func _settlement_has_nearby_stockpile(center: Vector2i) -> bool:
	for z in StockpileManager.zones():
		if z == null or not is_instance_valid(z):
			continue
		if z.chebyshev_distance_from(center) <= 16:
			return true
	return false


## Create a small (2x2) stockpile zone near a settlement center.
func _ensure_settlement_stockpile(center: Vector2i) -> void:
	var t: Vector2i = _find_build_tile_near(center, 4)
	if t.x < 0:
		return
	# Try 2x2 rect anchored at the found tile
	var rect: Rect2i = Rect2i(t.x, t.y, 2, 2)
	if _count_passable_in_rect(rect) < 2:
		# Fall back to 1x1
		rect = Rect2i(t.x, t.y, 1, 1)
	# Check no overlap with existing zones
	for z in StockpileManager.zones():
		if z != null and is_instance_valid(z) and z.contains_tile(t):
			return
	var sp: Stockpile = STOCKPILE_SCENE.instantiate()
	sp.set_filter(Stockpile.Filter.ALL)
	sp.set_rect_tiles(rect)
	sp.position = _world.tile_to_world(rect.position)
	# Assign settlement ownership so pawns prefer their own stockpile
	var rk: int = _WM._region_key(center.x, center.y)
	var sid: int = SettlementMemory.get_settlement_id_for_region(rk)
	if sid >= 0:
		sp.settlement_id = sid
	add_child(sp)
	StockpileManager.register(sp)
	# Bootstrap supplies for new settlement stockpile
	sp.add_item(Item.Type.BERRY, 5)
	sp.add_item(Item.Type.WOOD, 3)
	sp.add_item(Item.Type.STONE, 2)
	if OS.is_debug_build():
		print("[Main] Auto-created stockpile zone at %s for settlement near %s (sid=%d)" % [rect.position, center, sid])


func _tile_seeded_order_key(tile: Vector2i, stream_name: StringName) -> int:
	var salt: int = tile.x * 73856093 + tile.y * 19349663
	return WorldRNG.stream_seed(stream_name, salt)


## Work ticks for a hunt depend on how big the prey is. Anything we don't
## recognize falls back to the rabbit budget so we always return something
## sensible (defensive against future wildlife additions).
static func _hunt_ticks_for(feature: int) -> int:
	if feature == TileFeature.Type.DEER:
		return HUNT_DEER_WORK_TICKS
	return HUNT_RABBIT_WORK_TICKS


## One-shot, deterministic: tiles with wildlife on main component get HUNT if none posted during stab-seed.
func _post_wildlife_hunt_jobs_after_stabilization() -> void:
	if not is_instance_valid(_world) or _world.data == null:
		return
	if not _should_post_more_hunt_jobs():
		return
	var main_component: int = _world.pathfinder.largest_component_id()
	if main_component < 0:
		return
	var tiles: Array[Vector2i] = []
	for y in range(WorldData.HEIGHT):
		for x in range(WorldData.WIDTH):
			if _world.pathfinder.component_of(Vector2i(x, y)) != main_component:
				continue
			var f: int = _world.data.get_feature(x, y)
			if not TileFeature.is_wildlife(f):
				continue
			tiles.append(Vector2i(x, y))
	tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y * WorldData.WIDTH + a.x < b.y * WorldData.WIDTH + b.x
	)
	var n: int = 0
	var live_bootstrap: Dictionary = _live_wildlife_counts()
	var cap: int = mini(MAX_DYNAMIC_HUNT_JOBS_PER_PASS, _dynamic_hunt_job_budget())
	for t in tiles:
		if n >= cap:
			break
		if JobManager.has_job_at(t):
			continue
		var feat2: int = _world.data.get_feature(t.x, t.y)
		var species_bootstrap: int = Animal.Type.DEER if feat2 == TileFeature.Type.DEER else Animal.Type.RABBIT
		var live_now_bootstrap: int = int(live_bootstrap.get(species_bootstrap, 0))
		if live_now_bootstrap <= _hunt_reserve_for_species(species_bootstrap):
			continue
		if _can_post_job_at(t):
			var hj_boot: Job = JobManager.post(Job.Type.HUNT, t, HUNT_PRIORITY, _hunt_ticks_for(feat2))
			if hj_boot != null:
				_set_job_post_cooldown(t)
				live_bootstrap[species_bootstrap] = maxi(0, live_now_bootstrap - 1)
				n += 1
		else:
			_jobs_suppressed_this_session += 1
			if GameManager != null and GameManager.verbose_logs():
				var expiry_bs: int = int(_job_post_cooldowns.get(_tile_job_key(t), 0))
				var rem_bs: int = expiry_bs - GameManager.tick_count
				print("[JobCooldown] Suppressed %s at tile %s (cooldown remaining: %d)" % [Job.describe_type(Job.Type.HUNT), t, rem_bs])


## Post hunting jobs for live animals (called each tick to keep jobs in sync with moving animals).
func _post_hunting_jobs_for_animals() -> void:
	if (
			Main._world_stabilization_until_tick < 0
			or GameManager.tick_count < Main._world_stabilization_until_tick
	):
		return
	if _animal_spawner == null or _animal_spawner.animals.is_empty():
		return
	if not _should_post_more_hunt_jobs():
		return

	var main_component: int = _world.pathfinder.largest_component_id()
	_refresh_hunt_candidate_index(main_component)
	if _hunt_candidate_tiles.is_empty():
		return
	var hunt_budget: int = _dynamic_hunt_job_budget(_hunt_live_total_cache)
	var hunt_jobs_posted: int = 0
	var live_by_species: Dictionary = {}
	for k in _hunt_live_counts_cache:
		live_by_species[k] = _hunt_live_counts_cache[k]
	var scan_limit: int = maxi(HUNT_CANDIDATE_SCAN_LIMIT_MIN, hunt_budget * 4)
	var scanned: int = 0
	while (
			hunt_jobs_posted < hunt_budget
			and scanned < scan_limit
			and not _hunt_candidate_tiles.is_empty()
	):
		if _hunt_candidate_cursor >= _hunt_candidate_tiles.size():
			_hunt_candidate_cursor = 0
		var tile: Vector2i = _hunt_candidate_tiles[_hunt_candidate_cursor]
		_hunt_candidate_cursor += 1
		scanned += 1
		if not _world.data.in_bounds(tile.x, tile.y):
			continue
		if _world.pathfinder.component_of(tile) != main_component:
			continue
		if JobManager.has_job_at(tile):
			continue
		var feat: int = _world.data.get_feature(tile.x, tile.y)
		if not TileFeature.is_wildlife(feat):
			continue
		var species: int = Animal.Type.DEER if feat == TileFeature.Type.DEER else Animal.Type.RABBIT
		var live_now: int = int(live_by_species.get(species, 0))
		if live_now <= _hunt_reserve_for_species(species):
			continue
		var work_ticks: int = HUNT_RABBIT_WORK_TICKS if species == Animal.Type.RABBIT else HUNT_DEER_WORK_TICKS
		if _can_post_job_at(tile):
			var hj2: Job = JobManager.post(Job.Type.HUNT, tile, HUNT_PRIORITY, work_ticks)
			if hj2 != null:
				_set_job_post_cooldown(tile)
				hunt_jobs_posted += 1
				live_by_species[species] = maxi(0, live_now - 1)
		else:
			_jobs_suppressed_this_session += 1
			if GameManager != null and GameManager.verbose_logs():
				var expiry_ha: int = int(_job_post_cooldowns.get(_tile_job_key(tile), 0))
				var rem_ha: int = expiry_ha - GameManager.tick_count
				print("[JobCooldown] Suppressed %s at tile %s (cooldown remaining: %d)" % [Job.describe_type(Job.Type.HUNT), tile, rem_ha])


func _refresh_hunt_candidate_index(main_component: int) -> void:
	if _animal_spawner == null:
		_hunt_candidate_tiles.clear()
		_hunt_live_counts_cache = {}
		_hunt_live_total_cache = 0
		return
	var tick_now: int = GameManager.tick_count
	var should_refresh: bool = (
		_hunt_candidate_tiles.is_empty()
		or _hunt_candidate_last_refresh_tick < 0
		or tick_now - _hunt_candidate_last_refresh_tick >= HUNT_CANDIDATE_REFRESH_TICKS
		or _hunt_candidate_cursor >= _hunt_candidate_tiles.size()
	)
	if not should_refresh:
		return
	_hunt_candidate_tiles.clear()
	_hunt_candidate_cursor = 0
	_hunt_live_counts_cache = {
		int(Animal.Type.RABBIT): 0,
		int(Animal.Type.DEER): 0,
	}
	_hunt_live_total_cache = 0
	var seen_tiles: Dictionary = {}
	for animal in _animal_spawner.animals:
		if animal == null or not is_instance_valid(animal):
			continue
		var tile: Vector2i = animal.tile_pos
		if _world.pathfinder.component_of(tile) != main_component:
			continue
		var species: int = int(animal.animal_type)
		_hunt_live_counts_cache[species] = int(_hunt_live_counts_cache.get(species, 0)) + 1
		_hunt_live_total_cache += 1
		var tile_key: int = tile.y * WorldData.WIDTH + tile.x
		if seen_tiles.has(tile_key):
			continue
		seen_tiles[tile_key] = true
		_hunt_candidate_tiles.append(tile)
	_hunt_candidate_tiles.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return a.y * WorldData.WIDTH + a.x < b.y * WorldData.WIDTH + b.x
	)
	_hunt_candidate_last_refresh_tick = tick_now


## Same idea for regrowth: each species respawns on its own timer.
static func _regrow_ticks_for(feature: int) -> int:
	if feature == TileFeature.Type.DEER:
		return DEER_REGROW_TICKS
	return RABBIT_REGROW_TICKS


## Called whenever any job finishes. Rebuilds the picture of what's reachable
## now (mining can unlock sealed ore) and queues regrowth for harvested
## renewable resources.
func _on_job_completed(job: Job) -> void:
	if job == null:
		return
	var now_tick: int = GameManager.tick_count
	var job_type: int = int(job.type)
	var worker_id: int = -1
	var worker_name: String = ""
	var assigned_pawn: Node = null
	if job.assigned_pawn != null and is_instance_valid(job.assigned_pawn) and job.assigned_pawn.data != null:
		assigned_pawn = job.assigned_pawn
		worker_id = int(job.assigned_pawn.data.id)
		worker_name = String(job.assigned_pawn.data.display_name)
	var is_build_job: bool = (
		job_type == Job.Type.BUILD_BED
		or job_type == Job.Type.BUILD_WALL
		or job_type == Job.Type.BUILD_DOOR
		or job_type == Job.Type.BUILD_FIRE_PIT
		or job_type == Job.Type.BUILD_STORAGE_HUT
		or job_type == Job.Type.BUILD_MARKER_STONE
		or job_type == Job.Type.BUILD_SHRINE
		or job_type == Job.Type.BUILD_SHELTER
		or job_type == Job.Type.BUILD_HEARTH
	)
	# Nearby-worker counting is only used for build/co-op lore events.
	# Avoid full pawn scans for every labor completion.
	var nearby_workers: int = 1 if worker_id >= 0 else 0
	if is_build_job and _pawn_spawner != null:
		for p in _pawn_spawner.pawns:
			if p == assigned_pawn:
				continue
			if p == null or not is_instance_valid(p) or p.data == null:
				continue
			if job.tile.distance_to(p.data.tile_pos) <= 2.5:
				nearby_workers += 1
				if nearby_workers >= 2:
					break
	var region_key: int = _WM._region_key(job.tile.x, job.tile.y)
	WorldMemory.record_event({
		"type": "job_completed",
		"category": "labor",
		"severity": 1,
		"tick": now_tick,
		"job_type": job_type,
		"job_priority": int(job.priority),
		"worker_id": worker_id,
		"worker_name": worker_name,
		"nearby_workers": nearby_workers,
		"region": region_key,
		"tile": {"x": job.tile.x, "y": job.tile.y},
		"s": WorldMemory.SCHEMA,
	})
	match job.type:
		Job.Type.BUILD_BED, Job.Type.BUILD_WALL, Job.Type.BUILD_DOOR, \
		Job.Type.BUILD_FIRE_PIT, Job.Type.BUILD_STORAGE_HUT, \
		Job.Type.BUILD_MARKER_STONE, Job.Type.BUILD_SHRINE, \
		Job.Type.BUILD_SHELTER, Job.Type.BUILD_HEARTH:
			if has_node("WorldTrace") and _world != null:
				var wt: WorldTrace = $WorldTrace as WorldTrace
				if wt != null:
					wt.record_trace(_world.tile_to_world(job.tile), "build")
			# Get settlement context for the build event
			var settlement_name: String = ""
			var housing_pressure: float = 0.0
			var settlement_id: int = SettlementMemory.get_center_region_for_region(region_key)
			if settlement_id >= 0:
				var sd: Variant = SettlementMemory.get_settlement_at_region(region_key)
				if sd != null and sd is Dictionary:
					settlement_name = str((sd as Dictionary).get("name", (sd as Dictionary).get("intent", "")))
				# Housing pressure: ratio of population to beds
				var local_pop: int = 0
				var bed_count: int = 0
				if _pawn_spawner != null:
					for p in _pawn_spawner.pawns:
						if p != null and is_instance_valid(p) and p.data != null:
							var pt: Vector2i = p.data.tile_pos
							if abs(pt.x - job.tile.x) <= 24 and abs(pt.y - job.tile.y) <= 24:
								local_pop += 1
				var feats: Dictionary = HeelKawnianManager._scan_local_features(job.tile, 12)
				bed_count = int(feats.get("bed", 0))
				if local_pop > 0:
					housing_pressure = clampf(float(local_pop) / maxf(1.0, float(bed_count)), 0.0, 10.0)
			WorldMemory.record_event({
				"type": "structure_built",
				"category": "construction",
				"severity": 2,
				"tick": now_tick,
				"job_type": job_type,
				"worker_id": worker_id,
				"worker_name": worker_name,
				"nearby_workers": nearby_workers,
				"region": region_key,
				"tile": {"x": job.tile.x, "y": job.tile.y},
				"settlement": settlement_name,
				"housing_pressure": housing_pressure,
			})
			if nearby_workers >= 2:
				WorldMemory.record_event({
					"type": "cooperative_build",
					"category": "construction",
					"severity": 2,
					"tick": now_tick,
					"job_type": job_type,
					"worker_id": worker_id,
					"worker_name": worker_name,
					"nearby_workers": nearby_workers,
					"region": region_key,
					"tile": {"x": job.tile.x, "y": job.tile.y},
					"settlement": settlement_name,
					"housing_pressure": housing_pressure,
				})
		Job.Type.MINE, Job.Type.MINE_WALL:
			_mining_react_pending = true
			_invalidate_tunnel_frontier_cache()
		Job.Type.FORAGE:
			_queue_regrowth(job.tile, TileFeature.Type.FERTILE_SOIL, FORAGE_REGROW_TICKS)
		Job.Type.CHOP:
			_queue_regrowth(job.tile, TileFeature.Type.TREE, TREE_REGROW_TICKS)
		Job.Type.HUNT:
			# By the time we get here HeelKawnian._complete_current_job has already
			# cleared the feature, so we can't read the species off the tile
			# anymore. We use the job's planned work_ticks_needed as a proxy:
			# deer hunts are scheduled longer than rabbit hunts, so >= the
			# deer threshold means it was a deer. Cheap, robust, and good
			# enough until we add explicit per-job metadata.
			var species: int = TileFeature.Type.DEER \
				if job.work_ticks_needed >= HUNT_DEER_WORK_TICKS \
				else TileFeature.Type.RABBIT
			_queue_regrowth(job.tile, species, _regrow_ticks_for(species))
		Job.Type.FISH:
			# RIVER tiles persist, cooldown prevents over-fishing
			_set_job_post_cooldown(job.tile, FISH_COOLDOWN_TICKS)
			pass


# ==================== flood events ====================

## Tick flood events: during rain, rivers can overflow onto adjacent tiles.
## Flood deposits boost fertility temporarily and fade when dry.
## Runs every 200 ticks to avoid per-tick cost.
var _flood_scan_count: int = 0

func _tick_flood_events(tick: int) -> void:
	if _world == null or _world.data == null:
		return
	var wd = _world.data
	var is_raining: bool = _weather_overlay != null and _weather_overlay._current_weather == "rain"
	var is_dry: bool = _weather_overlay != null and _weather_overlay._current_weather == "none"
	
	# During rain: scan a limited number of river tiles for flood deposit
	if is_raining:
		# Only process a few tiles per tick to spread cost
		var scan_budget: int = 20
		var scanned: int = 0
		for y in range(WorldData.HEIGHT):
			for x in range(WorldData.WIDTH):
				if scanned >= scan_budget:
					break
				var tile: Vector2i = Vector2i(x, y)
				# Deterministic offset so different tiles get scanned each call
				var check_x: int = (x + _flood_scan_count) % WorldData.WIDTH
				var check_y: int = (y + int(_flood_scan_count / WorldData.WIDTH)) % WorldData.HEIGHT
				if wd.get_feature(check_x, check_y) == TileFeature.Type.RIVER:
					# Flood adjacent fertile tiles
					for dx in [-1, 0, 1]:
						for dy in [-1, 0, 1]:
							if dx == 0 and dy == 0:
								continue
							var nx: int = check_x + dx
							var ny: int = check_y + dy
							if not wd.in_bounds(nx, ny):
								continue
							# Only flood empty passable tiles (not buildings)
							var nidx: int = wd.index(nx, ny)
							if wd.features[nidx] == TileFeature.Type.NONE:
								if wd.is_passable(nx, ny):
									wd.features[nidx] = TileFeature.Type.FLOOD_DEPOSIT
									scanned += 1
									if scanned >= scan_budget:
										break
					if scanned >= scan_budget:
						break
			if scanned >= scan_budget:
				break
		_flood_scan_count = (_flood_scan_count + 1) % 256
	else:
		# Dry weather: gradually fade flood deposits
		var fade_budget: int = 10
		for y in range(WorldData.HEIGHT):
			for x in range(WorldData.WIDTH):
				if fade_budget <= 0:
					break
				if wd.get_feature(x, y) == TileFeature.Type.FLOOD_DEPOSIT:
					wd.features[wd.index(x, y)] = TileFeature.Type.NONE
					fade_budget -= 1


# ==================== regrowth ====================

func _queue_regrowth(tile: Vector2i, feature: int, delay_ticks: int) -> void:
	var entry: Dictionary = {
		"tile": tile,
		"feature": feature,
		"ready_tick": GameManager.tick_count + delay_ticks,
	}
	_regrow_add_entry(entry)


## Walk due-tick regrowth buckets and resurrect any feature whose timer has expired.
## Uses due-tick buckets + fixed restore budgets to prevent one-tick spikes.
func _process_regrowth(tick: int) -> void:
	if _regrow_due_ticks.is_empty():
		return
	var restore_budget: int = REGROWTH_RESTORE_BUDGET_PER_TICK
	if GameManager != null:
		var gs: float = GameManager.game_speed
		if gs >= 100.0:
			restore_budget = 1
		elif gs >= 50.0:
			restore_budget = 2
	var main_component: int = _world.pathfinder.largest_component_id()
	var restored: int = 0
	while restored < restore_budget and not _regrow_due_ticks.is_empty():
		var due_tick: int = int(_regrow_due_ticks[0])
		if due_tick > tick:
			break
		var bucket: Array = _regrow_due_buckets.get(due_tick, [])
		_regrow_due_buckets.erase(due_tick)
		_regrow_due_ticks.remove_at(0)
		for entry_any in bucket:
			if restored >= restore_budget:
				_regrow_add_entry(entry_any as Dictionary)
				continue
			if entry_any is not Dictionary:
				continue
			var entry: Dictionary = entry_any as Dictionary
			_restore_feature(entry.tile, entry.feature, main_component)
			restored += 1
func _regrow_add_entry(entry: Dictionary) -> void:
	var due_tick: int = int(entry.get("ready_tick", 0))
	var bucket: Array = _regrow_due_buckets.get(due_tick, [])
	if bucket.is_empty():
		var insert_idx: int = 0
		while insert_idx < _regrow_due_ticks.size() and int(_regrow_due_ticks[insert_idx]) < due_tick:
			insert_idx += 1
		_regrow_due_ticks.insert(insert_idx, due_tick)
	bucket.append(entry)
	_regrow_due_buckets[due_tick] = bucket


## Re-place a feature on its original tile, then post the matching job so a
## pawn will harvest it again. Skips silently if the tile is no longer a
## valid host (something else built there, biome was mined out, etc.).
func _restore_feature(tile: Vector2i, feature: int, main_component: int = -1) -> void:
	if not _world.data.in_bounds(tile.x, tile.y):
		return
	# Tile already has something else? Drop the regrowth -- player intent
	# wins (e.g. a future bed sitting on this spot).
	if _world.data.get_feature(tile.x, tile.y) != TileFeature.Type.NONE:
		return
	# Validate biome compatibility -- e.g. trees need plains/forest, fertile
	# soil also needs plains/forest. If the biome was mined out (mountain ->
	# stone floor) we just drop the regrowth.
	var biome: int = _world.data.get_biome(tile.x, tile.y)
	if not _is_biome_compatible(feature, biome):
		return
	if not _world.set_feature(tile.x, tile.y, feature):
		return
	# Repost the matching harvest job, but only if the tile is reachable.
	if main_component < 0:
		main_component = _world.pathfinder.largest_component_id()
	if _world.pathfinder.component_of(tile) != main_component:
		return
	if JobManager.has_job_at(tile):
		return
	match feature:
		TileFeature.Type.FERTILE_SOIL:
			if _can_post_job_at(tile):
				var rfj: Job = JobManager.post(Job.Type.FORAGE, tile, FORAGE_PRIORITY, FORAGE_WORK_TICKS)
				if rfj != null:
					_set_job_post_cooldown(tile)
			else:
				_jobs_suppressed_this_session += 1
				if GameManager != null and GameManager.verbose_logs():
					var expiry_rgf: int = int(_job_post_cooldowns.get(_tile_job_key(tile), 0))
					var rem_rgf: int = expiry_rgf - GameManager.tick_count
					print("[JobCooldown] Suppressed %s at tile %s (cooldown remaining: %d)" % [Job.describe_type(Job.Type.FORAGE), tile, rem_rgf])
		TileFeature.Type.TREE:
			if _can_post_job_at(tile):
				var rcj: Job = JobManager.post(Job.Type.CHOP, tile, CHOP_PRIORITY, CHOP_WORK_TICKS)
				if rcj != null:
					_set_job_post_cooldown(tile)
			else:
				_jobs_suppressed_this_session += 1
				if GameManager != null and GameManager.verbose_logs():
					var expiry_rgc: int = int(_job_post_cooldowns.get(_tile_job_key(tile), 0))
					var rem_rgc: int = expiry_rgc - GameManager.tick_count
					print("[JobCooldown] Suppressed %s at tile %s (cooldown remaining: %d)" % [Job.describe_type(Job.Type.CHOP), tile, rem_rgc])
		TileFeature.Type.RABBIT, TileFeature.Type.DEER:
			if (
					Main._world_stabilization_until_tick >= 0
					and GameManager.tick_count < Main._world_stabilization_until_tick
			):
				return
			if _can_post_job_at(tile):
				var rhj: Job = JobManager.post(Job.Type.HUNT, tile, HUNT_PRIORITY, _hunt_ticks_for(feature))
				if rhj != null:
					_set_job_post_cooldown(tile)
			else:
				_jobs_suppressed_this_session += 1
				if GameManager != null and GameManager.verbose_logs():
					var expiry_rgh: int = int(_job_post_cooldowns.get(_tile_job_key(tile), 0))
					var rem_rgh: int = expiry_rgh - GameManager.tick_count
					print("[JobCooldown] Suppressed %s at tile %s (cooldown remaining: %d)" % [Job.describe_type(Job.Type.HUNT), tile, rem_rgh])


static func _is_biome_compatible(feature: int, biome: int) -> bool:
	match feature:
		TileFeature.Type.FERTILE_SOIL:
			return biome == Biome.Type.PLAINS or biome == Biome.Type.FOREST
		TileFeature.Type.TREE:
			return biome == Biome.Type.PLAINS or biome == Biome.Type.FOREST
		TileFeature.Type.RABBIT, TileFeature.Type.DEER:
			return biome == Biome.Type.PLAINS or biome == Biome.Type.FOREST
	return false


## Re-seed jobs reactively after the map's reachability has changed (something
## was mined out). Two responsibilities:
##   1. Any ORE_VEIN that is now reachable but has no job -> post a MINE job.
##   2. If we have headroom, post one more MINE_WALL aimed at the closest
##      still-sealed ore vein, so colonies autonomously dig toward resources.
func _react_to_mining_progress_step() -> bool:
	# OPTIMIZATION: Check frame budget at entry
	var mining_start: int = Time.get_ticks_usec()
	const MINING_BUDGET_USEC: int = 2_000  # 2ms budget for mining react
	
	var pf: PathFinder = _world.pathfinder
	var main_component: int = pf.largest_component_id()
	if main_component < 0:
		_mining_react_in_progress = false
		_mining_react_scan_y_cursor = 0
		_mining_react_newly_minable_accum = 0
		return true

	# 1. Newly-reachable ore -> MINE jobs.
	if not _mining_react_in_progress:
		_mining_react_in_progress = true
		_mining_react_scan_y_cursor = 0
		_mining_react_newly_minable_accum = 0
		_mining_react_work_used = 0
	var y_start: int = _mining_react_scan_y_cursor
	var rows_step: int = _mining_react_scan_rows_for_speed()
	var work_budget_max: int = _mining_react_budget_for_speed()
	_mining_react_work_used = 0
	var y_end: int = mini(WorldData.HEIGHT, y_start + rows_step)
	for y in range(y_start, y_end):
		for x in range(WorldData.WIDTH):
			# OPTIMIZATION: Check frame budget every 32 tiles
			if _mining_react_work_used % 32 == 0:
				if Time.get_ticks_usec() - mining_start > MINING_BUDGET_USEC:
					_mining_react_in_progress = true
					_mining_react_scan_y_cursor = y
					return false  # Defer rest to next tick

			# Budgeting: count a cheap unit per tile checked. If we exceed
			# the per-tick budget, pause the scan and continue next tick.
			_mining_react_work_used += 1
			if _mining_react_work_used > work_budget_max:
				_mining_react_in_progress = true
				_mining_react_scan_y_cursor = y
				return false
			var f: int = _world.data.get_feature(x, y)
			if f != TileFeature.Type.ORE_VEIN:
				continue
			var ore_tile := Vector2i(x, y)
			if JobManager.has_job_at(ore_tile):
				continue
			# find_adjacent_passable is expensive — check budget after each call
			var work_tile: Vector2i = pf.find_adjacent_passable(ore_tile)
			if Time.get_ticks_usec() - mining_start > MINING_BUDGET_USEC:
				_mining_react_in_progress = true
				_mining_react_scan_y_cursor = y
				return false
			if work_tile.x < 0 or pf.component_of(work_tile) != main_component:
				continue
			if not _can_post_job_at(ore_tile):
				_jobs_suppressed_this_session += 1
				if GameManager != null and GameManager.verbose_logs():
					var expiry_mr: int = int(_job_post_cooldowns.get(_tile_job_key(ore_tile), 0))
					var rem_mr: int = expiry_mr - GameManager.tick_count
					print("[JobCooldown] Suppressed %s at tile %s (cooldown remaining: %d)" % [Job.describe_type(Job.Type.MINE), ore_tile, rem_mr])
				continue
			var job: Job = JobManager.post(Job.Type.MINE, ore_tile, MINE_PRIORITY, MINE_WORK_TICKS)
			if job == null:
				continue
			job.work_tile = work_tile
			_set_job_post_cooldown(ore_tile)
			_mining_react_newly_minable_accum += 1
	_mining_react_scan_y_cursor = y_end
	if _mining_react_scan_y_cursor < WorldData.HEIGHT:
		return false

	# 2. Top up MINE_WALL jobs up to the cap. Post at most one per step to keep
	# BFS tunnel targeting from monopolizing the frame.
	var active_walls: int = JobManager.active_count_of_type(Job.Type.MINE_WALL)
	var posted_walls: int = 0
	if active_walls < MAX_ACTIVE_MINE_WALL_JOBS:
		var wall_tile: Vector2i = _find_next_tunnel_target_cached(main_component)
		if wall_tile.x >= 0:
			# OPTIMIZATION: Check frame budget before expensive BFS
			if Time.get_ticks_usec() - mining_start > MINING_BUDGET_USEC:
				_mining_react_in_progress = true
				return false  # Defer wall posting to next tick
			
			# work_tile = a passable main-component neighbor of the wall tile.
			var work_tile: Vector2i = _find_main_component_neighbor(wall_tile, main_component)
			if work_tile.x >= 0:
				if _can_post_job_at(wall_tile):
					var job: Job = JobManager.post(Job.Type.MINE_WALL, wall_tile, MINE_WALL_PRIORITY, MINE_WALL_WORK_TICKS)
					if job != null:
						job.work_tile = work_tile
						_set_job_post_cooldown(wall_tile)
						active_walls += 1
						posted_walls = 1
				else:
					_jobs_suppressed_this_session += 1
					if GameManager != null and GameManager.verbose_logs():
						var expiry_mw: int = int(_job_post_cooldowns.get(_tile_job_key(wall_tile), 0))
						var rem_mw: int = expiry_mw - GameManager.tick_count
						print("[JobCooldown] Suppressed %s at tile %s (cooldown remaining: %d)" % [Job.describe_type(Job.Type.MINE_WALL), wall_tile, rem_mw])

	if _mining_react_newly_minable_accum > 0 or posted_walls > 0:
		if OS.is_debug_build():
			print(
					"[Main] React: +%d MINE  +%d MINE_WALL  (active walls=%d)" % [
						_mining_react_newly_minable_accum, posted_walls, active_walls
					]
			)
	_mining_react_in_progress = false
	_mining_react_scan_y_cursor = 0
	_mining_react_newly_minable_accum = 0
	_mining_react_work_used = 0
	return true


func _mining_react_budget_for_speed() -> int:
	var row_safe_minimum: int = WorldData.WIDTH + 1
	if GameManager == null:
		return maxi(row_safe_minimum, MINING_REACT_WORK_BUDGET_PER_TICK)
	var gs: float = GameManager.game_speed
	if gs >= 26.0:
		return 64  # ~1/4 row at high speed — keeps frame budget
	if gs >= 12.0:
		return 128
	if gs >= 3.0:
		return 256
	return maxi(row_safe_minimum, MINING_REACT_WORK_BUDGET_PER_TICK)


## At high speed, skip N ticks between mining react steps to spread load.
func _mining_react_step_skip_for_speed() -> int:
	if GameManager == null:
		return 0
	var gs: float = GameManager.game_speed
	if gs >= 100.0:
		return 3  # Run every 4th tick
	if gs >= 50.0:
		return 2  # Run every 3rd tick
	if gs >= 26.0:
		return 1  # Run every 2nd tick
	return 0  # Run every tick at normal speed


## Full react pass (legacy callers). Tick loop should prefer `_react_to_mining_progress_step`.
## Bootstrap must not spin unbounded: one bad state in the scanner would hard-freeze the game.
func _react_to_mining_progress() -> void:
	var guard: int = 0
	const MAX_BOOTSTRAP_MINING_REACT_LOOPS: int = 8192
	while not _react_to_mining_progress_step():
		guard += 1
		if guard >= MAX_BOOTSTRAP_MINING_REACT_LOOPS:
			print(
					"[Main][WARN] _react_to_mining_progress: bootstrap step cap (%d) — continuing on future ticks"
					% MAX_BOOTSTRAP_MINING_REACT_LOOPS
			)
			break


## Multi-source BFS starting from every still-sealed ORE_VEIN, expanding only
## through MOUNTAIN tiles. The first time the frontier touches a tile in
## main_component we know the previous (mountain) tile is the wall to mine
## next. Returns Vector2i(-1,-1) if there are no sealed ores or none can be
## tunneled to.
func _find_next_tunnel_target_cached(main_component: int) -> Vector2i:
	var tick_now: int = GameManager.tick_count
	var refresh_needed: bool = (
		_tunnel_frontier_cache.is_empty()
		or _tunnel_frontier_cache_component != main_component
		or _tunnel_frontier_cache_cursor >= _tunnel_frontier_cache.size()
		or _tunnel_frontier_cache_built_tick < 0
		or tick_now - _tunnel_frontier_cache_built_tick >= TUNNEL_FRONTIER_CACHE_REFRESH_TICKS
	)
	if refresh_needed:
		_rebuild_tunnel_frontier_cache(main_component)
	while _tunnel_frontier_cache_cursor < _tunnel_frontier_cache.size():
		var candidate: Vector2i = _tunnel_frontier_cache[_tunnel_frontier_cache_cursor]
		_tunnel_frontier_cache_cursor += 1
		if JobManager.has_job_at(candidate):
			continue
		var biome: int = _world.data.get_biome(candidate.x, candidate.y)
		if biome != Biome.Type.MOUNTAIN:
			continue
		if _find_main_component_neighbor(candidate, main_component).x < 0:
			continue
		return candidate
	return Vector2i(-1, -1)


func _rebuild_tunnel_frontier_cache(main_component: int) -> void:
	_tunnel_frontier_cache.clear()
	_tunnel_frontier_cache_cursor = 0
	_tunnel_frontier_cache_component = main_component
	_tunnel_frontier_cache_built_tick = GameManager.tick_count
	var pf: PathFinder = _world.pathfinder
	var width: int = WorldData.WIDTH
	var height: int = WorldData.HEIGHT
	var visited: PackedByteArray = PackedByteArray()
	visited.resize(WorldData.TILE_COUNT)
	var queue: Array[Vector2i] = []
	var rebuild_start: int = Time.get_ticks_usec()
	const REBUILD_BUDGET_USEC: int = 2_000  # 2ms max for cache rebuild
	for y in range(height):
		for x in range(width):
			# Budget check: don't let cache rebuild monopolize the frame
			if (y * width + x) % 2048 == 0:
				if Time.get_ticks_usec() - rebuild_start > REBUILD_BUDGET_USEC:
					_tunnel_frontier_cache_built_tick = GameManager.tick_count
					return  # Partial rebuild — will retry next refresh
			var idx: int = y * width + x
			if _world.data.features[idx] != TileFeature.Type.ORE_VEIN:
				continue
			var t := Vector2i(x, y)
			if JobManager.has_job_at(t):
				continue
			var adj: Vector2i = pf.find_adjacent_passable(t)
			if adj.x >= 0 and pf.component_of(adj) == main_component:
				continue
			queue.append(t)
			visited[idx] = 1
	if queue.is_empty():
		return
	var found: Dictionary = {}
	var head: int = 0
	var offsets := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while head < queue.size() and _tunnel_frontier_cache.size() < TUNNEL_FRONTIER_CACHE_MAX_TARGETS:
		var t: Vector2i = queue[head]
		head += 1
		for off in offsets:
			var n: Vector2i = t + off
			if n.x < 0 or n.x >= width or n.y < 0 or n.y >= height:
				continue
			var ni: int = n.y * width + n.x
			if visited[ni] != 0:
				continue
			var nbiome: int = _world.data.biomes[ni]
			if nbiome == Biome.Type.MOUNTAIN:
				visited[ni] = 1
				queue.append(n)
				continue
			if Biome.is_passable(nbiome) and pf.component_of(n) == main_component:
				var key: int = t.y * width + t.x
				if not found.has(key) and not JobManager.has_job_at(t):
					found[key] = true
					_tunnel_frontier_cache.append(t)
				visited[ni] = 1
			else:
				visited[ni] = 1


func _invalidate_tunnel_frontier_cache() -> void:
	_tunnel_frontier_cache.clear()
	_tunnel_frontier_cache_cursor = 0
	_tunnel_frontier_cache_component = -1
	_tunnel_frontier_cache_built_tick = -1


func _find_next_tunnel_target(main_component: int) -> Vector2i:
	var pf: PathFinder = _world.pathfinder
	var width: int = WorldData.WIDTH
	var height: int = WorldData.HEIGHT
	var visited: PackedByteArray = PackedByteArray()
	visited.resize(WorldData.TILE_COUNT)
	var queue: Array[Vector2i] = []

	# Seed the BFS with every ore vein that doesn't already have a passable
	# main-component neighbor. Those without an adjacent floor are the ones we
	# need to tunnel to. Skip ores that already have a job posted at their
	# tile (otherwise we'd queue redundant tunnels toward them).
	for y in range(height):
		for x in range(width):
			var i: int = y * width + x
			if _world.data.features[i] != TileFeature.Type.ORE_VEIN:
				continue
			var t := Vector2i(x, y)
			if JobManager.has_job_at(t):
				continue
			var adj: Vector2i = pf.find_adjacent_passable(t)
			if adj.x >= 0 and pf.component_of(adj) == main_component:
				continue  # already mineable; not a tunnel target
			queue.append(t)
			visited[i] = 1

	if queue.is_empty():
		return Vector2i(-1, -1)

	var head: int = 0
	var offsets := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while head < queue.size():
		var t: Vector2i = queue[head]
		head += 1
		for off in offsets:
			var n: Vector2i = t + off
			if n.x < 0 or n.x >= width or n.y < 0 or n.y >= height:
				continue
			var ni: int = n.y * width + n.x
			if visited[ni] != 0:
				continue
			var nbiome: int = _world.data.biomes[ni]
			if nbiome == Biome.Type.MOUNTAIN:
				visited[ni] = 1
				queue.append(n)
			elif Biome.is_passable(nbiome) and pf.component_of(n) == main_component:
				# Frontier touched the colony. `t` is a mountain tile bordering
				# main_component along the shortest tunnel from the closest ore.
				# But: skip if a job is already pending on `t`, and try the
				# next BFS step instead by marking visited and continuing.
				if JobManager.has_job_at(t):
					visited[ni] = 1  # don't re-discover from this side
					continue
				return t
			else:
				visited[ni] = 1  # water / wrong component / etc; don't expand
	return Vector2i(-1, -1)


## Find any 4-way passable neighbor of `tile` that belongs to `main_component`.
## Used to choose the standing tile for a MINE_WALL job. Returns (-1,-1) if
## none exists (which means the tunnel target wasn't actually on the frontier).
func _find_main_component_neighbor(tile: Vector2i, main_component: int) -> Vector2i:
	var pf: PathFinder = _world.pathfinder
	for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = tile + off
		if not _world.data.in_bounds(n.x, n.y):
			continue
		if not pf.is_passable(n):
			continue
		if pf.component_of(n) == main_component:
			return n
	return Vector2i(-1, -1)


# ==================== beds (player designation) ====================

## Hotkey B: stamp BEDS_PER_DESIGNATION new BUILD_BED jobs on the closest
## passable empty tiles to the stockpile. Skips tiles already occupied by
## the stockpile itself, an existing feature, an active job, or a bed we
## already built. Cheap O(R^2) scan -- R defaults to 6.
func _designate_beds_near_stockpile() -> void:
	if _world == null or _world.stockpile == null:
		if OS.is_debug_build():
			print("[Main] Can't designate beds: no stockpile yet.")
		return
	var center: Vector2i = _world.stockpile.tile
	var main_component: int = _world.pathfinder.largest_component_id()
	# Collect candidate tiles, sorted by Chebyshev distance from the stockpile
	# so the first beds land in the closest slots.
	var candidates: Array = []
	for dy in range(-BED_SCAN_RADIUS, BED_SCAN_RADIUS + 1):
		for dx in range(-BED_SCAN_RADIUS, BED_SCAN_RADIUS + 1):
			if dx == 0 and dy == 0:
				continue
			var t := Vector2i(center.x + dx, center.y + dy)
			if not _is_valid_bed_site(t, main_component):
				continue
			candidates.append({"tile": t, "d": max(abs(dx), abs(dy))})
	candidates.sort_custom(func(a, b): return a.d < b.d)

	var posted: int = 0
	for c in candidates:
		if posted >= BEDS_PER_DESIGNATION:
			break
		var job: Job = JobManager.post(Job.Type.BUILD_BED, c.tile,
			BUILD_BED_PRIORITY, BUILD_BED_WORK_TICKS)
		if job == null:
			continue
		posted += 1
	if posted == 0:
		if OS.is_debug_build():
			print(
					"[Main] B: no eligible bed sites within %d tiles of the stockpile." %
					BED_SCAN_RADIUS
			)
	else:
		if OS.is_debug_build():
			print(
					"[Main] B: designated %d new bed site(s) near (%d,%d). Pawns will fetch wood (%d each) and build." %
					[posted, center.x, center.y, HeelKawnian.BED_WOOD_COST]
			)


func _is_valid_bed_site(t: Vector2i, main_component: int) -> bool:
	if not _world.data.in_bounds(t.x, t.y):
		return false
	# Don't plant a bed inside any stockpile zone; you wouldn't build a bunk
	# in the middle of the pantry. Scans every zone, but N is small so this
	# stays cheap.
	for z in StockpileManager.zones():
		if z.contains_tile(t):
			return false
	if not _world.pathfinder.is_passable(t):
		return false
	if _world.pathfinder.component_of(t) != main_component:
		return false
	if _world.data.get_feature(t.x, t.y) != TileFeature.Type.NONE:
		return false
	if JobManager.has_job_at(t):
		return false
	return true


# -------------------- settlement planner (autonomous build v1) --------------------

func settlement_planner_count_pawns_in_regions(regions: PackedInt32Array) -> int:
	var want: Dictionary = {}
	for j in range(regions.size()):
		want[int(regions[j])] = true
	var n: int = 0
	if _pawn_spawner == null:
		return 0
	for p in _pawn_spawner.pawns:
		if p == null or not is_instance_valid(p) or not p.has_method("get_pawn_data"):
			continue
		var pd: HeelKawnianData = p.get_pawn_data() as HeelKawnianData
		if pd == null:
			continue
		var rk: int = _WM._region_key(pd.tile_pos.x, pd.tile_pos.y)
		if want.has(rk):
			n += 1
	return n


func settlement_planner_is_valid_bed_site(t: Vector2i) -> bool:
	return _is_valid_bed_site(t, _world.pathfinder.largest_component_id())


func settlement_planner_is_valid_build_wall_site(t: Vector2i) -> bool:
	return _is_valid_build_site(t, _world.pathfinder.largest_component_id())


func settlement_planner_is_valid_door_site(t: Vector2i) -> bool:
	return _is_valid_door_site(t, _world.pathfinder.largest_component_id())


func settlement_planner_post_bed(t: Vector2i) -> bool:
	if not _is_valid_bed_site(t, _world.pathfinder.largest_component_id()):
		return false
	return JobManager.post(Job.Type.BUILD_BED, t, BUILD_BED_PRIORITY, BUILD_BED_WORK_TICKS) != null


func settlement_planner_post_wall(t: Vector2i) -> bool:
	var main_component: int = _world.pathfinder.largest_component_id()
	var work_tile: Vector2i = _find_main_component_neighbor(t, main_component)
	if work_tile.x < 0 or not _is_valid_build_site(t, main_component):
		return false
	var job: Job = JobManager.post(Job.Type.BUILD_WALL, t, BUILD_WALL_PRIORITY, BUILD_WALL_WORK_TICKS)
	if job == null:
		return false
	job.work_tile = work_tile
	_world.pathfinder.set_job_construction_reservation(t.x, t.y, true, _world.data)
	_world.kick_occupants_off_reserved_build_tile(t.x, t.y)
	_world.notify_pawns_nav_changed()
	return true


func settlement_planner_post_door(t: Vector2i) -> bool:
	var main_component2: int = _world.pathfinder.largest_component_id()
	if not _is_valid_door_site(t, main_component2):
		return false
	var fdoor: int = _world.data.get_feature(t.x, t.y)
	var wtd: Vector2i
	if fdoor == TileFeature.Type.WALL:
		wtd = _find_main_component_neighbor(t, main_component2)
		if wtd.x < 0:
			return false
	else:
		wtd = t
	var jdoor: Job = JobManager.post(Job.Type.BUILD_DOOR, t, BUILD_DOOR_PRIORITY, BUILD_DOOR_WORK_TICKS)
	if jdoor == null:
		return false
	jdoor.work_tile = wtd
	return true


func settlement_planner_post_zone_rect(rect: Rect2i) -> bool:
	if rect.size.x * rect.size.y > ZONE_MAX_AREA:
		return false
	if _count_passable_in_rect(rect) == 0:
		return false
	for dy in range(rect.size.y):
		for dx in range(rect.size.x):
			var t2 := Vector2i(rect.position.x + dx, rect.position.y + dy)
			for z in StockpileManager.zones():
				if z != null and is_instance_valid(z) and z.contains_tile(t2):
					return false
	var sp: Stockpile = STOCKPILE_SCENE.instantiate()
	sp.set_filter(Stockpile.Filter.ALL)
	sp.set_rect_tiles(rect)
	sp.position = _world.tile_to_world(rect.position)
	add_child(sp)
	StockpileManager.register(sp)
	return true


func settlement_planner_post_fire_pit(t: Vector2i) -> bool:
	if not _world.data.in_bounds(t.x, t.y):
		return false
	if _world.data.get_feature(t.x, t.y) != TileFeature.Type.NONE:
		return false
	if not _world.data.is_passable(t.x, t.y):
		return false
	if StockpileManager.total_count_of(Item.Type.WOOD) < 1:
		return false
	var job: Job = JobManager.post(Job.Type.BUILD_FIRE_PIT, t, 5, 35)
	return job != null


func settlement_planner_post_storage_hut(t: Vector2i) -> bool:
	if not _world.data.in_bounds(t.x, t.y):
		return false
	if _world.data.get_feature(t.x, t.y) != TileFeature.Type.NONE:
		return false
	if not _world.data.is_passable(t.x, t.y):
		return false
	if StockpileManager.total_count_of(Item.Type.WOOD) < 2:
		return false
	var job: Job = JobManager.post(Job.Type.BUILD_STORAGE_HUT, t, 5, 40)
	return job != null


func settlement_planner_post_protect(t: Vector2i) -> bool:
	if not _world.data.in_bounds(t.x, t.y):
		return false
	if not _world.data.is_passable(t.x, t.y):
		return false
	var job: Job = JobManager.post(Job.Type.PROTECT, t, 6, 60)
	return job != null


func settlement_planner_post_defend(t: Vector2i) -> bool:
	if not _world.data.in_bounds(t.x, t.y):
		return false
	if not _world.data.is_passable(t.x, t.y):
		return false
	var job: Job = JobManager.post(Job.Type.DEFEND, t, 7, 80)
	return job != null


## Generic job posting for Phase 6 buildings via BuildingRegistry.
## Posts a build job of any type at the given tile.
func settlement_planner_post_job(t: Vector2i, job_type: int) -> bool:
	if not _world.data.in_bounds(t.x, t.y):
		return false
	if not _world.data.is_passable(t.x, t.y):
		return false
	# Look up work ticks from BuildingRegistry
	var work_ticks: int = 30
	if BuildingRegistry != null:
		var building: Dictionary = BuildingRegistry.get_building_by_job_type(job_type)
		if not building.is_empty():
			work_ticks = int(building.get("work_ticks", 30))
	var job: Job = JobManager.post(job_type, t, 5, work_ticks)
	return job != null


func _print_stockpile() -> void:
	if not OS.is_debug_build():
		return
	var zones: Array[Stockpile] = StockpileManager.zones()
	if zones.is_empty():
		print("[Stockpile] (no zones)")
		return
	print("[Stockpile] %d zone(s):" % zones.size())
	for z in zones:
		var parts: Array[String] = []
		for it in z.inventory:
			parts.append("%s=%d" % [Item.name_for(it), z.inventory[it]])
		var inv_str: String = " ".join(parts) if not parts.is_empty() else "empty"
		print("  - %s @%s (%dx%d)  %s" % [
			Stockpile.FILTER_NAME.get(z.filter, "?"),
			z.rect.position, z.rect.size.x, z.rect.size.y, inv_str
		])


# ==================== save / load (F5 / F8) ====================
#
# Cross-session continuity (must survive save → quit → load): everything in
# `_build_save_dict()` / `_apply_save_dict`: sim identity (`GameManager.tick_count`,
# optional speed/pause when `RESTORE_SPEED_FROM_SAVE`), `last_generation_tick`,
# `WorldData` (terrain + `world_seed`), stockpile zones, pawn blobs, regrow queue,
# `WorldMemory`, bloodlines, `SettlementRegistry` + `SettlementMemory` (including
# persisted governance keys from `SettlementMemory.to_save_dict`), `WorldPersistence`,
# myth/sacred/chronicle/cultural memory, `PlayerIntentQueue`, `FactionRegistry`,
# and player mode / pawn binding.
#
# Verification here does **not** prove `_apply_save_dict` is bug-free; it proves the
# snapshot dict round-trips through the same binary encoding as `GameSave` (`store_var`
# / `get_var`, i.e. `var_to_bytes` / `bytes_to_var`). Call `verify_save_load_state()` from
# the editor Remote Inspector on the Main node when you need a quick encoding check without
# applying load (full F5→F8 smoke test remains manual in-editor).

func _colony_save() -> void:
	var snapshot: Dictionary = _build_save_dict()
	if OS.is_debug_build():
		if not verify_save_roundtrip(snapshot):
			push_warning(
					"[Main] Save encoding round-trip failed (var_to_bytes). File still written; investigate persistence."
			)
	var err: Error = GameSave.write_file(GameSave.get_save_path(), snapshot)
	if err == OK:
		_reset_job_cooldown_telemetry()
		if OS.is_debug_build():
			print("[Main] Saved colony -> %s" % GameSave.get_save_path())
	else:
		push_error("[Main] Save failed (code %d)" % err)


func _colony_load() -> void:
	var d: Dictionary = GameSave.read_file(GameSave.get_save_path())
	if d.is_empty():
		if OS.is_debug_build():
			print("[Main] No save at %s" % GameSave.get_save_path())
		return
	var save_v: int = int(d.get("v", 0))
	if save_v < 1 or save_v > GameSave.SAVE_VERSION:
		if OS.is_debug_build():
			print(
					"[Main] Save version mismatch: got v=%d, supported 1..%d" % [
						save_v, GameSave.SAVE_VERSION
					]
			)
		return
	_apply_save_dict(d)
	_reset_job_cooldown_telemetry()
	if OS.is_debug_build():
		print("[Main] Loaded colony from %s" % GameSave.get_save_path())


func _on_structure_type_selected(type: String) -> void:
	if PlayerBuilding == null:
		return
	
	# Mapping display types to DesignationMode if necessary, 
	# but player placement in HeelKawn follows a "Ghost Preview" pattern.
	# For now, we'll log it and set the mode to WALL or similar as a proxy.
	if OS.is_debug_build():
		print("[Main] Player selected structure: %s" % type)
	
	# If Foundation/Wall/Door, use existing modes
	match type:
		"foundation":
			_set_designation_mode(DesignationMode.BUILD_BED) # Proxy for foundation in v1
		"wall", "wall_wood", "wall_stone":
			_set_designation_mode(DesignationMode.BUILD_WALL)
		"door", "door_wood":
			_set_designation_mode(DesignationMode.BUILD_DOOR)
		_:
			# For other types, we might need a general "STAMP" mode in the future.
			pass


func _on_save_slot(slot: int) -> void:
	var snapshot: Dictionary = _build_save_dict()
	var err: Error = GameSave.write_file(GameSave.get_save_path(slot), snapshot)
	if err == OK:
		if OS.is_debug_build():
			print("[Main] Saved colony to slot %d -> %s" % [slot, GameSave.get_save_path(slot)])
	else:
		push_error("[Main] Save slot %d failed (code %d)" % [slot, err])


func _on_load_slot(slot: int) -> void:
	var d: Dictionary = GameSave.read_file(GameSave.get_save_path(slot))
	if d.is_empty():
		if OS.is_debug_build():
			print("[Main] No save at slot %d" % slot)
		return
	var save_v: int = int(d.get("v", 0))
	if save_v < 1 or save_v > GameSave.SAVE_VERSION:
		if OS.is_debug_build():
			print("[Main] Save version mismatch at slot %d: got v=%d, supported 1..%d" % [slot, save_v, GameSave.SAVE_VERSION])
		return
	_apply_save_dict(d)
	_reset_job_cooldown_telemetry()
	if OS.is_debug_build():
		print("[Main] Loaded colony from slot %d" % slot)


func _on_new_game() -> void:
	if _seed_gallery != null:
		_seed_gallery.show_gallery(WorldRNG.current_seed() if WorldRNG != null else 0)
		if _main_menu != null:
			_main_menu.hide_menu()
		return
	if OS.is_debug_build():
		_reroll_world()
	_set_player_mode(PlayerMode.OBSERVER)
	_update_hud_mode_badge()
	if _main_menu != null:
		_main_menu.hide_menu()


## "Play" button: start in spectator, then open incarnation picker
func _on_play_mode() -> void:
	if OS.is_debug_build():
		_reroll_world()
	_set_player_mode(PlayerMode.OBSERVER)
	_update_hud_mode_badge()
	if _main_menu != null:
		_main_menu.hide_menu()
	# Open incarnation picker after a short delay so the world is ready
	_open_incarnation_picker()


## "Observer" button: start directly in Observer mode (full command authority)
func _on_observer_mode_start() -> void:
	if OS.is_debug_build():
		_reroll_world()
	_set_player_mode(PlayerMode.OBSERVER)
	_update_hud_mode_badge()
	if _main_menu != null:
		_main_menu.hide_menu()


## Debug/editor: ensures `_build_save_dict()` survives `var_to_bytes` → `bytes_to_var` (same
## family as [member FileAccess.store_var]). Does not read disk and does not run `_apply_save_dict`.
## In running game: Remote Inspector → select [Main] → call [method verify_save_load_state].
func verify_save_load_state() -> bool:
	return verify_save_roundtrip(_build_save_dict())


## Returns true if `bytes_to_var(var_to_bytes(snapshot))` equals `snapshot` (same encoding path as
## [member FileAccess.store_var]). Used automatically on F5 in debug builds; safe to call from tooling while paused.
func verify_save_roundtrip(snapshot: Dictionary) -> bool:
	var enc: PackedByteArray = var_to_bytes(snapshot)
	var restored: Variant = bytes_to_var(enc)
	if not (restored is Dictionary):
		if OS.is_debug_build():
			push_warning("[Main] verify_save_roundtrip: round-trip did not yield a Dictionary")
		return false
	if (restored as Dictionary) != snapshot:
		if OS.is_debug_build():
			push_warning("[Main] verify_save_roundtrip: snapshot differs after var_to_bytes round-trip")
		return false
	return true


func _build_save_dict() -> Dictionary:
	var pawns_s: Array = []
	for p in _pawn_spawner.pawns:
		if p != null and is_instance_valid(p):
			pawns_s.append(p.data.to_save_dict())
	return {
		"v": GameSave.SAVE_VERSION,
		"tick": GameManager.tick_count,
		"game_speed": GameManager.game_speed,
		"is_paused": GameManager.is_paused,
		"player_mode": _player_mode,
		"player_pawn_id": get_player_pawn_id(),
		"world": _world.data.to_save_dict(),
		"zones": _save_stockpiles_to_array(),
		"pawns": pawns_s,
		"regrow": _save_regrow_queue(),
		"zone_filter": _zone_next_filter,
		"world_memory": WorldMemory.to_save_dict(),
		"bloodline_system": BloodlineSystem.to_save_dict(),
		"settlement_registry": SettlementRegistry.to_save_dict(),
		"settlement_memory": SettlementMemory.to_save_dict(),
		"world_persistence": WorldPersistence.to_save_dict(),
		"myth": MythMemory.to_save_dict(),
		"sacred": SacredMemory.to_save_dict(),
		"chronicle": ChronicleLog.to_save_dict(),
		"cultural_memory": CulturalMemory.to_save_dict(),
		"player_intent_queue": PlayerIntentQueue.to_save_dict(),
		"faction_registry": FactionRegistry.to_save_dict(),
		"grudge_manager": GrudgeManager.to_save_dict(),
		"gossip_manager": GossipManager.to_save_dict(),
		"myth_age": MythAge.to_save_dict(),
		"last_generation_tick": _last_generation_tick,
		# Metadata for save/load menu
		"settlement_name": _get_primary_settlement_name(),
		"pawn_count": pawns_s.size(),
		"timestamp": Time.get_datetime_string_from_system(),
	}


func _get_primary_settlement_name() -> String:
	if SettlementMemory != null:
		var settlements: Array = SettlementMemory.get_formal_settlements()
		if not settlements.is_empty():
			var s: Dictionary = settlements[0] as Dictionary
			return str(s.get("name", s.get("intent", "Settlement")))
	return "Settlement"


func _save_stockpiles_to_array() -> Array:
	var out: Array = []
	for z in StockpileManager.zones():
		var inv: Dictionary = {}
		for it in z.inventory:
			inv[str(int(it))] = int(z.inventory[it])
		out.append({
			"x": z.rect.position.x, "y": z.rect.position.y,
			"w": z.rect.size.x, "h": z.rect.size.y,
			"filter": z.filter,
			"inv": inv,
		})
	return out


func _save_regrow_queue() -> Array:
	var out: Array = []
	for due_tick in _regrow_due_ticks:
		var bucket: Array = _regrow_due_buckets.get(int(due_tick), [])
		for e in bucket:
			if e is Dictionary and e.has("tile"):
				var te: Vector2i = e.tile
				out.append({
					"tile_x": te.x, "tile_y": te.y,
					"feature": int(e.get("feature", 0)),
					"ready_tick": int(e.get("ready_tick", 0)),
				})
	return out


func _apply_save_dict(s: Dictionary) -> void:
	var wdata: Variant = WorldData.from_save_dict(s.get("world", {}))
	if wdata == null or not (wdata is WorldData):
		push_error("[Main] Load failed: world data missing or invalid. Colony unchanged.")
		return

	JobManager.clear_all()
	if SocialManager.get_kinship_system() != null and SocialManager.get_kinship_system().has_method("clear"):
		SocialManager.get_kinship_system().clear()
	if BloodlineSystem != null and BloodlineSystem.has_method("clear"):
		BloodlineSystem.clear()
	TradeMemory.clear()
	MemoryManager.get_remnant_memory().clear()
	IntentMemory.clear()
	MemoryManager.get_age_memory().clear()
	SacredMemory.clear()
	PlayerIntentQueue.clear()
	if FootpathMemory != null and FootpathMemory.has_method("clear"):
		FootpathMemory.clear()
	if BuildingUsageTracker != null and BuildingUsageTracker.has_method("clear"):
		BuildingUsageTracker.clear()
	if SnowAccumulation != null and SnowAccumulation.has_method("clear"):
		SnowAccumulation.clear()
	if TimeLapseRecorder != null and TimeLapseRecorder.has_method("clear"):
		TimeLapseRecorder.clear()
	FactionRegistry.clear()
	ChronicleLog.clear()
	_set_designation_mode(DesignationMode.NONE)
	_cancel_drag()
	_set_selected_pawn(null)
	_set_player_mode(PlayerMode.SPECTATOR)
	_regrow_due_buckets.clear()
	_regrow_due_ticks.clear()
	_hunt_candidate_tiles.clear()
	_hunt_candidate_cursor = 0
	_hunt_candidate_last_refresh_tick = -1
	_hunt_live_counts_cache = {}
	_hunt_live_total_cache = 0
	_invalidate_tunnel_frontier_cache()
	_mining_react_in_progress = false
	_mining_react_scan_y_cursor = 0
	_mining_react_newly_minable_accum = 0
	_tear_down_all_zones()
	_pawn_spawner.clear_pawns()

	_world.load_world_data(wdata as WorldData)
	var loaded_tick: int = int(s.get("tick", 0))
	var saved_player_mode: int = int(s.get("player_mode", PlayerMode.INCARNATED))
	var saved_player_pawn_id: int = int(s.get("player_pawn_id", -1))
	var load_speed: float = 1.0
	var load_paused: bool = false
	if RESTORE_SPEED_FROM_SAVE:
		load_speed = float(s.get("game_speed", 1.0))
		load_paused = bool(s.get("is_paused", false))
	GameManager.set_state_from_load(
		loaded_tick,
		load_speed,
		load_paused
	)
	_last_generation_tick = int(s.get("last_generation_tick", loaded_tick))
	_zone_next_filter = int(s.get("zone_filter", 0))
	WorldMemory.from_save_dict(s.get("world_memory", {}))
	BloodlineSystem.from_save_dict(s.get("bloodline_system", {}))
	SettlementRegistry.from_save_dict(s.get("settlement_registry", {}))
	SettlementMemory.from_save_dict(s.get("settlement_memory", {}))
	MythMemory.from_save_dict(s.get("myth", {}))
	SacredMemory.from_save_dict(s.get("sacred", {}))
	ChronicleLog.from_save_dict(s.get("chronicle", {}))
	CulturalMemory.from_save_dict(s.get("cultural_memory", {}))
	WorldMeaning.recompute()
	WorldPersistence.from_save_dict(s.get("world_persistence", {}))
	WorldPersistence.recompute()
	if GrudgeManager != null and GrudgeManager.has_method("from_save_dict"):
		GrudgeManager.from_save_dict(s.get("grudge_manager", {}))
	if GossipManager != null and GossipManager.has_method("from_save_dict"):
		GossipManager.from_save_dict(s.get("gossip_manager", {}))
	if MythAge != null and MythAge.has_method("from_save_dict"):
		MythAge.from_save_dict(s.get("myth_age", {}))
	_push_zone_filter_label_to_toolbar()
	var zlist: Array = s.get("zones", [])
	if zlist is Array and not zlist.is_empty():
		_restore_stockpiles_from_save(zlist)
	else:
		_place_stockpile(_world.pathfinder.largest_component_id())
	HeelKawnianData._next_id = 1
	for pd in s.get("pawns", []):
		if pd is Dictionary:
			var pdat: HeelKawnianData = HeelKawnianData.from_save_dict(pd)
			_pawn_spawner.spawn_from_data(pdat, _world)
	if SocialManager.get_kinship_system() != null and SocialManager.get_kinship_system().has_method("rebuild_from_pawn_spawner"):
		SocialManager.get_kinship_system().call("rebuild_from_pawn_spawner", _pawn_spawner)
	_restore_player_state(saved_player_mode, saved_player_pawn_id)
	_world.set_meta("animal_spawner", _animal_spawner)
	if is_instance_valid(_world):
		_world.apply_ruins_from_persistence()
		CulturalMemory.recompute(_world)
		SettlementMemory.recompute(_world)
		_ensure_validation_session_seed_stockpile_overlaps_settlement()
		MythMemory.recompute(_world)
		SacredMemory.sync_permanent_ruins_from_settlements()
		PlayerIntentQueue.from_save_dict(s.get("player_intent_queue", {}))
		_reset_player_intent_observer_routing()
		FactionRegistry.from_save_dict(s.get("faction_registry", {}))
		FactionRegistry.sync_from_settlements()
		MemoryManager.recompute_intent(_world)
		_run_heavy_refresh_once_per_tick(func() -> void:
			if is_instance_valid(_world):
				_world.refresh_terrain_scar_tint()
				_world.refresh_pawn_historic_path_weights()
		)
		SettlementPlanner.plan(_world, self, true)
		EconomyManager.get_trade_planner().plan(_world, self, true)
		MemoryManager.flush_dirty_tiles(_world)
		_sync_pawn_inherited_cultural_reputation()
		MemoryManager.seed_births_from_current_world(_world)
	_regrow_due_buckets.clear()
	_regrow_due_ticks.clear()
	for e in s.get("regrow", []):
		if e is Dictionary:
			var entry: Dictionary = {
				"tile": Vector2i(int(e.get("tile_x", 0)), int(e.get("tile_y", 0))),
				"feature": int(e.get("feature", 0)),
				"ready_tick": int(e.get("ready_tick", 0)),
			}
			_regrow_add_entry(entry)
	Main._world_stabilization_until_tick = GameManager.tick_count + WORLD_STABILIZATION_TICKS
	_seed_jobs_from_world()
	_react_to_mining_progress()
	if _hud != null:
		_hud.bind(_world, _pawn_spawner)
	if is_instance_valid(_day_night):
		_day_night.sync_to_tick(GameManager.tick_count)


func _restore_stockpiles_from_save(zones_data: Array) -> void:
	for zd in zones_data:
		if not (zd is Dictionary):
			continue
		var d: Dictionary = zd
		var r: Rect2i = Rect2i(
			int(d.get("x", 0)), int(d.get("y", 0)),
			int(d.get("w", 1)), int(d.get("h", 1))
		)
		var sp: Stockpile = STOCKPILE_SCENE.instantiate() as Stockpile
		if sp == null:
			continue
		sp.set_filter(int(d.get("filter", Stockpile.Filter.ALL)))
		sp.set_rect_tiles(r)
		sp.position = _world.tile_to_world(r.position)
		sp.inventory = {}
		var inv: Dictionary = d.get("inv", {})
		if inv is Dictionary:
			for key in inv:
				sp.inventory[int(key)] = int(inv[key])
		add_child(sp)
		if _world.stockpile == null:
			_world.stockpile = sp
		StockpileManager.register(sp)
		sp.queue_redraw()


# ==================== enemy combat ====================

func _on_enemy_tick(tick: int, spawner: EnemySpawner) -> void:
	if spawner == null:
		return
	# Skip enemy processing entirely when no enemies exist
	if spawner.enemies.is_empty():
		return
	spawner.process_tick(_world, tick)
	if spawner.get_enemy_count() > 0 and tick % 100 == 0 and OS.is_debug_build():
		print("[Combat] %s" % spawner.describe())


func trigger_war_battle_spawn(src_settlement_id: int, target_settlement_id: int, strength: float) -> bool:
	if _enemy_spawner == null or _world == null:
		return false
	if _enemy_spawner.get_enemy_count() > 0:
		return false
	return bool(_enemy_spawner.spawn_war_forces(_world, src_settlement_id, target_settlement_id, strength))


func _living_pawn_count() -> int:
	if _pawn_spawner == null:
		return 0
	var alive: int = 0
	for p in _pawn_spawner.pawns:
		if p != null and is_instance_valid(p):
			alive += 1
	return alive


func register_enemy_kill(enemy_name: String, attacker_name: String, tile: Vector2i) -> void:
	_kill_count += 1
	WorldMemory.record_enemy_death(GameManager.tick_count, tile, enemy_name, attacker_name, _kill_count)


func register_pawn_death(_pawn_id: int) -> void:
	_kill_count += 1
	if BloodlineSystem != null and BloodlineSystem.has_method("record_pawn_death"):
		BloodlineSystem.call("record_pawn_death", int(_pawn_id))


func get_kill_count() -> int:
	return _kill_count


func _toggle_observer_hud() -> void:
	if _observer_hud == null:
		return
	var next_visible: bool = not _observer_hud.is_visible_state()
	_observer_hud.set_visible_state(next_visible)
	if next_visible:
		_observer_hud.apply_snapshot(_build_observer_snapshot(GameManager.tick_count))


func _toggle_focus_inspector() -> void:
	if _focus_inspector == null:
		return
	var next_visible: bool = not _focus_inspector.is_visible_state()
	_focus_inspector.set_visible_state(next_visible)
	if next_visible:
		_focus_inspector.apply_snapshot(_build_focus_snapshot(GameManager.tick_count))


func _toggle_performance_monitor() -> void:
	if _performance_monitor == null:
		return
	_performance_monitor.toggle()


func _build_focus_snapshot(tick: int) -> Dictionary:
	return ObservationAPI.build_focus_snapshot_from_focus(_resolve_focus_target(), tick)


func _resolve_focus_target() -> Dictionary:
	if _world == null:
		return {"type": "NONE", "source": "none"}
	var mouse_world: Vector2 = get_global_mouse_position()
	var mouse_pawn: HeelKawnian = _focus_pawn_under_world_pos(mouse_world)
	if mouse_pawn != null and mouse_pawn.data != null:
		return {"type": "PAWN", "source": "mouse_pawn", "pawn": mouse_pawn}
	var mouse_tile: Vector2i = _world.world_to_tile(mouse_world)
	if mouse_tile.x >= 0 and mouse_tile.y >= 0:
		var settlement: Variant = SettlementMemory.get_settlement_at_region(_WM._region_key(mouse_tile.x, mouse_tile.y))
		if settlement is Dictionary:
			return {"type": "SETTLEMENT", "source": "mouse_tile", "tile": mouse_tile, "settlement": settlement}
		return {"type": "TILE", "source": "mouse_tile", "tile": mouse_tile}
	var cam_tile: Vector2i = _world.world_to_tile(_camera.global_position) if _camera != null else Vector2i(-1, -1)
	if cam_tile.x >= 0 and cam_tile.y >= 0:
		return {"type": "TILE", "source": "camera_center", "tile": cam_tile}
	return {"type": "NONE", "source": "none"}


func _focus_pawn_under_world_pos(world_pos: Vector2) -> HeelKawnian:
	if _pawn_spawner == null:
		return null
	var best: HeelKawnian = null
	var best_d_sq: float = SELECT_PICK_RADIUS_PX * SELECT_PICK_RADIUS_PX
	for p in _pawn_spawner.pawns:
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		var d_sq: float = p.global_position.distance_squared_to(world_pos)
		if d_sq <= best_d_sq:
			best = p
			best_d_sq = d_sq
	return best


func _focus_lines_for_pawn(focus: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var p: HeelKawnian = focus.get("pawn", null) as HeelKawnian
	if p == null or p.data == null:
		return PackedStringArray(["NO FOCUS", "Move cursor over a pawn, settlement, or tile"])
	var d: HeelKawnianData = p.data
	var rk: int = _WM._region_key(d.tile_pos.x, d.tile_pos.y)
	var gov: Dictionary = SettlementMemory.get_governance_profile_for_region(rk)
	var role: String = _pawn_governance_role(d, gov)
	var war: Dictionary = SettlementMemory.get_war_profile_for_region(rk)
	var st_v: Variant = SettlementMemory.get_settlement_at_region(rk)
	var settlement_label: String = "Unknown"
	if st_v is Dictionary:
		settlement_label = _pretty_settlement_state(str((st_v as Dictionary).get("state", "unknown")))
	var health_pct: int = int(round(d.get_health_percentage() * 100.0)) if d.has_method("get_health_percentage") else 0
	var state_label: String = p.get_state_name() if p.has_method("get_state_name") else "Unknown"
	var job_label: String = p.get_current_job_label() if p.has_method("get_current_job_label") else "None"
	var local_mode: String = "Retreat" if d.has_method("get_health_percentage") and float(d.get_health_percentage()) < 0.5 else "Ordered"
	out.append("Name: %s" % d.display_name)
	out.append("Profession: %s | Military Rank: %s" % [d.profession_name(), str(d.military_rank_legacy).capitalize()])
	out.append("Governance Role: %s" % role)
	out.append("Health: %d%% | Hunger %.0f | Rest %.0f | Mood %.0f" % [health_pct, d.hunger, d.rest, d.mood])
	out.append("Action: %s | Job: %s" % [state_label, job_label])
	out.append("Settlement state (committed/hysteresis): %s | War: %s" % [settlement_label, _pretty_war_state(str(war.get("state", "peace")))])
	out.append("Battlefield Posture: %s" % local_mode)
	if p.has_method("get_runtime_cohort_observability"):
		var cobs: Dictionary = p.call("get_runtime_cohort_observability")
		var c_job_type: int = int(cobs.get("cohort_job_type", -1))
		var a_job_type: int = int(cobs.get("active_job_type", -1))
		var s_job_type: int = int(cobs.get("stability_job_type", -1))
		var locus_tile: Vector2i = cobs.get("locus_tile", Vector2i(-1, -1))
		out.append("Cohort: anchor=%s active=%s stored=%s is_anchor=%s" % [
			str(cobs.get("anchor_id", -1)),
			Job.describe_type(a_job_type) if a_job_type >= 0 else "None",
			Job.describe_type(c_job_type) if c_job_type >= 0 else "None",
			"Yes" if bool(cobs.get("is_anchor", false)) else "No",
		])
		out.append("Cohort Locus: (%d,%d) | Stability: %d ticks [%s]" % [
			locus_tile.x,
			locus_tile.y,
			int(cobs.get("stability_ticks", 0)),
			Job.describe_type(s_job_type) if s_job_type >= 0 else "None",
		])
	var house_center: int = rk
	var st_for_house: Variant = SettlementMemory.get_settlement_at_region(rk)
	if st_for_house is Dictionary:
		house_center = int((st_for_house as Dictionary).get("center_region", rk))
	_focus_append_house_stub_lines(out, house_center)
	return out


func _focus_lines_for_settlement(focus: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var tile: Vector2i = focus.get("tile", Vector2i(-1, -1))
	var st: Dictionary = focus.get("settlement", {})
	var center: int = int(st.get("center_region", -1))
	var gov: Dictionary = SettlementMemory.get_governance_profile_for_region(center)
	var war: Dictionary = SettlementMemory.get_war_profile_for_region(center)
	out.append("Region: %d | Tile: (%d,%d)" % [center, tile.x, tile.y])
	out.append(
			"Settlement state (committed/hysteresis-smoothed): %s"
			% _pretty_settlement_state(str(st.get("state", "unknown")))
	)
	out.append(
			"Settlement truth raw (material audit, not smoothed): %s"
			% str(st.get("state_truth_raw", st.get("state", "unknown")))
	)
	out.append(
			(
					"Material signals: liv=%d shelter=%s work=%d stockpile=%s (flag=designated stockpile-zone overlap only) "
					+ "sp_zone_overlap_hits=%d | hysteresis_key=center_region:%d"
			)
			% [
				int(st.get("material_signal_living", 0)),
				"Y" if int(st.get("material_signal_shelter", 0)) != 0 else "N",
				int(st.get("material_signal_work", 0)),
				"Y" if int(st.get("material_signal_stockpile", 0)) != 0 else "N",
				int(st.get("material_stockpile_overlap_hits", 0)),
				center,
			]
	)
	out.append("Governance (political identity, not material liveness): %s | Ruler: %s" % [
		_pretty_governance_name(str(gov.get("type", "anarchy"))),
		_pawn_name_by_id(int(gov.get("ruler_id", -1)))
	])
	var pop: int = _count_pawns_in_regions(st.get("regions", PackedInt32Array()))
	out.append("Population: %d | Council Size: %d" % [pop, (gov.get("council_ids", PackedInt32Array()) as PackedInt32Array).size() if gov.get("council_ids", PackedInt32Array()) is PackedInt32Array else 0])
	out.append("War: %s | Target: %s" % [_pretty_war_state(str(war.get("state", "peace"))), _observer_war_target_label(int(war.get("target_settlement_id", -1)))])
	out.append("Intent: %s" % str(st.get("current_intent", SettlementMemory.INTENT_GROW)))
	var wf_ph: String = str(st.get("specialization_phase", SettlementMemory.SPECIALIZATION_PHASE_UNKNOWN))
	var wf_lk: String = str(st.get("specialization_channel", ""))
	var wf_cd: String = str(st.get("specialization_candidate_channel", ""))
	var wf_cf: int = int(st.get("specialization_confidence", 0))
	var wf_line: String = "Work-focus (proxy): %s" % wf_ph
	match wf_ph:
		SettlementMemory.SPECIALIZATION_PHASE_LOCKED:
			wf_line += " — %s [%d%%]" % [SettlementMemory.specialization_work_focus_label(wf_lk), wf_cf]
		SettlementMemory.SPECIALIZATION_PHASE_CANDIDATE:
			wf_line += " — → %s [%d%%]" % [SettlementMemory.specialization_work_focus_label(wf_cd), wf_cf]
		_:
			wf_line += " — Unspecialized"
	out.append(wf_line)
	var fronts_v: Variant = st.get("preferred_fronts", [])
	if fronts_v is Array and not (fronts_v as Array).is_empty():
		var idx: int = 0
		for fv in fronts_v as Array:
			if not (fv is Dictionary):
				continue
			if idx >= 2:
				break
			var f: Dictionary = fv as Dictionary
			var ftile: Vector2i = f.get("tile", Vector2i(-1, -1))
			out.append("Front %d: %s @ (%d,%d) support=%d stability=%d" % [
				idx + 1,
				Job.describe_type(int(f.get("job_type", -1))) if int(f.get("job_type", -1)) >= 0 else "Unknown",
				ftile.x,
				ftile.y,
				int(f.get("support", 0)),
				int(f.get("stability_ticks", 0)),
			])
			idx += 1
	else:
		out.append("Fronts: none")
	out.append("Food Pressure: %d%% | Housing Pressure: %d%%" % [
		int(round(ColonySimServices.get_food_pressure() * 100.0)),
		int(round(ColonySimServices.get_housing_pressure() * 100.0)),
	])
	var tradition: Dictionary = CulturalMemory.get_tradition(center)
	var t_branch: String = str(tradition.get("preferred_tech_branch", "agriculture"))
	var t_naming: String = str(tradition.get("naming_convention", "nordic"))
	var taboo_v: Variant = tradition.get("taboo_jobs", [])
	var taboo_s: String = "none"
	if taboo_v is Array and not (taboo_v as Array).is_empty():
		taboo_s = ", ".join(taboo_v as Array)
	out.append("Tradition: branch=%s | naming=%s | taboo=%s" % [t_branch, t_naming, taboo_s])
	out.append(_tradition_narrative_tooltip_line(tradition))
	_focus_append_house_stub_lines(out, center)
	return out


func _focus_lines_for_tile(focus: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var tile: Vector2i = focus.get("tile", Vector2i(-1, -1))
	if tile.x < 0:
		return PackedStringArray(["NO FOCUS", "Move cursor over a pawn, settlement, or tile"])
	var rk: int = _WM._region_key(tile.x, tile.y)
	out.append("Tile: (%d,%d) | Region: %d" % [tile.x, tile.y, rk])
	var biome: int = _world.data.get_biome(tile.x, tile.y) if _world != null and _world.data != null else -1
	out.append("Biome: %d | Scar: %d" % [biome, int(WorldPersistence.get_region_persistence(rk).get("scar_level", 0))])
	var st_v: Variant = SettlementMemory.get_settlement_at_region(rk)
	if st_v is Dictionary:
		var st: Dictionary = st_v as Dictionary
		var center: int = int(st.get("center_region", -1))
		var gov: Dictionary = SettlementMemory.get_governance_profile_for_region(center)
		out.append(
				"Settlement committed: %s | truth raw: %s | Governance (political): %s"
				% [
					_pretty_settlement_state(str(st.get("state", "unknown"))),
					str(st.get("state_truth_raw", st.get("state", "unknown"))),
					_pretty_governance_name(str(gov.get("type", "anarchy"))),
				]
		)
		var t_line: String = _tradition_narrative_tooltip_line(CulturalMemory.get_tradition(center))
		out.append("Tradition narrative: %s" % t_line)
		_focus_append_house_stub_lines(out, int(st.get("center_region", -1)))
	var events: Array[Dictionary] = WorldMemory.get_events_for_tile(tile)
	if not events.is_empty():
		var evt: Dictionary = events[events.size() - 1]
		var etype: String = str(evt.get("type", "event"))
		out.append("Last Event: %s @ tick %d" % [etype.replace("_", " "), int(evt.get("t", 0))])
	return out


func _tradition_narrative_tooltip_line(tradition: Dictionary) -> String:
	var branch: String = str(tradition.get("preferred_tech_branch", "agriculture")).to_lower()
	var naming: String = str(tradition.get("naming_convention", "nordic")).to_lower()
	var taboo_v: Variant = tradition.get("taboo_jobs", [])
	var taboo_hunt: bool = false
	if taboo_v is Array:
		for t_any in taboo_v as Array:
			if str(t_any).to_upper() == "HUNT":
				taboo_hunt = true
				break
	var branch_line: String = "leans into patient fieldcraft and food security."
	if branch.find("metal") >= 0:
		branch_line = "leans into forge-minded craft and durable tools."
	var taboo_line: String = "No major labor taboo dominates memory."
	if taboo_hunt:
		taboo_line = "Hunting is culturally avoided after prior bloodshed."
	var naming_line: String = "Names preserve a %s cadence across generations." % naming
	return "%s %s %s" % [branch_line, taboo_line, naming_line]


## FactionRegistry: deterministic house line for settlement zone (focus / observer readout).
func _focus_append_house_stub_lines(out: PackedStringArray, center_region: int) -> void:
	FactionRegistry.append_focus_house_lines(out, center_region)


func _pawn_governance_role(d: HeelKawnianData, gov: Dictionary) -> String:
	var pid: int = int(d.id)
	if int(gov.get("ruler_id", -1)) == pid:
		return "Ruler"
	var council_ids: Variant = gov.get("council_ids", PackedInt32Array())
	if council_ids is PackedInt32Array and (council_ids as PackedInt32Array).has(pid):
		return "Council"
	if str(d.military_rank_legacy).to_lower() == "battlemaster":
		return "BattleMaster"
	return "Citizen"


func _count_pawns_in_regions(regions_v: Variant) -> int:
	if _pawn_spawner == null or not (regions_v is PackedInt32Array):
		return 0
	var wanted: Dictionary = {}
	for rk in regions_v as PackedInt32Array:
		wanted[int(rk)] = true
	var n: int = 0
	for p in _pawn_spawner.pawns:
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		var rk: int = _WM._region_key(p.data.tile_pos.x, p.data.tile_pos.y)
		if wanted.has(rk):
			n += 1
	return n


func _pawn_counts_by_region_key() -> Dictionary:
	var out: Dictionary = {}
	for p in get_visible_pawns():
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		var rk: int = _WM._region_key(p.data.tile_pos.x, p.data.tile_pos.y)
		out[rk] = int(out.get(rk, 0)) + 1
	return out


func _build_realm_crown_view_text() -> String:
	## Macro strip: settlements × proto-houses × myth/sacred tone (read-only facts).
	var max_settlements: int = _realm_crown_max_settlements
	var proto_sites: int = SettlementMemory.get_proto_sites().size()
	FactionRegistry.sync_from_settlements()
	var rows: Array = []
	for st_any in SettlementMemory.get_formal_settlements():
		if not (st_any is Dictionary):
			continue
		var st: Dictionary = st_any
		if int(st.get("center_region", -1)) < 0:
			continue
		rows.append(st)
	rows.sort_custom(func(a: Variant, b: Variant) -> bool:
		if not (a is Dictionary and b is Dictionary):
			return false
		var ad: Dictionary = a
		var bd: Dictionary = b
		var an: String = str(ad.get("name", "Unnamed"))
		var bn: String = str(bd.get("name", "Unnamed"))
		if an != bn:
			return an < bn
		return int(ad.get("center_region", 0)) < int(bd.get("center_region", 0))
	)
	if is_player_incarnated() and _player_pawn != null and is_instance_valid(_player_pawn) and _player_pawn.data != null:
		var pt: Vector2i = _player_pawn.data.tile_pos
		var r_fog: int = INCARNATE_KNOWLEDGE_FOG_RADIUS_TILES
		var rows_f: Array = []
		for st_row in rows:
			if not (st_row is Dictionary):
				continue
			var st_f: Dictionary = st_row
			var ckr_f: int = int(st_f.get("center_region", -1))
			if ckr_f < 0:
				continue
			var ct_f: Vector2i = _center_tile_from_region_key(ckr_f)
			if _tile_chebyshev_dist(pt, ct_f) <= r_fog:
				rows_f.append(st_row)
		rows = rows_f
	var place_count: int = rows.size()
	var listed: int = 0
	var lines: PackedStringArray = PackedStringArray()
	var pop_by_rk: Dictionary = _pawn_counts_by_region_key()
	for st_row in rows:
		if listed >= max_settlements:
			break
		var st: Dictionary = st_row
		var ckr: int = int(st.get("center_region", -1))
		var zid: String = str(ckr)
		var nm: String = str(st.get("name", "Unnamed"))
		if nm.length() > 20:
			nm = nm.substr(0, 17) + "..."
		var pop: int = 0
		var regv: Variant = st.get("regions", PackedInt32Array())
		if regv is PackedInt32Array:
			var seen_rk: Dictionary = {}
			for rk_any in regv as PackedInt32Array:
				var rk: int = int(rk_any)
				if seen_rk.has(rk):
					continue
				seen_rk[rk] = true
				pop += int(pop_by_rk.get(rk, 0))
		var house: Dictionary = FactionRegistry.get_house_for_zone(zid)
		var house_disp: String = str(house.get("house_display", "—"))
		var rel: Dictionary = ReligionLens.describe_settlement_zone(zid)
		var st_state: String = str(rel.get("state", ""))
		var voice: String = str(rel.get("voice", ""))
		lines.append("• %s — pop %d · %s · %s · %s" % [nm, pop, house_disp, st_state, voice])
		listed += 1
	var houses_n: int = FactionRegistry.get_synced_house_count()
	var sac_n: int = SacredMemory.site_count() if SacredMemory != null else 0
	var harm: float = ReligionLens.get_harmony_index() if ReligionLens != null else 0.0
	var total_pawns: int = _observer_total_pawns()
	var head: String = (
			"[b]REALM (crown view)[/b]\n"
			+ "Formal settlements %d · Proto sites %d · Heelkawnians %d · Houses %d · Sacred sites %d · Harmony %.2f\n"
			% [place_count, proto_sites, total_pawns, houses_n, sac_n, harm]
	)
	if place_count == 0:
		return (
				head
				+ "No settlements yet.\n[i]F9 observer · Shift+F9 cycle rows (%d)[/i]\n"
				% max_settlements
		)
	var more_note: String = ""
	if place_count > listed:
		more_note = "[i](+%d places not listed)[/i]\n" % (place_count - listed)
	var body: String = "\n".join(lines)
	return (
			head
			+ more_note
			+ body
			+ "\n[i]F9 observer · Shift+F9 rows (%d) · sim refresh[/i]\n"
			% max_settlements
	)


func _build_observer_snapshot(tick: int) -> Dictionary:
	var day_len: int = DayNightCycle.TICKS_PER_DAY
	var day_abs: int = SimTime.calendar_absolute_visual_day(tick)
	var day_in_year: int = SimTime.calendar_day_within_sim_year(tick)
	var days_per_sim_year: int = SimTime.visual_days_per_sim_year()
	var speed_text: String = "%dx" % int(GameManager.game_speed)
	var paused_text: String = "Yes" if GameManager.is_paused else "No"
	var focus: Dictionary = _observer_focus_settlement()
	var settlement_idx: int = int(focus.get("settlement_idx", -1))
	var settlement_data: Dictionary = focus.get("settlement_data", {})
	var governance: Dictionary = focus.get("governance", {"type": "anarchy", "ruler_id": -1, "council_ids": PackedInt32Array()})
	var war: Dictionary = focus.get("war", {"state": "peace", "target_settlement_id": -1, "votes": []})
	var ruler_name: String = _pawn_name_by_id(int(governance.get("ruler_id", -1)))
	var council_ids: Variant = governance.get("council_ids", PackedInt32Array())
	var council_size: int = council_ids.size() if council_ids is PackedInt32Array else 0
	var battlemaster_name: String = _find_battlemaster_name(settlement_idx, settlement_data)
	var wildlife: Dictionary = get_wildlife_snapshot_for_diagnostic()
	var jobs: Dictionary = JobManager.stats()
	var battlefield_mode: String = _observer_battlefield_mode()
	var determinism_lock: String = "Locked" if is_kernel_diagnostic_complete() else "Pending"
	var kernel_phase: String = "Phase 7 Complete" if is_kernel_diagnostic_complete() else "Phase 7 Waiting"
	var food_pressure: float = float(ColonySimServices.get_food_pressure())
	var housing_pressure: float = float(ColonySimServices.get_housing_pressure())
	var resource_pressure: Dictionary = settlement_data.get("resource_pressure", {})
	var resource_truth: Dictionary = settlement_data.get("resource_truth", {})
	var resource_balance: Dictionary = settlement_data.get("resource_balance", {})
	var rp_wood: float = clamp(float(resource_pressure.get("wood", 0.0)), 0.0, 1.0)
	var rp_stone: float = clamp(float(resource_pressure.get("stone", 0.0)), 0.0, 1.0)
	var rp_ore: float = clamp(float(resource_pressure.get("ore_proxy", 0.0)), 0.0, 1.0)
	var rt_food: int = int(resource_truth.get("stock_food", 0))
	var rt_wood: int = int(resource_truth.get("stock_wood", 0))
	var rt_stone: int = int(resource_truth.get("stock_stone", 0))
	var rt_ore_proxy: int = int(resource_truth.get("stock_ore_proxy", 0))
	var rt_total: int = int(resource_truth.get("total_stock_units", 0))
	var rt_tick: int = int(resource_truth.get("snapshot_tick", -1))
	var rt_center: int = int(resource_truth.get("center_region", -1))
	var rb_food: String = str(resource_balance.get("food_balance", "DEFICIT"))
	var rb_wood: String = str(resource_balance.get("wood_balance", "DEFICIT"))
	var rb_stone: String = str(resource_balance.get("stone_balance", "DEFICIT"))
	var rb_ore_proxy: String = str(resource_balance.get("ore_proxy_balance", "DEFICIT"))
	var rb_tick: int = int(resource_balance.get("snapshot_tick", -1))
	var rb_center: int = int(resource_balance.get("center_region", -1))
	var rb_source: String = str(resource_balance.get("source", "stock_truth_derived_first_pass"))
	var rb_audit: Dictionary = SettlementMemory.resource_balance_audit_snapshot_for_settlement(settlement_data)
	var rb_audit_result: String = str(rb_audit.get("result", "n/a"))
	var rb_audit_tick: int = int(rb_audit.get("snapshot_tick", -1))
	var rb_audit_center: int = int(rb_audit.get("center_region", -1))
	var rb_audit_sig: String = "%d|%s|%d|%d|%d|%d|%s|%s|%s|%s" % [
		rb_audit_center,
		rb_audit_result,
		int(rb_audit.get("food_count", 0)),
		int(rb_audit.get("wood_count", 0)),
		int(rb_audit.get("stone_count", 0)),
		int(rb_audit.get("ore_proxy_count", 0)),
		str(rb_audit.get("food_actual", "")),
		str(rb_audit.get("wood_actual", "")),
		str(rb_audit.get("stone_actual", "")),
		str(rb_audit.get("ore_proxy_actual", "")),
	]
	var sig_changed: bool = rb_audit_sig != _resource_balance_audit_last_sig

	# Recent player_inspect summary (for observer HUD)
	var last_inspect_summary: String = "None"
	var recent_events: Array = WorldMemory.get_recent_events(32)
	for i in range(recent_events.size() - 1, -1, -1):
		var ev: Dictionary = recent_events[i]
		if str(ev.get("type", "")) == "player_inspect":
			last_inspect_summary = "%s | pawn:%d region:%d meaning:%s tags:%s" % [
				str(ev.get("type", "player_inspect")),
				int(ev.get("pawn_id", -1)),
				int(ev.get("center_region", -1)),
				str(ev.get("meaning_label", "")),
				str(ev.get("tags", PackedStringArray())),
			]
			break
	var force_audit_line: bool = rb_audit_result != "PASS"
	if (
			OS.is_debug_build()
			and rb_audit_tick >= 0
			and rb_audit_center >= 0
			and (sig_changed or force_audit_line)
	):
		_resource_balance_audit_last_sig = rb_audit_sig
		print(
				(
						"[RESOURCE_BALANCE_AUDIT] tick=%d center_region=%d result=%s "
						+ "food=%d=>%s(actual=%s) wood=%d=>%s(actual=%s) "
						+ "stone=%d=>%s(actual=%s) ore_proxy=%d=>%s(actual=%s)"
				)
				% [
					rb_audit_tick,
					rb_audit_center,
					rb_audit_result,
					int(rb_audit.get("food_count", 0)),
					str(rb_audit.get("food_expected", "DEFICIT")),
					str(rb_audit.get("food_actual", "DEFICIT")),
					int(rb_audit.get("wood_count", 0)),
					str(rb_audit.get("wood_expected", "DEFICIT")),
					str(rb_audit.get("wood_actual", "DEFICIT")),
					int(rb_audit.get("stone_count", 0)),
					str(rb_audit.get("stone_expected", "DEFICIT")),
					str(rb_audit.get("stone_actual", "DEFICIT")),
					int(rb_audit.get("ore_proxy_count", 0)),
					str(rb_audit.get("ore_proxy_expected", "DEFICIT")),
					str(rb_audit.get("ore_proxy_actual", "DEFICIT")),
				]
		)
	var wf_phase: String = str(settlement_data.get("specialization_phase", SettlementMemory.SPECIALIZATION_PHASE_UNKNOWN))
	var wf_locked_ch: String = str(settlement_data.get("specialization_channel", ""))
	var wf_cand_ch: String = str(settlement_data.get("specialization_candidate_channel", ""))
	var wf_conf: int = int(settlement_data.get("specialization_confidence", 0))
	var wf_display: String = "Unspecialized"
	match wf_phase:
		SettlementMemory.SPECIALIZATION_PHASE_LOCKED:
			wf_display = SettlementMemory.specialization_work_focus_label(wf_locked_ch)
		SettlementMemory.SPECIALIZATION_PHASE_CANDIDATE:
			wf_display = "→ %s (pending)" % SettlementMemory.specialization_work_focus_label(wf_cand_ch)
		_:
			wf_display = "Unspecialized"
	var war_state_raw: String = str(war.get("state", "peace"))
	var settlement_state_raw: String = str(settlement_data.get("state", "unknown"))
	var settlement_truth_raw: String = str(settlement_data.get("state_truth_raw", settlement_state_raw))
	var mat_liv: int = int(settlement_data.get("material_signal_living", 0))
	var mat_sh: int = int(settlement_data.get("material_signal_shelter", 0))
	var mat_wk: int = int(settlement_data.get("material_signal_work", 0))
	var mat_sp: int = int(settlement_data.get("material_signal_stockpile", 0))
	var mat_sp_zone_hits: int = int(settlement_data.get("material_stockpile_overlap_hits", 0))
	var settlement_center_region: int = int(settlement_data.get("center_region", -1))
	var war_state_label: String = _war_state_label(war_state_raw)
	var settlement_state_label: String = _settlement_state_label(settlement_state_raw)
	var food_pressure_label: String = _pressure_label(food_pressure)
	var housing_pressure_label: String = _pressure_label(housing_pressure)
	var world_status_summary: String = _observer_world_status_summary(
		war_state_raw,
		settlement_state_raw,
		food_pressure,
		housing_pressure,
		str(governance.get("type", "anarchy")),
		ruler_name
	)
	var recent_history_lines: PackedStringArray = WorldMemory.get_recent_event_summaries(3)
	var vh: Dictionary = SettlementMemory.validation_harness_flags_for_snapshot()
	var footer_stamp: String = "Tick %d | Y%d D%d/%d (absD%d) | Determinism %s | Events %d | %s" % [
		tick,
		SimTime.sim_year_index(tick),
		day_in_year,
		days_per_sim_year,
		day_abs,
		determinism_lock,
		WorldMemory.event_count(),
		kernel_phase,
	]
	return {
		"tick": tick,
		"day": day_abs,
		"calendar_day_in_year": day_in_year,
		"calendar_days_per_sim_year": days_per_sim_year,
		"speed": speed_text,
		"paused": paused_text,
		"player_mode": get_player_mode_label(),
		"player_pawn_id": get_player_pawn_id(),
		"incarnation_picker_visible": _incarnation_picker != null and is_instance_valid(_incarnation_picker) and _incarnation_picker.visible,
		"last_player_inspect": last_inspect_summary,
		"world_status_summary": world_status_summary,
		"governance_type": _pretty_governance_name(str(governance.get("type", "anarchy"))),
		"ruler_name": ruler_name,
		"council_size": council_size,
		"settlement_state": _pretty_settlement_state(settlement_state_raw),
		"settlement_state_label": settlement_state_label,
		"settlement_state_truth_raw": settlement_truth_raw,
		"settlement_state_committed": settlement_state_raw,
		"settlement_hysteresis_key_center_region": settlement_center_region,
		"settlement_material_living": mat_liv,
		"settlement_material_shelter": mat_sh,
		"settlement_material_work": mat_wk,
		"settlement_material_stockpile": mat_sp,
		"settlement_material_stockpile_zone_overlap_hits": mat_sp_zone_hits,
		"total_pawns": _observer_total_pawns(),
		"children_count": _observer_children_count(),
		"wild_rabbit": int(wildlife.get("rabbit", 0)),
		"wild_deer": int(wildlife.get("deer", 0)),
		"wild_total": int(wildlife.get("total", 0)),
		"jobs_open": int(jobs.get("open", 0)),
		"jobs_claimed": int(jobs.get("claimed", 0)),
		"food_pressure": food_pressure,
		"food_pressure_label": food_pressure_label,
		"housing_pressure": housing_pressure,
		"housing_pressure_label": housing_pressure_label,
		"resource_pressure_wood": rp_wood,
		"resource_pressure_stone": rp_stone,
		"resource_pressure_ore_proxy": rp_ore,
		"resource_truth_stock_food": rt_food,
		"resource_truth_stock_wood": rt_wood,
		"resource_truth_stock_stone": rt_stone,
		"resource_truth_stock_ore_proxy": rt_ore_proxy,
		"resource_truth_total_units": rt_total,
		"resource_truth_snapshot_tick": rt_tick,
		"resource_truth_center_region": rt_center,
		"resource_balance_food": rb_food,
		"resource_balance_wood": rb_wood,
		"resource_balance_stone": rb_stone,
		"resource_balance_ore_proxy": rb_ore_proxy,
		"resource_balance_snapshot_tick": rb_tick,
		"resource_balance_center_region": rb_center,
		"resource_balance_source": rb_source,
		"resource_balance_audit_result": rb_audit_result,
		"resource_balance_audit_snapshot_tick": rb_audit_tick,
		"resource_balance_audit_center_region": rb_audit_center,
		"work_focus_phase": wf_phase,
		"work_focus_display": wf_display,
		"work_focus_confidence": wf_conf,
		"intent_summary": _observer_intent_summary(),
		"war_state": _pretty_war_state(war_state_raw),
		"war_state_label": war_state_label,
		"war_target": _observer_war_target_label(int(war.get("target_settlement_id", -1))),
		"battlemaster_name": battlemaster_name,
		"active_enemies": _enemy_spawner.get_enemy_count() if _enemy_spawner != null else 0,
		"battlefield_mode": battlefield_mode,
		"recent_history_lines": recent_history_lines,
		"determinism_lock": determinism_lock,
		"world_memory_events": WorldMemory.event_count(),
		"kernel_phase": kernel_phase,
		"next_diag_tick": KernelDiagnostic.DIAGNOSTIC_TICK,
		"footer_stamp": footer_stamp,
		"validation_os_debug_build": OS.is_debug_build(),
		"validation_session_const_requested": SettlementMemory.VALIDATION_SESSION_ENABLED,
		"validation_session": bool(vh.get("session", false)),
		"validation_clean_economy_events": WorldEvents.validation_clean_economy_events_active(),
		"validation_settlement_truth_verify": bool(vh.get("settlement_truth_verify", false)),
		"validation_specialization_log": bool(vh.get("specialization_log", false)),
		"camera_revival_digest_plain": get_camera_revival_digest_plain(),
		"chronicler_pin_zone_id": _player_intent_pin_zone_id,
		"sim_ticks_last_frame": GameManager.ticks_emitted_last_frame if GameManager != null else 0,
		"realm_crown_view_text": _build_realm_crown_view_text(),
	}


func _observer_focus_settlement() -> Dictionary:
	var settlement_idx: int = -1
	var settlement_data: Dictionary = {}
	if _player_intent_focus_center_region >= 0:
		var cr_focus: int = _player_intent_focus_center_region
		_player_intent_focus_center_region = -1
		for i in range(SettlementMemory.settlements.size()):
			var stv_f: Variant = SettlementMemory.settlements[i]
			if not (stv_f is Dictionary):
				continue
			var st_f: Dictionary = stv_f as Dictionary
			if int(st_f.get("center_region", -1)) == cr_focus:
				settlement_idx = i
				settlement_data = st_f
				break
			var regs_f: Variant = st_f.get("regions", PackedInt32Array())
			if regs_f is PackedInt32Array and (regs_f as PackedInt32Array).has(cr_focus):
				settlement_idx = i
				settlement_data = st_f
				break
		if settlement_idx >= 0:
			var center_f: int = int(settlement_data.get("center_region", -1))
			var governance_f: Dictionary = {"type": "anarchy", "ruler_id": -1, "council_ids": PackedInt32Array()}
			var war_f: Dictionary = {"state": "peace", "target_settlement_id": -1, "votes": []}
			if center_f >= 0:
				governance_f = SettlementMemory.get_governance_profile_for_region(center_f)
				war_f = SettlementMemory.get_war_profile_for_region(center_f)
			return {
				"settlement_idx": settlement_idx,
				"settlement_data": settlement_data,
				"governance": governance_f,
				"war": war_f,
			}
	if _player_pawn != null and is_instance_valid(_player_pawn) and _player_pawn.data != null:
		var prk: int = _WM._region_key(_player_pawn.data.tile_pos.x, _player_pawn.data.tile_pos.y)
		for i in range(SettlementMemory.settlements.size()):
			var stv: Variant = SettlementMemory.settlements[i]
			if not (stv is Dictionary):
				continue
			var st: Dictionary = stv as Dictionary
			var regs: Variant = st.get("regions", PackedInt32Array())
			if regs is PackedInt32Array and (regs as PackedInt32Array).has(prk):
				settlement_idx = i
				settlement_data = st
				break
	if settlement_idx < 0:
		if is_player_incarnated() and _player_pawn != null and is_instance_valid(_player_pawn) and _player_pawn.data != null:
			var pt_obs: Vector2i = _player_pawn.data.tile_pos
			var r_obs: int = INCARNATE_KNOWLEDGE_FOG_RADIUS_TILES
			var best_i: int = -1
			var best_d: int = 1_000_000_000
			for i in range(SettlementMemory.settlements.size()):
				if not (SettlementMemory.settlements[i] is Dictionary):
					continue
				var st_try: Dictionary = SettlementMemory.settlements[i] as Dictionary
				var ckr_t: int = int(st_try.get("center_region", -1))
				if ckr_t < 0:
					continue
				var ct_t: Vector2i = _center_tile_from_region_key(ckr_t)
				var dist_t: int = _tile_chebyshev_dist(pt_obs, ct_t)
				if dist_t <= r_obs and dist_t < best_d:
					best_d = dist_t
					best_i = i
			if best_i >= 0:
				settlement_idx = best_i
				settlement_data = SettlementMemory.settlements[best_i] as Dictionary
		else:
			for i in range(SettlementMemory.settlements.size()):
				if SettlementMemory.settlements[i] is Dictionary:
					settlement_idx = i
					settlement_data = SettlementMemory.settlements[i] as Dictionary
					break
	var governance: Dictionary = {"type": "anarchy", "ruler_id": -1, "council_ids": PackedInt32Array()}
	var war: Dictionary = {"state": "peace", "target_settlement_id": -1, "votes": []}
	if settlement_idx >= 0:
		var center: int = int(settlement_data.get("center_region", -1))
		if center >= 0:
			governance = SettlementMemory.get_governance_profile_for_region(center)
			war = SettlementMemory.get_war_profile_for_region(center)
	return {
		"settlement_idx": settlement_idx,
		"settlement_data": settlement_data,
		"governance": governance,
		"war": war,
	}


func _observer_total_pawns() -> int:
	return get_visible_pawns().size()


func _observer_children_count() -> int:
	var c: int = 0
	for p in get_visible_pawns():
		if p != null and is_instance_valid(p) and p.data != null:
			c += int(p.data.children_count)
	return c


func _observer_intent_summary() -> String:
	var grow: int = 0
	var hold: int = 0
	var abandon: int = 0
	for v in IntentMemory.settlement_intent.values():
		match int(v):
			IntentMemory.INTENT_GROW:
				grow += 1
			IntentMemory.INTENT_ABANDON:
				abandon += 1
			_:
				hold += 1
	return "Grow %d | Hold %d | Abandon %d" % [grow, hold, abandon]


func _observer_war_target_label(target_id: int) -> String:
	return "None" if target_id < 0 else str(target_id)


func _observer_battlefield_mode() -> String:
	if _enemy_spawner == null or _enemy_spawner.get_enemy_count() <= 0:
		return "Idle"
	if _pawn_spawner != null:
		for p in _pawn_spawner.pawns:
			if p == null or not is_instance_valid(p) or p.data == null:
				continue
			if p.data.has_method("get_health_percentage") and float(p.data.get_health_percentage()) < 0.5:
				return "Anarchy"
	return "Ordered"


func _pawn_name_by_id(pawn_id: int) -> String:
	if pawn_id < 0:
		return "None"
	for p in get_visible_pawns():
		if p != null and is_instance_valid(p) and p.data != null and int(p.data.id) == pawn_id:
			return p.data.display_name
	if is_player_incarnated():
		return "Unknown"
	return "None"


func _find_battlemaster_name(settlement_idx: int, settlement_data: Dictionary) -> String:
	if settlement_idx < 0 or _pawn_spawner == null:
		return "None"
	var regs: Variant = settlement_data.get("regions", PackedInt32Array())
	if not (regs is PackedInt32Array):
		return "None"
	var region_set: Dictionary = {}
	for rk in regs as PackedInt32Array:
		region_set[int(rk)] = true
	for p in get_visible_pawns():
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		if str(p.data.military_rank_legacy).to_lower() != "battlemaster":
			continue
		var rk: int = _WM._region_key(p.data.tile_pos.x, p.data.tile_pos.y)
		if region_set.has(rk):
			return p.data.display_name
	return "None"


func _pretty_governance_name(raw: String) -> String:
	match raw:
		"monarchy":
			return "Monarchy"
		"council":
			return "Council"
		_:
			return "Anarchy"


func _pretty_settlement_state(raw: String) -> String:
	return raw.replace("_", " ").capitalize()


func _pretty_war_state(raw: String) -> String:
	match raw:
		"at_war":
			return "Active"
		"proposed":
			return "Proposed"
		"mobilizing":
			return "Mobilizing"
		"truce":
			return "Truce"
		_:
			return "Peace"


func _pressure_label(value: float) -> String:
	if value < 0.25:
		return "LOW"
	if value < 0.55:
		return "WATCH"
	if value < 0.8:
		return "HIGH"
	return "CRITICAL"


func _war_state_label(raw: String) -> String:
	match raw:
		"at_war":
			return "AT WAR"
		"mobilizing", "proposed":
			return "MOBILIZING"
		"truce":
			return "TRUCE"
		_:
			return "PEACE"


func _settlement_state_label(raw: String) -> String:
	match raw:
		"active":
			return "ACTIVE"
		"recovering", "revivable":
			return "RECOVERING"
		"abandoned":
			return "ABANDONED"
		"permanently_abandoned":
			return "PERMANENTLY ABANDONED"
		_:
			return "UNKNOWN"


func _observer_world_status_summary(
		war_state: String,
		settlement_state: String,
		food_pressure: float,
		housing_pressure: float,
		governance_type: String,
		ruler_name: String
) -> String:
	var war_label: String = _war_state_label(war_state)
	if war_label == "AT WAR":
		return "WORLD STATUS: War active and battle pressure elevated"
	if war_label == "MOBILIZING":
		return "WORLD STATUS: War mobilization underway"
	if _pressure_label(food_pressure) == "CRITICAL":
		return "WORLD STATUS: Severe food pressure, stability at risk"
	if _pressure_label(housing_pressure) == "CRITICAL":
		return "WORLD STATUS: Severe housing pressure, stability at risk"
	var settle_label: String = _settlement_state_label(settlement_state)
	if settle_label == "PERMANENTLY ABANDONED":
		return "WORLD STATUS: Settlement collapse is permanent"
	if settle_label == "ABANDONED":
		return "WORLD STATUS: Settlement abandoned, recovery uncertain"
	if settle_label == "RECOVERING":
		if governance_type == "anarchy" or ruler_name == "None":
			return "WORLD STATUS: Recovering settlement, no active ruler"
		return "WORLD STATUS: Recovery underway under local authority"
	if _pressure_label(food_pressure) == "HIGH" or _pressure_label(housing_pressure) == "HIGH":
		return "WORLD STATUS: Fragile peace under rising pressure"
	if governance_type != "anarchy" and ruler_name != "None":
		return "WORLD STATUS: Prosperity and order"
	return "WORLD STATUS: Fragile peace under light pressure"


# ==================== draft mode (combat control) ====================

func _toggle_draft_mode() -> void:
	_draft_mode_active = not _draft_mode_active
	if OS.is_debug_build():
		if _draft_mode_active:
			print("[Draft] DRAFT MODE ENABLED - Click pawns to select for combat (D to toggle)")
		else:
			print("[Draft] Draft mode disabled")
		# Release all drafted pawns from draft mode
		for pawn in _drafted_pawns:
			if pawn != null and is_instance_valid(pawn):
				pawn.draft_mode = false
				pawn.queue_redraw()
		_drafted_pawns.clear()


func _handle_draft_click(pawn: HeelKawnian) -> void:
	if not _draft_mode_active or pawn == null:
		return
	
	if pawn in _drafted_pawns:
		# Remove from draft
		_drafted_pawns.erase(pawn)
		pawn.draft_mode = false
		if OS.is_debug_build():
			print("[Draft] %s undrafted" % pawn.data.display_name)
	else:
		# Add to draft
		_drafted_pawns.append(pawn)
		pawn.draft_mode = true
		if OS.is_debug_build():
			print(
					"[Draft] %s drafted (now %d drafted)" % [pawn.data.display_name, _drafted_pawns.size()]
			)
	pawn.queue_redraw()
