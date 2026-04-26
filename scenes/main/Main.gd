extends Node2D
class_name Main

## Top-level scene controller. Owns input hotkeys and the startup/reroll
## sequence: world -> stockpile -> pawns -> jobs. Each step depends on the
## previous, so order here matters.

const STOCKPILE_SCENE: PackedScene = preload("res://scenes/stockpile/Stockpile.tscn")

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
# Pawn._tick_idle, which forces idle pawns onto FORAGE jobs when the
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
const BUILD_BED_PRIORITY: int = 4
const BUILD_WALL_PRIORITY: int = 5
const BUILD_DOOR_PRIORITY: int = 4

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
const GENERATION_TICKS: int = 30000
const REPRODUCTION_CHECK_INTERVAL_TICKS: int = 300
const INFLUENCE_UPDATE_INTERVAL_TICKS: int = 500
const OBSERVER_HUD_REFRESH_TICKS: int = 30
const FOCUS_INSPECTOR_REFRESH_TICKS: int = 15
## Deterministic rebirth cadence (tick-gated, no frame-time).
const REBIRTH_CHECK_INTERVAL_TICKS: int = 2000
## Ecosystems (hunt) stay inert until this tick (world gen / reroll / load).
const WORLD_STABILIZATION_TICKS: int = 500
## World-level only; Pawn/Animal read via [code]Main._world_stabilization_until_tick[/code].
## -1 = not initialized yet (hunt/tick guards treat as: allow hunt once bootstrapped sets a non-negative window).
static var _world_stabilization_until_tick: int = -1

@onready var _world: World = $WorldViewport/World
@onready var _preview_layer: Node2D = $WorldViewport/BuildPreviewOverlay
@onready var _pawn_spawner: PawnSpawner = $WorldViewport/PawnSpawner
@onready var _animal_spawner: AnimalSpawner = $WorldViewport/AnimalSpawner
@onready var _enemy_spawner: EnemySpawner = $WorldViewport/EnemySpawner
@onready var _hud: ColonyHUD = $UI_Viewport/ColonyHUD
@onready var _observer_hud: ObserverHUD = $UI_Viewport/ObserverHUD
@onready var _focus_inspector: FocusInspector = $UI_Viewport/FocusInspector
@onready var _toolbar: BuildToolbar = $UI_Viewport/BuildToolbar
@onready var _info_panel: PawnInfoPanel = $UI_Viewport/PawnInfoPanel
@onready var _day_night: DayNightCycle = $DayNight
@onready var _camera: Camera2D = $WorldViewport/Camera

# -------------------- selection --------------------
## Currently selected pawn (right-side info panel). null = nothing selected.
## Click a pawn to select; click empty ground or press Esc to deselect.
var _selected_pawn: Pawn = null
## Deterministic local-control pawn. Defaults to current selection.
var _player_pawn: Pawn = null
var _player_input: PlayerInputBuffer = null
var _player_action_state: String = "idle"
var _kernel_diagnostic: KernelDiagnostic = null
var _kill_count: int = 0
## Pixel radius around a pawn that counts as a click hit. Pawns draw at
## DRAW_RADIUS=3.5; we add a generous slop so moving targets are easy to grab.
const SELECT_PICK_RADIUS_PX: float = 7.0

# -------------------- draft mode (combat) --------------------
## Draft mode: select pawns to fight enemies. Pawns in draft mode stop normal work.
var _draft_mode_active: bool = false
var _drafted_pawns: Array[Pawn] = []
var _ambient_player: AudioStreamPlayer = null
var _ambient_playback: AudioStreamGeneratorPlayback = null
var _ambient_phase: float = 0.0
var _ambient_freq_current: float = 112.0
var _trace_redraw_timer: float = 0.0
var _ambient_freq_target: float = 112.0
## 0 = dead/empty, 1 = open/living. Drives crossfade; current region at camera.
var _meaning_ambient_mood: float = 0.5
## Settlement style expression (derived): open -> positive, defensive -> negative.
var _meaning_style_bias: float = 0.0

## Pending regrowth events. Each entry is a Dictionary:
##   { "tile": Vector2i, "feature": int (TileFeature.Type), "ready_tick": int }
## Processed every tick; tiles whose feature slot is still NONE and biome is
## still compatible get the feature back and a fresh job posted.
var _regrow_queue: Array = []
## Sim tick at which the last generational birth (or failed attempt) was processed. Serialized.
var _last_generation_tick: int = 0
## Pawns/Animals run after Main on `game_tick`; one deferred pass flushes after their `WorldMemory` writes.
var _world_memory_derivative_flush_queued: bool = false
## Coalesce same-tick [World] terrain / path cost refreshes (pair vs stack+ruins are separate).
var _last_heavy_refresh_tick: int = -1
var _last_heavy_stack_tick: int = -1

func _is_ultra_speed() -> bool:
	return GameManager.game_speed >= 12.0

func _high_speed_interval(normal_ticks: int, fast_ticks: int, ultra_ticks: int) -> int:
	if _is_ultra_speed():
		return ultra_ticks
	if GameManager.game_speed >= 6.0:
		return fast_ticks
	return normal_ticks

func _should_post_more_hunt_jobs() -> bool:
	return StockpileManager.total_count_of(Item.Type.MEAT) < HUNT_MEAT_STOCKPILE_SOFT_CAP

func _dynamic_hunt_job_budget() -> int:
	if _animal_spawner == null:
		return 1
	var live_animals: int = 0
	for a in _animal_spawner.animals:
		if a != null and is_instance_valid(a):
			live_animals += 1
	var budget: int = maxi(1, int(ceil(float(live_animals) / float(HUNT_JOB_PER_ANIMALS_DIVISOR))))
	budget = mini(budget, MAX_DYNAMIC_HUNT_JOBS_PER_PASS)
	if _is_ultra_speed():
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
enum DesignationMode { NONE, BUILD_BED, BUILD_WALL, BUILD_DOOR, DESIGNATE_ZONE }
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


func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)
	GameManager.speed_changed.connect(_on_speed_changed)
	_player_input = PlayerInputBuffer.new()
	_player_input.name = "PlayerInputBuffer"
	add_child(_player_input)
	_player_input.set_process_unhandled_input(true)
	_kernel_diagnostic = KernelDiagnostic.new()
	_kernel_diagnostic.name = "KernelDiagnostic"
	add_child(_kernel_diagnostic)
	_init_ambient_audio()
	# React to mining progress: when a wall comes down or an ore is cleared,
	# new ores can become reachable and we may want to queue the next tunnel.
	JobManager.job_completed.connect(_on_job_completed)
	# Bottom toolbar: lets the player drive everything with the mouse.
	if _toolbar != null:
		_toolbar.mode_requested.connect(_on_toolbar_mode_requested)
		_toolbar.speed_index_requested.connect(GameManager.set_speed_index)
		_toolbar.pause_toggled.connect(GameManager.toggle_pause)
		_toolbar.reroll_requested.connect(_reroll_world)
		_toolbar.zone_filter_cycle_requested.connect(_cycle_zone_filter)
		_toolbar.save_requested.connect(_colony_save)
		_toolbar.load_requested.connect(_colony_load)
		_push_zone_filter_label_to_toolbar()
	if OS.is_debug_build():
		print("[Main] Scene ready. Tick interval: %.2fs" % GameManager.TICK_INTERVAL_SECONDS)
	_bootstrap_colony()
	if _hud != null:
		_hud.set_player_control_refs(_player_input, _player_pawn)
	if _observer_hud != null:
		_observer_hud.set_visible_state(false)
	if _focus_inspector != null:
		_focus_inspector.set_visible_state(false)


func _process(delta: float) -> void:
	_meaning_ambient_mood = lerpf(
		_meaning_ambient_mood, _get_meaning_ambient_mood_target(), minf(1.0, delta * MEANING_AMBIENT_SMOOTH)
	)
	_update_camera_meaning_bias(delta)
	_update_ambient_audio(delta)
	_trace_redraw_timer += delta
	if _trace_redraw_timer >= TRACE_REDRAW_INTERVAL_SEC:
		_trace_redraw_timer = 0.0
		if has_node("WorldTrace"):
			$WorldTrace.queue_redraw()


func _on_toolbar_mode_requested(mode: int) -> void:
	# Toolbar mode ints match Main.DesignationMode by construction.
	_set_designation_mode(mode)


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
	_place_stockpile(main_component)
	_pawn_spawner.spawn_starters(_world, main_component)
	if is_instance_valid(_world):
		_world.apply_ruins_from_persistence()
		CulturalMemory.recompute(_world)
		SettlementMemory.recompute(_world)
		MythMemory.recompute(_world)
		SacredMemory.sync_permanent_ruins_from_settlements()
		_run_heavy_refresh_once_per_tick(func() -> void:
			if is_instance_valid(_world):
				_world.refresh_terrain_scar_tint()
				_world.refresh_pawn_historic_path_weights()
		)
		SettlementPlanner.plan(_world, self, true)
		TradePlanner.plan(_world, self, true)
		RoadMemory.flush_dirty_tiles(_world)
		_sync_pawn_inherited_cultural_reputation()
	# Spawn animals and register spawner with world for breeding
	_animal_spawner.spawn_initial(_world)
	_world.set_meta("animal_spawner", _animal_spawner)
	Main._world_stabilization_until_tick = GameManager.tick_count + WORLD_STABILIZATION_TICKS
	_seed_jobs_from_world()
	# Seed initial tunneling toward sealed ore.
	_react_to_mining_progress()
	if _hud != null:
		_hud.bind(_world, _pawn_spawner)
	_last_generation_tick = GameManager.tick_count
	RemnantMemory.clear()
	AgeMemory.clear()
	if is_instance_valid(_world):
		RemnantMemory.seed_births_from_current_world(_world)
		IntentMemory.recompute(_world)


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
		push_error("[Main] Could not find a tile on the main component to place the stockpile.")
		return
	var seed_rect: Rect2i = _fit_seed_stockpile_rect(tile, main_component, 3, 3)
	var sp: Stockpile = STOCKPILE_SCENE.instantiate()
	sp.set_filter(Stockpile.Filter.ALL)
	sp.set_rect_tiles(seed_rect)
	sp.position = _world.tile_to_world(seed_rect.position)
	add_child(sp)
	_world.stockpile = sp
	StockpileManager.register(sp)
	if OS.is_debug_build():
		print(
				"[Main] Seed stockpile placed at %s (%dx%d, ALL)" %
				[seed_rect.position, seed_rect.size.x, seed_rect.size.y]
		)


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


func _on_game_tick(tick: int) -> void:
	if _player_input != null:
		if is_instance_valid(_player_pawn):
			_player_input.process_next_tick(_player_pawn)
			_player_action_state = _player_input.get_last_action_state()
		else:
			_player_action_state = "no_pawn"
	# First tick of post-stab window: (re)post HUNT for static wildlife skipped during [member _world_stabilization_until_tick] seed; deterministic order.
	if Main._world_stabilization_until_tick >= 0 and tick == Main._world_stabilization_until_tick:
		_post_wildlife_hunt_jobs_after_stabilization()
	if (
			_animal_spawner != null
			and int(tick) % AnimalSpawner.POPULATION_CHECK_TICKS == 0
	):
		_animal_spawner.update_population_dynamics(_world)
	_process_regrowth(tick)
	_update_ambient_target()
	# Post dynamic hunt jobs less aggressively than harvest loops.
	var hunt_post_interval: int = _high_speed_interval(20, 30, 45)
	if (
			tick % hunt_post_interval == 0
			and Main._world_stabilization_until_tick >= 0
			and tick >= Main._world_stabilization_until_tick
	):
		_post_hunting_jobs_for_animals()
	# Enemy AI and raid spawning
	_on_enemy_tick(tick, _enemy_spawner)
	# Suppress hot-loop tick spam; this is a major source of debug-mode stutter.
	# Failsafe: pawns that slipped into solid tiles (rare) get nudged; log once per pawn.
	if tick % 60 == 0 and _pawn_spawner != null:
		for p in _pawn_spawner.pawns:
			if p != null and is_instance_valid(p):
				p.sanity_check_impassable_tile()
	# WorldMemory-derived recompute: defer once so Pawn/Animal (connected after Main) can record first.
	if is_instance_valid(_world) and not _world_memory_derivative_flush_queued:
		_world_memory_derivative_flush_queued = true
		call_deferred("_flush_world_memory_derivatives")
	if is_instance_valid(_world):
		var planner_interval: int = _high_speed_interval(1, 2, 4)
		if tick % planner_interval == 0:
			SettlementPlanner.plan(_world, self, false)
			TradePlanner.plan(_world, self, false)
		if tick % REBIRTH_CHECK_INTERVAL_TICKS == 0:
			SettlementMemory.recompute(_world)
			SettlementRebirth.process(_world, self, false)
	if int(tick) % 10000 == 0 and int(tick) > 0:
		AgeMemory.recompute()
		if is_instance_valid(_world):
			IntentMemory.recompute(_world)
	_maybe_generational_turnover()
	if tick % REPRODUCTION_CHECK_INTERVAL_TICKS == 0:
		_process_reproduction_tick()
	if tick % INFLUENCE_UPDATE_INTERVAL_TICKS == 0:
		_update_pawn_influence_tick()
	SettlementMemory.update_settlement_intents(tick)
	SettlementMemory.update_preferred_work_fronts(tick)
	if _observer_hud != null and _observer_hud.is_visible_state() and tick % OBSERVER_HUD_REFRESH_TICKS == 0:
		_observer_hud.apply_snapshot(_build_observer_snapshot(tick))
	if _focus_inspector != null and _focus_inspector.is_visible_state() and tick % FOCUS_INSPECTOR_REFRESH_TICKS == 0:
		_focus_inspector.apply_snapshot(_build_focus_snapshot(tick))
	if is_instance_valid(_world):
		call_deferred("_flush_road_memory_dirty_tiles")


func _flush_road_memory_dirty_tiles() -> void:
	if is_instance_valid(_world):
		RoadMemory.flush_dirty_tiles(_world)


func _flush_world_memory_derivatives() -> void:
	_world_memory_derivative_flush_queued = false
	if not is_instance_valid(_world) or not WorldMemory.consume_dirty():
		return
	WorldMeaning.recompute()
	WorldPersistence.recompute()
	CulturalMemory.recompute(_world)
	MythMemory.recompute(_world)
	SacredMemory.sync_permanent_ruins_from_settlements()
	IntentMemory.recompute(_world)
	_run_heavy_stack_refresh_once_per_tick(func() -> void:
		if is_instance_valid(_world):
			_world.refresh_terrain_scar_tint()
			_world.apply_ruins_from_persistence()
			_world.refresh_pawn_historic_path_weights()
	)
	SettlementPlanner.plan(_world, self, true)
	TradePlanner.plan(_world, self, true)
	RoadMemory.flush_dirty_tiles(_world)


func _maybe_generational_turnover() -> void:
	if _pawn_spawner == null or not is_instance_valid(_world) or _world.data == null:
		return
	var alive: int = 0
	for p in _pawn_spawner.pawns:
		if p != null and is_instance_valid(p):
			alive += 1
	if alive == 0:
		return
	var t: int = GameManager.tick_count
	if t - _last_generation_tick < GENERATION_TICKS:
		return
	var sp: Vector2i = _find_generational_spawn_tile()
	_last_generation_tick = t
	if sp.x < 0:
		return
	_pawn_spawner.spawn_generational_pawn(_world, sp, t)


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
	var living: Array[Pawn] = []
	for p in _pawn_spawner.pawns:
		if p != null and is_instance_valid(p) and p.data != null:
			living.append(p)
	var population: int = living.size()
	for p in living:
		p.data.calculate_influence(population)


## Best region: max [CulturalMemory] reputation, then min [WorldPersistence] scar, then lowest region_key.
## Tile: first passable plains/forest on main landmass, row-major within that region, not occupied.
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
			var rk: int = WorldMemory._region_key(x0, y0)
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


func _get_meaning_ambient_mood_target() -> float:
	if not is_instance_valid(_world) or _camera == null or _world.data == null:
		_meaning_style_bias = 0.0
		return 0.5
	var t: Vector2i = _world.world_to_tile(_camera.global_position)
	if t.x < 0:
		_meaning_style_bias = 0.0
		return 0.5
	var rk: int = WorldMemory._region_key(t.x, t.y)
	var m: float
	var sv: Variant = SettlementMemory.get_settlement_at_region(rk)
	var st_here: String = ""
	var intent_here: int = IntentMemory.INTENT_HOLD
	if sv is Dictionary:
		_meaning_style_bias = SettlementPlanner.get_culture_audio_bias_for_settlement(sv as Dictionary)
		st_here = str((sv as Dictionary).get("state", ""))
		var ckr_here: int = int((sv as Dictionary).get("center_region", -1))
		intent_here = int(IntentMemory.settlement_intent.get(ckr_here, IntentMemory.INTENT_HOLD))
		if st_here == "permanently_abandoned":
			m = 0.0
		elif st_here == "abandoned":
			m = 0.15
		elif st_here == "revivable":
			m = 0.92
		elif st_here == "dormant":
			m = 0.46
		else:
			m = 0.5
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
		var rk0: int = WorldMemory._region_key(t0.x, t0.y)
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
	vel = vel.limit_length(MEANING_CAM_VEL_MAX)
	_camera.position += vel * delta


func _update_ambient_audio(delta: float) -> void:
	if _ambient_playback == null:
		return
	var frames: int = _ambient_playback.get_frames_available()
	if frames <= 0:
		return
	var interp: float = min(1.0, delta * 2.6)
	_ambient_freq_current = lerpf(_ambient_freq_current, _ambient_freq_target, interp)
	var mood: float = _meaning_ambient_mood
	var style_mix: float = clampf(_meaning_style_bias, -0.2, 0.2)
	var base_layer: float = lerpf(0.82, 0.64, 1.0 - mood) + style_mix * -0.18
	var otone_layer: float = lerpf(0.16, 0.34, mood) + style_mix * 0.2
	base_layer = clampf(base_layer, 0.52, 0.9)
	otone_layer = clampf(otone_layer, 0.1, 0.42)
	var amp: float = AMBIENT_BASE_AMP * lerpf(0.62, 1.0, mood)
	if GameManager.is_paused:
		amp *= 0.45
	if _ambient_player != null:
		_ambient_player.volume_db = lerpf(-24.0, -18.5, mood)
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
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			GameManager.toggle_pause()
		KEY_1:
			GameManager.set_speed_index(0)
		KEY_2:
			GameManager.set_speed_index(1)
		KEY_3:
			GameManager.set_speed_index(2)
		KEY_4:
			GameManager.set_speed_index(3)
		KEY_5:
			GameManager.set_speed_index(4)
		KEY_6:
			GameManager.set_speed_index(5)
		KEY_R:
			_reroll_world()
		KEY_T:
			_pawn_spawner.print_stats()
		KEY_J:
			JobManager.print_debug()
		KEY_I:
			_print_stockpile()
		KEY_D:
			_toggle_draft_mode()
		KEY_B:
			# Shift+B is the legacy "stamp 5 beds near the stockpile" shortcut,
			# kept for quick demos. Plain B enters bed-designation mode.
			if event.shift_pressed:
				_designate_beds_near_stockpile()
			else:
				_toggle_designation_mode(DesignationMode.BUILD_BED)
		KEY_W:
			_toggle_designation_mode(DesignationMode.BUILD_WALL)
		KEY_O:
			_toggle_designation_mode(DesignationMode.BUILD_DOOR)
		KEY_Z:
			_toggle_designation_mode(DesignationMode.DESIGNATE_ZONE)
		KEY_F:
			_cycle_zone_filter()
		KEY_F5:
			_colony_save()
		KEY_F8:
			_colony_load()
		KEY_F9:
			_toggle_observer_hud()
		KEY_F10:
			_toggle_focus_inspector()
		KEY_M:
			ColonySimServices.cycle_labor_stance()
		KEY_ESCAPE:
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
		KEY_HOME:
			if _camera != null and _camera.has_method("reset_to_world_bounds"):
				_camera.call("reset_to_world_bounds", _world)


func _unhandled_input(event: InputEvent) -> void:
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
						_designation_mode_label(_designation_mode),
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
	if _designation_mode == mode:
		_set_designation_mode(DesignationMode.NONE)
	else:
		_set_designation_mode(mode)


func _set_designation_mode(mode: int) -> void:
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
					_designation_mode_label(mode)
			)
	_update_wall_path_preview()
	_queue_designation_redraw()


static func _designation_mode_label(mode: int) -> String:
	match mode:
		DesignationMode.BUILD_BED:     return "Bed"
		DesignationMode.BUILD_WALL:    return "Wall"
		DesignationMode.BUILD_DOOR:    return "Door"
		DesignationMode.DESIGNATE_ZONE: return "Zone"
	return ""


func _handle_select_click_at(world_pos: Vector2) -> void:
	# Pick the visually-closest pawn within SELECT_PICK_RADIUS_PX. We use
	# the pawn's actual global_position (not data.tile_pos) so a pawn that
	# is currently between tiles is still selectable.
	if _pawn_spawner == null:
		_set_selected_pawn(null)
		return
	var best: Pawn = null
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


func _set_selected_pawn(p: Pawn) -> void:
	if _selected_pawn == p:
		return
	if _selected_pawn != null and is_instance_valid(_selected_pawn):
		_selected_pawn.is_selected = false
		_selected_pawn.queue_redraw()
	_selected_pawn = p
	_player_pawn = _selected_pawn
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


func get_player_queue_size() -> int:
	if _player_input == null:
		return 0
	return _player_input.get_queue_size()


func get_player_action_state() -> String:
	return _player_action_state


func get_player_pawn_id() -> int:
	if _player_pawn == null or not is_instance_valid(_player_pawn) or _player_pawn.data == null:
		return -1
	return int(_player_pawn.data.id)


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
	var rk: int = WorldMemory._region_key(_player_pawn.data.tile_pos.x, _player_pawn.data.tile_pos.y)
	var gov: Dictionary = SettlementMemory.get_governance_profile_for_region(rk)
	var gtype: String = str(gov.get("type", "anarchy"))
	var rid: int = int(gov.get("ruler_id", -1))
	var ruler_name: String = "None"
	if rid >= 0 and _pawn_spawner != null:
		for p in _pawn_spawner.pawns:
			if p != null and is_instance_valid(p) and p.data != null and int(p.data.id) == rid:
				ruler_name = p.data.display_name
				break
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
	var rk: int = WorldMemory._region_key(_player_pawn.data.tile_pos.x, _player_pawn.data.tile_pos.y)
	return SettlementMemory.get_war_profile_for_region(rk)


func get_player_military_rank() -> String:
	if _player_pawn == null or not is_instance_valid(_player_pawn) or _player_pawn.data == null:
		return "grunt"
	return String(_player_pawn.data.military_rank)


func get_wildlife_snapshot_for_diagnostic() -> Dictionary:
	if _animal_spawner == null:
		return {"rabbit": 0, "deer": 0, "total": 0}
	return _animal_spawner.get_live_wildlife_snapshot()


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
		DesignationMode.BUILD_BED:  return TileFeature.Type.BED
		DesignationMode.BUILD_WALL: return TileFeature.Type.WALL
		DesignationMode.BUILD_DOOR: return TileFeature.Type.DOOR
	return TileFeature.Type.NONE


func _reroll_world() -> void:
	JobManager.clear_all()
	WorldMemory.clear()
	MythMemory.clear()
	SacredMemory.clear()
	ChronicleLog.clear()
	RoadMemory.clear()
	TradeMemory.clear()
	IntentMemory.clear()
	AgeMemory.clear()
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
	_world.generate(randi())
	if is_instance_valid(_world):
		_world.apply_ruins_from_persistence()
		CulturalMemory.recompute(_world)
		SettlementMemory.recompute(_world)
		MythMemory.recompute(_world)
		_run_heavy_refresh_once_per_tick(func() -> void:
			if is_instance_valid(_world):
				_world.refresh_terrain_scar_tint()
				_world.refresh_pawn_historic_path_weights()
		)
	var main_component: int = _world.pathfinder.largest_component_id()
	# Place the stockpile BEFORE respawning pawns, so every pawn sees a valid
	# stockpile reference the first time it ticks.
	_place_stockpile(main_component)
	_pawn_spawner.respawn(_world, main_component)
	Main._world_stabilization_until_tick = GameManager.tick_count + WORLD_STABILIZATION_TICKS
	_seed_jobs_from_world()
	_react_to_mining_progress()
	if _hud != null:
		_hud.bind(_world, _pawn_spawner)
	_last_generation_tick = GameManager.tick_count
	_world.set_meta("animal_spawner", _animal_spawner)
	if is_instance_valid(_world):
		IntentMemory.recompute(_world)
		SettlementPlanner.plan(_world, self, true)
		TradePlanner.plan(_world, self, true)
		RoadMemory.flush_dirty_tiles(_world)
		RemnantMemory.clear()
		RemnantMemory.seed_births_from_current_world(_world)


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
	forage_tiles.shuffle()
	mine_tiles.shuffle()
	chop_tiles.shuffle()
	hunt_tiles.shuffle()
	var forage_posted: int = 0
	var forage_skipped: int = 0
	var mine_posted: int = 0
	var mine_skipped: int = 0
	var chop_posted: int = 0
	var chop_skipped: int = 0
	var hunt_posted: int = 0
	var hunt_skipped: int = 0
	for tile in forage_tiles:
		if forage_posted >= MAX_FORAGE_JOBS:
			break
		if _world.pathfinder.component_of(tile) != main_component:
			forage_skipped += 1
			continue
		JobManager.post(Job.Type.FORAGE, tile, FORAGE_PRIORITY, FORAGE_WORK_TICKS)
		forage_posted += 1
	for tile in mine_tiles:
		if mine_posted >= MAX_MINE_JOBS:
			break
		var work_tile: Vector2i = _world.pathfinder.find_adjacent_passable(tile)
		if work_tile.x < 0 or _world.pathfinder.component_of(work_tile) != main_component:
			mine_skipped += 1
			continue
		var job: Job = JobManager.post(Job.Type.MINE, tile, MINE_PRIORITY, MINE_WORK_TICKS)
		if job == null:
			continue
		job.work_tile = work_tile
		mine_posted += 1
	# CHOP: trees stand on passable tiles, so work_tile = the tree tile itself
	# (forage-style). The pawn walks onto the tree to chop it.
	for tile in chop_tiles:
		if chop_posted >= MAX_CHOP_JOBS:
			break
		if _world.pathfinder.component_of(tile) != main_component:
			chop_skipped += 1
			continue
		JobManager.post(Job.Type.CHOP, tile, CHOP_PRIORITY, CHOP_WORK_TICKS)
		chop_posted += 1
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
			JobManager.post(Job.Type.HUNT, tile, HUNT_PRIORITY, _hunt_ticks_for(feat))
			live_seed[species_seed] = maxi(0, live_now_seed - 1)
			hunt_posted += 1
	if OS.is_debug_build():
		print(
				"[Main] Seeded jobs: %d forage, %d mine, %d chop, %d hunt  (pool: %d fertile / %d ore / %d tree / %d wildlife; skipped: F%d M%d C%d H%d off-mainland)" %
				[forage_posted, mine_posted, chop_posted, hunt_posted,
					forage_tiles.size(), mine_tiles.size(), chop_tiles.size(), hunt_tiles.size(),
					forage_skipped, mine_skipped, chop_skipped, hunt_skipped]
		)


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
		if JobManager.post(Job.Type.HUNT, t, HUNT_PRIORITY, _hunt_ticks_for(feat2)) != null:
			live_bootstrap[species_bootstrap] = maxi(0, live_now_bootstrap - 1)
			n += 1


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
	var hunt_budget: int = _dynamic_hunt_job_budget()
	var hunt_jobs_posted: int = 0
	var live_by_species: Dictionary = _live_wildlife_counts()
	
	for animal in _animal_spawner.animals:
		if not is_instance_valid(animal) or animal == null:
			continue
		
		var tile: Vector2i = animal.tile_pos
		if _world.pathfinder.component_of(tile) != main_component:
			continue
		
		# If no job (any type) is registered for this tile, `post` can add a HUNT
		# job; `has_job_at` matches JobManager's internal tile index (open + claimed).
		if not JobManager.has_job_at(tile) and hunt_jobs_posted < hunt_budget:
			var animal_type: int = animal.animal_type
			var live_now: int = int(live_by_species.get(animal_type, 0))
			if live_now <= _hunt_reserve_for_species(animal_type):
				continue
			var work_ticks: int = HUNT_RABBIT_WORK_TICKS if animal_type == Animal.Type.RABBIT else HUNT_DEER_WORK_TICKS
			if JobManager.post(Job.Type.HUNT, tile, HUNT_PRIORITY, work_ticks) != null:
				live_by_species[animal_type] = maxi(0, live_now - 1)
				hunt_jobs_posted += 1


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
	match job.type:
		Job.Type.BUILD_BED, Job.Type.BUILD_WALL, Job.Type.BUILD_DOOR:
			if has_node("WorldTrace") and _world != null:
				var wt: WorldTrace = $WorldTrace as WorldTrace
				if wt != null:
					wt.record_trace(_world.tile_to_world(job.tile), "build")
		Job.Type.MINE, Job.Type.MINE_WALL:
			_react_to_mining_progress()
		Job.Type.FORAGE:
			_queue_regrowth(job.tile, TileFeature.Type.FERTILE_SOIL, FORAGE_REGROW_TICKS)
		Job.Type.CHOP:
			_queue_regrowth(job.tile, TileFeature.Type.TREE, TREE_REGROW_TICKS)
		Job.Type.HUNT:
			# By the time we get here Pawn._complete_current_job has already
			# cleared the feature, so we can't read the species off the tile
			# anymore. We use the job's planned work_ticks_needed as a proxy:
			# deer hunts are scheduled longer than rabbit hunts, so >= the
			# deer threshold means it was a deer. Cheap, robust, and good
			# enough until we add explicit per-job metadata.
			var species: int = TileFeature.Type.DEER \
				if job.work_ticks_needed >= HUNT_DEER_WORK_TICKS \
				else TileFeature.Type.RABBIT
			_queue_regrowth(job.tile, species, _regrow_ticks_for(species))


# ==================== regrowth ====================

func _queue_regrowth(tile: Vector2i, feature: int, delay_ticks: int) -> void:
	_regrow_queue.append({
		"tile": tile,
		"feature": feature,
		"ready_tick": GameManager.tick_count + delay_ticks,
	})


## Walk the regrow queue and resurrect any feature whose timer has expired.
## Iterating backwards so we can remove in place.
func _process_regrowth(tick: int) -> void:
	if _regrow_queue.is_empty():
		return
	var i: int = _regrow_queue.size() - 1
	while i >= 0:
		var entry: Dictionary = _regrow_queue[i]
		if entry.ready_tick <= tick:
			_restore_feature(entry.tile, entry.feature)
			_regrow_queue.remove_at(i)
		i -= 1


## Re-place a feature on its original tile, then post the matching job so a
## pawn will harvest it again. Skips silently if the tile is no longer a
## valid host (something else built there, biome was mined out, etc.).
func _restore_feature(tile: Vector2i, feature: int) -> void:
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
	var main_component: int = _world.pathfinder.largest_component_id()
	if _world.pathfinder.component_of(tile) != main_component:
		return
	if JobManager.has_job_at(tile):
		return
	match feature:
		TileFeature.Type.FERTILE_SOIL:
			JobManager.post(Job.Type.FORAGE, tile, FORAGE_PRIORITY, FORAGE_WORK_TICKS)
		TileFeature.Type.TREE:
			JobManager.post(Job.Type.CHOP, tile, CHOP_PRIORITY, CHOP_WORK_TICKS)
		TileFeature.Type.RABBIT, TileFeature.Type.DEER:
			if (
					Main._world_stabilization_until_tick >= 0
					and GameManager.tick_count < Main._world_stabilization_until_tick
			):
				return
			JobManager.post(Job.Type.HUNT, tile, HUNT_PRIORITY, _hunt_ticks_for(feature))


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
func _react_to_mining_progress() -> void:
	var pf: PathFinder = _world.pathfinder
	var main_component: int = pf.largest_component_id()
	if main_component < 0:
		return

	# 1. Newly-reachable ore -> MINE jobs.
	var newly_minable: int = 0
	for y in range(WorldData.HEIGHT):
		for x in range(WorldData.WIDTH):
			var f: int = _world.data.get_feature(x, y)
			if f != TileFeature.Type.ORE_VEIN:
				continue
			var ore_tile := Vector2i(x, y)
			if JobManager.has_job_at(ore_tile):
				continue
			var work_tile: Vector2i = pf.find_adjacent_passable(ore_tile)
			if work_tile.x < 0 or pf.component_of(work_tile) != main_component:
				continue
			var job: Job = JobManager.post(Job.Type.MINE, ore_tile, MINE_PRIORITY, MINE_WORK_TICKS)
			if job == null:
				continue
			job.work_tile = work_tile
			newly_minable += 1

	# 2. Top up MINE_WALL jobs up to the cap, each aimed at a different sealed ore.
	var active_walls: int = JobManager.active_count_of_type(Job.Type.MINE_WALL)
	var posted_walls: int = 0
	while active_walls < MAX_ACTIVE_MINE_WALL_JOBS:
		var wall_tile: Vector2i = _find_next_tunnel_target(main_component)
		if wall_tile.x < 0:
			break
		# work_tile = a passable main-component neighbor of the wall tile.
		var work_tile: Vector2i = _find_main_component_neighbor(wall_tile, main_component)
		if work_tile.x < 0:
			break
		var job: Job = JobManager.post(Job.Type.MINE_WALL, wall_tile, MINE_WALL_PRIORITY, MINE_WALL_WORK_TICKS)
		if job == null:
			break  # tile already has a job (defensive); stop to avoid an infinite loop
		job.work_tile = work_tile
		active_walls += 1
		posted_walls += 1

	if newly_minable > 0 or posted_walls > 0:
		if OS.is_debug_build():
			print(
					"[Main] React: +%d MINE  +%d MINE_WALL  (active walls=%d)" % [
						newly_minable, posted_walls, active_walls
					]
			)


## Multi-source BFS starting from every still-sealed ORE_VEIN, expanding only
## through MOUNTAIN tiles. The first time the frontier touches a tile in
## main_component we know the previous (mountain) tile is the wall to mine
## next. Returns Vector2i(-1,-1) if there are no sealed ores or none can be
## tunneled to.
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
					[posted, center.x, center.y, Pawn.BED_WOOD_COST]
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
		var pd: PawnData = p.get_pawn_data() as PawnData
		if pd == null:
			continue
		var rk: int = WorldMemory._region_key(pd.tile_pos.x, pd.tile_pos.y)
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

func _colony_save() -> void:
	var snapshot: Dictionary = _build_save_dict()
	var err: Error = GameSave.write_file(GameSave.get_save_path(), snapshot)
	if err == OK:
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
	if OS.is_debug_build():
		print("[Main] Loaded colony from %s" % GameSave.get_save_path())


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
		"world": _world.data.to_save_dict(),
		"zones": _save_stockpiles_to_array(),
		"pawns": pawns_s,
		"regrow": _save_regrow_queue(),
		"zone_filter": _zone_next_filter,
		"world_memory": WorldMemory.to_save_dict(),
		"world_persistence": WorldPersistence.to_save_dict(),
		"myth": MythMemory.to_save_dict(),
		"sacred": SacredMemory.to_save_dict(),
		"chronicle": ChronicleLog.to_save_dict(),
		"last_generation_tick": _last_generation_tick,
	}


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
	for e in _regrow_queue:
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
	TradeMemory.clear()
	RemnantMemory.clear()
	IntentMemory.clear()
	AgeMemory.clear()
	SacredMemory.clear()
	ChronicleLog.clear()
	_set_designation_mode(DesignationMode.NONE)
	_cancel_drag()
	_set_selected_pawn(null)
	_regrow_queue.clear()
	_tear_down_all_zones()
	_pawn_spawner.clear_pawns()

	_world.load_world_data(wdata as WorldData)
	var loaded_tick: int = int(s.get("tick", 0))
	GameManager.set_state_from_load(
		loaded_tick,
		float(s.get("game_speed", 1.0)),
		bool(s.get("is_paused", false))
	)
	_last_generation_tick = int(s.get("last_generation_tick", loaded_tick))
	_zone_next_filter = int(s.get("zone_filter", 0))
	WorldMemory.from_save_dict(s.get("world_memory", {}))
	MythMemory.from_save_dict(s.get("myth", {}))
	SacredMemory.from_save_dict(s.get("sacred", {}))
	ChronicleLog.from_save_dict(s.get("chronicle", {}))
	WorldMeaning.recompute()
	WorldPersistence.from_save_dict(s.get("world_persistence", {}))
	WorldPersistence.recompute()
	_push_zone_filter_label_to_toolbar()
	var zlist: Array = s.get("zones", [])
	if zlist is Array and not zlist.is_empty():
		_restore_stockpiles_from_save(zlist)
	else:
		_place_stockpile(_world.pathfinder.largest_component_id())
	PawnData._next_id = 1
	for pd in s.get("pawns", []):
		if pd is Dictionary:
			var pdat: PawnData = PawnData.from_save_dict(pd)
			_pawn_spawner.spawn_from_data(pdat, _world)
	_world.set_meta("animal_spawner", _animal_spawner)
	if is_instance_valid(_world):
		_world.apply_ruins_from_persistence()
		CulturalMemory.recompute(_world)
		SettlementMemory.recompute(_world)
		MythMemory.recompute(_world)
		SacredMemory.sync_permanent_ruins_from_settlements()
		IntentMemory.recompute(_world)
		_run_heavy_refresh_once_per_tick(func() -> void:
			if is_instance_valid(_world):
				_world.refresh_terrain_scar_tint()
				_world.refresh_pawn_historic_path_weights()
		)
		SettlementPlanner.plan(_world, self, true)
		TradePlanner.plan(_world, self, true)
		RoadMemory.flush_dirty_tiles(_world)
		_sync_pawn_inherited_cultural_reputation()
		RemnantMemory.seed_births_from_current_world(_world)
	_regrow_queue.clear()
	for e in s.get("regrow", []):
		if e is Dictionary:
			_regrow_queue.append({
				"tile": Vector2i(int(e.get("tile_x", 0)), int(e.get("tile_y", 0))),
				"feature": int(e.get("feature", 0)),
				"ready_tick": int(e.get("ready_tick", 0)),
			})
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


func _build_focus_snapshot(tick: int) -> Dictionary:
	var focus: Dictionary = _resolve_focus_target()
	var focus_type: String = str(focus.get("type", "NONE"))
	var main_lines: PackedStringArray = PackedStringArray()
	var title: String = "FOCUS INSPECTOR"
	if focus_type == "PAWN":
		title = "FOCUS: PAWN"
		main_lines = _focus_lines_for_pawn(focus)
	elif focus_type == "SETTLEMENT":
		title = "FOCUS: SETTLEMENT"
		main_lines = _focus_lines_for_settlement(focus)
	elif focus_type == "TILE":
		title = "FOCUS: TILE"
		main_lines = _focus_lines_for_tile(focus)
	else:
		main_lines = PackedStringArray([
			"NO FOCUS",
			"Move cursor over a pawn, settlement, or tile",
		])
	return {
		"title": title,
		"focus_type": focus_type,
		"main_lines": main_lines,
		"footer": "Tick %d | source: %s" % [tick, str(focus.get("source", "none"))],
	}


func _resolve_focus_target() -> Dictionary:
	if _world == null:
		return {"type": "NONE", "source": "none"}
	var mouse_world: Vector2 = get_global_mouse_position()
	var mouse_pawn: Pawn = _focus_pawn_under_world_pos(mouse_world)
	if mouse_pawn != null and mouse_pawn.data != null:
		return {"type": "PAWN", "source": "mouse_pawn", "pawn": mouse_pawn}
	var mouse_tile: Vector2i = _world.world_to_tile(mouse_world)
	if mouse_tile.x >= 0 and mouse_tile.y >= 0:
		var settlement: Variant = SettlementMemory.get_settlement_at_region(WorldMemory._region_key(mouse_tile.x, mouse_tile.y))
		if settlement is Dictionary:
			return {"type": "SETTLEMENT", "source": "mouse_tile", "tile": mouse_tile, "settlement": settlement}
		return {"type": "TILE", "source": "mouse_tile", "tile": mouse_tile}
	var cam_tile: Vector2i = _world.world_to_tile(_camera.global_position) if _camera != null else Vector2i(-1, -1)
	if cam_tile.x >= 0 and cam_tile.y >= 0:
		return {"type": "TILE", "source": "camera_center", "tile": cam_tile}
	return {"type": "NONE", "source": "none"}


func _focus_pawn_under_world_pos(world_pos: Vector2) -> Pawn:
	if _pawn_spawner == null:
		return null
	var best: Pawn = null
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
	var p: Pawn = focus.get("pawn", null) as Pawn
	if p == null or p.data == null:
		return PackedStringArray(["NO FOCUS", "Move cursor over a pawn, settlement, or tile"])
	var d: PawnData = p.data
	var rk: int = WorldMemory._region_key(d.tile_pos.x, d.tile_pos.y)
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
	out.append("Profession: %s | Military Rank: %s" % [d.profession_name(), String(d.military_rank).capitalize()])
	out.append("Governance Role: %s" % role)
	out.append("Health: %d%% | Hunger %.0f | Rest %.0f | Mood %.0f" % [health_pct, d.hunger, d.rest, d.mood])
	out.append("Action: %s | Job: %s" % [state_label, job_label])
	out.append("Settlement State: %s | War: %s" % [settlement_label, _pretty_war_state(str(war.get("state", "peace")))])
	out.append("Battlefield Posture: %s" % local_mode)
	return out


func _focus_lines_for_settlement(focus: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var tile: Vector2i = focus.get("tile", Vector2i(-1, -1))
	var st: Dictionary = focus.get("settlement", {})
	var center: int = int(st.get("center_region", -1))
	var gov: Dictionary = SettlementMemory.get_governance_profile_for_region(center)
	var war: Dictionary = SettlementMemory.get_war_profile_for_region(center)
	out.append("Region: %d | Tile: (%d,%d)" % [center, tile.x, tile.y])
	out.append("Settlement State: %s" % _pretty_settlement_state(str(st.get("state", "unknown"))))
	out.append("Governance: %s | Ruler: %s" % [
		_pretty_governance_name(str(gov.get("type", "anarchy"))),
		_pawn_name_by_id(int(gov.get("ruler_id", -1)))
	])
	var pop: int = _count_pawns_in_regions(st.get("regions", PackedInt32Array()))
	out.append("Population: %d | Council Size: %d" % [pop, (gov.get("council_ids", PackedInt32Array()) as PackedInt32Array).size() if gov.get("council_ids", PackedInt32Array()) is PackedInt32Array else 0])
	out.append("War: %s | Target: %s" % [_pretty_war_state(str(war.get("state", "peace"))), _observer_war_target_label(int(war.get("target_settlement_id", -1)))])
	out.append("Food Pressure: %d%% | Housing Pressure: %d%%" % [
		int(round(ColonySimServices.get_food_pressure() * 100.0)),
		int(round(ColonySimServices.get_housing_pressure() * 100.0)),
	])
	return out


func _focus_lines_for_tile(focus: Dictionary) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var tile: Vector2i = focus.get("tile", Vector2i(-1, -1))
	if tile.x < 0:
		return PackedStringArray(["NO FOCUS", "Move cursor over a pawn, settlement, or tile"])
	var rk: int = WorldMemory._region_key(tile.x, tile.y)
	out.append("Tile: (%d,%d) | Region: %d" % [tile.x, tile.y, rk])
	var biome: int = _world.data.get_biome(tile.x, tile.y) if _world != null and _world.data != null else -1
	out.append("Biome: %d | Scar: %d" % [biome, int(WorldPersistence.get_region_persistence(rk).get("scar_level", 0))])
	var st_v: Variant = SettlementMemory.get_settlement_at_region(rk)
	if st_v is Dictionary:
		var st: Dictionary = st_v as Dictionary
		var center: int = int(st.get("center_region", -1))
		var gov: Dictionary = SettlementMemory.get_governance_profile_for_region(center)
		out.append("Settlement: %s | Governance: %s" % [
			_pretty_settlement_state(str(st.get("state", "unknown"))),
			_pretty_governance_name(str(gov.get("type", "anarchy")))
		])
	var events: Array[Dictionary] = WorldMemory.get_events_for_tile(tile)
	if not events.is_empty():
		var evt: Dictionary = events[events.size() - 1]
		var etype: String = str(evt.get("type", "event"))
		out.append("Last Event: %s @ tick %d" % [etype.replace("_", " "), int(evt.get("t", 0))])
	return out


func _pawn_governance_role(d: PawnData, gov: Dictionary) -> String:
	var pid: int = int(d.id)
	if int(gov.get("ruler_id", -1)) == pid:
		return "Ruler"
	var council_ids: Variant = gov.get("council_ids", PackedInt32Array())
	if council_ids is PackedInt32Array and (council_ids as PackedInt32Array).has(pid):
		return "Council"
	if String(d.military_rank).to_lower() == "battlemaster":
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
		var rk: int = WorldMemory._region_key(p.data.tile_pos.x, p.data.tile_pos.y)
		if wanted.has(rk):
			n += 1
	return n


func _build_observer_snapshot(tick: int) -> Dictionary:
	var day_len: int = DayNightCycle.TICKS_PER_DAY
	var day: int = int(tick / float(day_len)) + 1
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
	var war_state_raw: String = str(war.get("state", "peace"))
	var settlement_state_raw: String = str(settlement_data.get("state", "unknown"))
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
	var footer_stamp: String = "Tick %d | Day %d | Determinism %s | Events %d | %s" % [
		tick,
		day,
		determinism_lock,
		WorldMemory.event_count(),
		kernel_phase,
	]
	return {
		"tick": tick,
		"day": day,
		"speed": speed_text,
		"paused": paused_text,
		"world_status_summary": world_status_summary,
		"governance_type": _pretty_governance_name(str(governance.get("type", "anarchy"))),
		"ruler_name": ruler_name,
		"council_size": council_size,
		"settlement_state": _pretty_settlement_state(settlement_state_raw),
		"settlement_state_label": settlement_state_label,
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
	}


func _observer_focus_settlement() -> Dictionary:
	var settlement_idx: int = -1
	var settlement_data: Dictionary = {}
	if _player_pawn != null and is_instance_valid(_player_pawn) and _player_pawn.data != null:
		var prk: int = WorldMemory._region_key(_player_pawn.data.tile_pos.x, _player_pawn.data.tile_pos.y)
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
	if _pawn_spawner == null:
		return 0
	var n: int = 0
	for p in _pawn_spawner.pawns:
		if p != null and is_instance_valid(p) and p.data != null:
			n += 1
	return n


func _observer_children_count() -> int:
	if _pawn_spawner == null:
		return 0
	var c: int = 0
	for p in _pawn_spawner.pawns:
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
	if pawn_id < 0 or _pawn_spawner == null:
		return "None"
	for p in _pawn_spawner.pawns:
		if p != null and is_instance_valid(p) and p.data != null and int(p.data.id) == pawn_id:
			return p.data.display_name
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
	for p in _pawn_spawner.pawns:
		if p == null or not is_instance_valid(p) or p.data == null:
			continue
		if String(p.data.military_rank).to_lower() != "battlemaster":
			continue
		var rk: int = WorldMemory._region_key(p.data.tile_pos.x, p.data.tile_pos.y)
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


func _handle_draft_click(pawn: Pawn) -> void:
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
