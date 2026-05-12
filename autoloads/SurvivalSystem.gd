extends Node
## SurvivalSystem - The foundation of HeelKawn's reality
##
## Makes survival REAL:
## - Hunger decays (starvation kills)
## - Thirst decays faster (dehydration kills faster)
## - Energy drains from work (exhaustion impairs)
## - Body temperature matters (hypothermia/heatstroke)
## - Injuries apply and persist (cuts, breaks, scars)
## - Mood affected by conditions (isolation, trauma, beauty)
##
## Minecraft ease + Vintage Story depth + Kenshi tension + Rust stakes

# Decay rates (per tick at rest) - BALANCED FOR SURVIVABILITY
const HUNGER_DECAY_RATE: float = 0.003  # ~33,333 ticks to starve from full (~9 hours at 1 tick/sec)
const THIRST_DECAY_RATE: float = 0.005  # ~20,000 ticks to dehydrate from full (~5.5 hours at 1 tick/sec)
const ENERGY_DECAY_RATE: float = 0.002  # ~50,000 ticks to exhaust from full (~14 hours at 1 tick/sec)
const STAMINA_DECAY_RATE: float = 0.004  # ~25,000 ticks to deplete from full (~7 hours at 1 tick/sec)
const EARLY_SURVIVAL_PROTECTION_DAYS: int = 35
const FIRST_YEAR_HARMFUL_SLOWDOWN: float = 300.0
const SURVIVAL_PAWN_BATCH_COUNT: int = 4

# Work multipliers (faster decay when working)
const WORK_HUNGER_MULT: float = 1.5    # Working pawns get hungry 1.5x faster
const WORK_THIRST_MULT: float = 1.3   # Working pawns get thirsty 1.3x faster
const WORK_ENERGY_MULT: float = 2.0   # Working pawns tire 2x faster
const WORK_STAMINA_MULT: float = 3.0  # Working pawns exhaust 3x faster

# Temperature thresholds (Celsius)
const TEMP_NORMAL_LOW: float = 36.0
const TEMP_NORMAL_HIGH: float = 37.5
const TEMP_HYPOTHERMIA: float = 35.0
const TEMP_HYPOTHERMIA_SEVERE: float = 33.0
const TEMP_HEATSTROKE: float = 39.0
const TEMP_HEATSTROKE_SEVERE: float = 41.0

# Environmental temperature effects
const COLD_EXPOSURE_RATE: float = 0.02  # Temp drops per tick in cold
const HEAT_EXPOSURE_RATE: float = 0.02  # Temp rises per tick in heat
const WET_COLD_MULT: float = 1.5        # Wet + cold = faster hypothermia

# Injury severity thresholds
const INJURY_MINOR_MAX: float = 25.0    # Minor: 0-25
const INJURY_MODERATE_MAX: float = 60.0 # Moderate: 25-60
const INJURY_SEVERE_MAX: float = 100.0  # Severe: 60-100

# Injury types
const INJURY_TYPES: Array[String] = [
	"cut", "laceration", "puncture", "bruise", "sprain",
	"fracture", "broken_bone", "burn", "frostbite", "concussion"
]

# Moodlet types
const MOODLETS: Dictionary = {
	"well_fed": {"duration": 300, "mood": 10, "description": "Well Fed"},
	"hungry": {"duration": -1, "mood": -5, "description": "Hungry"},
	"starving": {"duration": -1, "mood": -20, "description": "Starving"},
	"quenched": {"duration": 300, "mood": 5, "description": "Quenched"},
	"thirsty": {"duration": -1, "mood": -8, "description": "Thirsty"},
	"parched": {"duration": -1, "mood": -25, "description": "Parched"},
	"rested": {"duration": 600, "mood": 10, "description": "Rested"},
	"exhausted": {"duration": -1, "mood": -15, "description": "Exhausted"},
	"comfortable": {"duration": -1, "mood": 5, "description": "Comfortable"},
	"uncomfortable": {"duration": -1, "mood": -10, "description": "Uncomfortable"},
	"hypothermia": {"duration": -1, "mood": -20, "description": "Freezing"},
	"heatstroke": {"duration": -1, "mood": -20, "description": "Overheated"},
	"injured_minor": {"duration": -1, "mood": -5, "description": "Minor Injury"},
	"injured_moderate": {"duration": -1, "mood": -15, "description": "Moderate Injury"},
	"injured_severe": {"duration": -1, "mood": -30, "description": "Severe Injury"},
	"lonely": {"duration": -1, "mood": -10, "description": "Lonely"},
	"in_crowd": {"duration": -1, "mood": 5, "description": "Among Friends"},
}

# References
@onready var _world_memory: Node = null
@onready var _pawn_spawner: Node = null
@onready var _body_risk_manager: Node = null
var _last_survival_processed_tick_by_pawn_id: Dictionary = {}


func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)
	_world_memory = get_node_or_null("/root/WorldMemory")
	_pawn_spawner = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	_body_risk_manager = get_node_or_null("/root/BodyRiskManager")


func _on_game_tick(tick: int) -> void:
	# Throttle: survival checks don't need to run every tick at high speed
	var interval: int = 1
	if GameManager != null:
		var gs: float = GameManager.game_speed
		if gs >= 100.0:
			interval = 5
		elif gs >= 50.0:
			interval = 3
		elif gs >= 26.0:
			interval = 2
	if tick % interval != 0:
		return
	# Process survival for all pawns.
	var pawns: Array[HeelKawnian] = PawnSpawner.find_alive_pawns()
	if pawns.is_empty():
		return

	var alive_ids: Dictionary = {}
	for pawn in pawns:
		if pawn == null or not is_instance_valid(pawn) or pawn.data == null:
			continue
		var data: RefCounted = pawn.data
		var pawn_id: int = int(data.id)
		alive_ids[pawn_id] = true

		# Keep fatal-state and duplicate-death protection frequent; batch the
		# expensive body/mood/injury upkeep below.
		_check_death_conditions(pawn, tick)
		if "is_dead" in data and bool(data.is_dead):
			continue
		if not _pawn_in_batch(pawn, tick, SURVIVAL_PAWN_BATCH_COUNT):
			continue

		var last_processed_tick: int = int(_last_survival_processed_tick_by_pawn_id.get(pawn_id, tick - interval))
		var elapsed_ticks: int = maxi(1, tick - last_processed_tick)
		_last_survival_processed_tick_by_pawn_id[pawn_id] = tick
		_process_survival(pawn, tick, elapsed_ticks)

	var stale_ids: Array = []
	for pid in _last_survival_processed_tick_by_pawn_id.keys():
		if not alive_ids.has(pid):
			stale_ids.append(pid)
	for pid in stale_ids:
		_last_survival_processed_tick_by_pawn_id.erase(pid)


func _pawn_stable_batch_id(pawn: Node) -> int:
	if pawn == null:
		return 0
	if pawn.has_method("get_stable_id"):
		return int(pawn.call("get_stable_id"))
	var data = pawn.get("data")
	if data != null and "id" in data:
		return int(data.id)
	var stable_id = pawn.get("stable_id")
	if stable_id != null:
		return int(stable_id)
	var pawn_id = pawn.get("pawn_id")
	if pawn_id != null:
		return int(pawn_id)
	return int(pawn.get_instance_id())


func _pawn_in_batch(pawn: Node, tick: int, batch_count: int) -> bool:
	var safe_batch_count: int = maxi(1, batch_count)
	return posmod(_pawn_stable_batch_id(pawn), safe_batch_count) == posmod(tick, safe_batch_count)


# ==================== MAIN SURVIVAL PROCESS ====================

func _process_survival(pawn: Node, tick: int, elapsed_ticks: int = 1) -> void:
	var data: RefCounted = pawn.data
	var tick_delta: int = maxi(1, elapsed_ticks)

	# Safety: clamp mood to valid range (guards against legacy corruption)
	if data.mood != null and (data.mood < 0.0 or data.mood > 100.0):
		data.mood = clampf(data.mood, 0.0, 100.0)

	# Check if pawn is working (increases decay)
	var state_val = pawn.get("state")
	var is_working: bool = (state_val if state_val != null else "") == "working"
	var work_mult: float = 1.0
	if is_working:
		work_mult = WORK_HUNGER_MULT
	
	# Decay needs — HeelKawnian.gd _decay_needs already handles hunger/rest/thirst
	# with sleeping rates and personality multipliers. Only decay stamina here
	# (HeelKawnian.gd doesn't handle stamina). Moodlets are still applied below.
	_decay_stamina(data, work_mult, tick_delta)

	# Apply moodlets from current conditions (hunger/thirst/etc are
	# decayed by HeelKawnian.gd, but moodlets are managed here).
	_apply_condition_moodlets(data)
	
	# Update wetness from weather
	_update_wetness(data, tick_delta)
	
	# Regulate body temperature
	_regulate_temperature(pawn, tick, tick_delta)
	
	# Process injuries
	_process_injuries(data, tick, tick_delta)
	
	# Apply moodlets from conditions
	_apply_moodlets(pawn, tick)
	
	# Check for death conditions
	_check_death_conditions(pawn, tick)


# ==================== NEEDS DECAY ====================

func _decay_hunger(data: RefCounted, work_mult: float) -> void:
	if data.hunger == null:
		return

	var decay: float = HUNGER_DECAY_RATE * work_mult

	# Traits can affect hunger decay
	if data.traits != null:
		for tr in data.traits:
			if tr.hunger_decay_mult != null:
				decay *= tr.hunger_decay_mult

	data.hunger = maxf(0.0, data.hunger - decay)

	# Apply moodlet
	if data.hunger <= 0:
		_apply_moodlet(data, "starving")
	elif data.hunger < 30:
		_apply_moodlet(data, "hungry")
	elif data.hunger > 80:
		_apply_moodlet(data, "well_fed")


func _decay_thirst(data: RefCounted, work_mult: float) -> void:
	if data.thirst == null:
		# Add thirst if missing (for backwards compatibility)
		data.thirst = 100.0

	var decay: float = THIRST_DECAY_RATE * work_mult
	data.thirst = maxf(0.0, data.thirst - decay)

	# Apply moodlet
	if data.thirst <= 0:
		_apply_moodlet(data, "parched")
	elif data.thirst < 30:
		_apply_moodlet(data, "thirsty")
	elif data.thirst > 80:
		_apply_moodlet(data, "quenched")


func _decay_energy(data: RefCounted, work_mult: float) -> void:
	if data.rest == null:
		return

	var decay: float = ENERGY_DECAY_RATE * work_mult

	var cur_rest = data.rest
	var rest_val: float = cur_rest if cur_rest != null else 100.0
	data.rest = maxf(0.0, rest_val - decay)

	# Apply moodlet
	if data.rest < 20:
		_apply_moodlet(data, "exhausted")
	elif data.rest > 80:
		_apply_moodlet(data, "rested")


func _decay_stamina(data: RefCounted, work_mult: float, tick_delta: int = 1) -> void:
	if data.stamina == null:
		return

	var decay: float = STAMINA_DECAY_RATE * work_mult * float(maxi(1, tick_delta))
	data.stamina = maxf(0.0, data.stamina - decay)


# ==================== TEMPERATURE REGULATION ====================

func _regulate_temperature(pawn: Node, tick: int, tick_delta: int = 1) -> void:
	var data: RefCounted = pawn.data
	if data.body_temperature == null:
		return

	var current_temp: float = data.body_temperature
	var target_temp: float = 37.0  # Normal body temperature

	# Grace period: pioneers resist cold for 5000 ticks, others for 2500 ticks
	# HeelKawnian.gd _check_temperature handles the detailed grace logic,
	# but we must also respect it here to avoid pulling body temp down.
	var birth_tick_g_val = data.birth_tick if "birth_tick" in data else 0
	var birth_tick_g: int = int(birth_tick_g_val) if birth_tick_g_val != null else 0
	var age_g: int = maxi(GameManager.tick_count - birth_tick_g, 0)
	var is_pioneer_g: bool = data.is_pioneer if "is_pioneer" in data else false
	var grace_dur: int = maxi(5000 if is_pioneer_g else 2500, EARLY_SURVIVAL_PROTECTION_DAYS * SimTime.TICKS_PER_VISUAL_DAY)
	var grace_frac: float = clampf(1.0 - float(age_g) / float(grace_dur), 0.0, 1.0)

	# Get environmental temperature (from tile/weather)
	var env_temp: float = _get_environmental_temperature(pawn)

	# Wetness affects cold exposure (if wetness property exists)
	var wet_mult: float = 1.0
	if data.has_method("get") and data.get("wetness") != null:
		var wetness_val = data.get("wetness")
		if wetness_val != null and wetness_val > 50:
			wet_mult = WET_COLD_MULT

	# Adjust towards environmental temperature
	if env_temp < 10:  # Cold environment
		target_temp = lerpf(35.0, 37.0, clampf((env_temp + 10) / 20.0, 0.0, 1.0))
		target_temp *= wet_mult
		# During grace: keep body temp closer to 37°C
		if grace_frac > 0.0:
			target_temp = lerpf(target_temp, 37.0, grace_frac * 0.6)
	elif env_temp > 35:  # Hot environment
		target_temp = lerpf(37.0, 39.0, clampf((env_temp - 35) / 10.0, 0.0, 1.0))

	# Gradually adjust body temperature (slower during grace)
	var lerp_rate: float = 0.01 * (1.0 - grace_frac * 0.8) * _harmful_pressure_scale(tick)
	var tick_delta_f: float = float(maxi(1, tick_delta))
	var adjusted_lerp_rate: float = 1.0 - pow(1.0 - clampf(lerp_rate, 0.0, 1.0), tick_delta_f)
	var temp_change: float = lerp(current_temp, target_temp, adjusted_lerp_rate)
	data.body_temperature = temp_change
	
	# Apply temperature moodlets
	if current_temp < TEMP_HYPOTHERMIA:
		_apply_moodlet(data, "hypothermia")
	elif current_temp > TEMP_HEATSTROKE:
		_apply_moodlet(data, "heatstroke")
	
	# Temperature affects health — suppressed during grace period
	var birth_tick_h_val = data.birth_tick if "birth_tick" in data else 0
	var birth_tick_h: int = int(birth_tick_h_val) if birth_tick_h_val != null else 0
	var age_h: int = maxi(GameManager.tick_count - birth_tick_h, 0)
	var is_pio_h: bool = data.is_pioneer if "is_pioneer" in data else false
	var grace_damage_dur: int = maxi(5000 if is_pio_h else 2500, EARLY_SURVIVAL_PROTECTION_DAYS * SimTime.TICKS_PER_VISUAL_DAY)
	var grace_suppress: float = clampf(1.0 - float(age_h) / float(grace_damage_dur), 0.0, 1.0)
	if current_temp < TEMP_HYPOTHERMIA_SEVERE or current_temp > TEMP_HEATSTROKE_SEVERE:
		var dmg: float = 0.1 * (1.0 - grace_suppress * 0.9) * _harmful_pressure_scale(tick) * tick_delta_f
		data.health = maxf(0.0, data.health - dmg)


func _get_environmental_temperature(pawn: Node) -> float:
	# Get temperature from tile/weather
	var data: RefCounted = pawn.data

	# GRACE PERIOD: New pawns (first 2 hours = 7200 ticks) are protected from extreme cold
	var birth_tick: int = 0
	if "birth_tick" in data:
		birth_tick = int(data.get("birth_tick"))
	var age_ticks: int = GameManager.tick_count - birth_tick
	var grace_mult: float = 1.0
	if age_ticks < 7200:
		# Linear interpolation from full protection to no protection
		grace_mult = lerp(0.2, 1.0, float(age_ticks) / 7200.0)

	var base_temp: float = 20.0  # Base comfortable temperature

	# Seasonal variation (simplified)
	var tick: int = GameManager.tick_count
	var day_in_year: int = tick % 30000  # 30000 ticks per year
	var seasonal_mult: float = sin((day_in_year / 30000.0) * 2.0 * PI)
	base_temp += seasonal_mult * 10.0
	
	# Time of day variation
	var hour: int = (tick % 1440) / 60  # 24 hours = 1440 ticks
	if hour < 6 or hour > 20:
		base_temp -= 5.0  # Night is colder
	elif hour > 12 and hour < 16:
		base_temp += 3.0  # Midday is warmer

	# Shelter bonus: pawns near beds/fire_pits are warmer
	var tile: Vector2i = Vector2i.ZERO
	if data.has_method("get"):
		tile = data.get("tile_pos")
	if tile.x >= 0 and tile.y >= 0:
		var world: Node = get_node_or_null("/root/Main/WorldViewport/World")
		if world != null and world.has_method("get_feature"):
			var feat: int = int(world.call("get_feature", tile.x, tile.y))
			if feat == 3 or feat == 8:  # BED or FIRE_PIT
				base_temp += 8.0  # Shelter/fire provides significant warmth

	# Weather effect on environmental temperature
	var weather_overlay: Node = get_node_or_null("/root/Main/WeatherOverlay")
	if weather_overlay != null and weather_overlay.has_method("get_current_weather"):
		var weather: String = weather_overlay.get_current_weather()
		match weather:
			"rain":
				base_temp -= 4.0
			"snow":
				base_temp -= 10.0
			"sand":
				base_temp += 5.0
			"embers":
				base_temp += 3.0
		# Wind chill amplifies cold weather
		if weather == "rain" or weather == "snow":
			var wind_system: Node = get_node_or_null("/root/WindSystem")
			if wind_system != null and wind_system.has_method("get_wind_strength"):
				var wind_str: float = wind_system.get_wind_strength()
				base_temp -= wind_str * 4.0

	# Apply grace period multiplier (new pawns are more resilient)
	base_temp = lerp(base_temp, 37.0, grace_mult)

	return base_temp


# ==================== WETNESS SYSTEM ====================

func _update_wetness(data: RefCounted, tick_delta: int = 1) -> void:
	# Wetness tracks exposure to precipitation; affects cold vulnerability
	if data == null:
		return
	var wetness_val: float = 0.0
	if data.has_method("get") and data.get("wetness") != null:
		wetness_val = data.get("wetness")
	
	var weather_overlay: Node = get_node_or_null("/root/Main/WeatherOverlay")
	var is_precipitating: bool = false
	if weather_overlay != null and weather_overlay.has_method("is_precipitating"):
		is_precipitating = weather_overlay.is_precipitating()
	
	if is_precipitating:
		# Get wet under rain/snow — caps at 100
		wetness_val = minf(100.0, wetness_val + 1.0 * float(maxi(1, tick_delta)))
	else:
		# Dry off when no precipitation
		wetness_val = maxf(0.0, wetness_val - 0.5 * float(maxi(1, tick_delta)))
	
	# Shelter reduces wetness gain / speeds drying
	var tile: Vector2i = Vector2i.ZERO
	if data.has_method("get"):
		tile = data.get("tile_pos")
	if tile.x >= 0 and tile.y >= 0:
		var world: Node = get_node_or_null("/root/Main/WorldViewport/World")
		if world != null and world.has_method("get_feature"):
			var feat: int = int(world.call("get_feature", tile.x, tile.y))
			if feat == 3 or feat == 8:  # BED or FIRE_PIT — under cover
				if is_precipitating:
					wetness_val = maxf(0.0, wetness_val - 2.0 * float(maxi(1, tick_delta)))  # Shelter blocks rain
				else:
					wetness_val = maxf(0.0, wetness_val - 1.0 * float(maxi(1, tick_delta)))  # Faster drying by fire
	
	if data.has_method("set"):
		data.set("wetness", wetness_val)


# ==================== INJURY SYSTEM ====================

func _process_injuries(data: RefCounted, tick: int, tick_delta: int = 1) -> void:
	if data.injuries == null or not data.injuries is Dictionary:
		data.injuries = {}
		return

	# Process each injury
	var injuries_to_remove: Array = []

	for injury_type in data.injuries.keys():
		var severity: float = data.injuries[injury_type]

		# Natural healing (1 severity per 100 ticks)
		severity -= 0.01 * float(maxi(1, tick_delta))
		data.injuries[injury_type] = maxf(0.0, severity)

		# Mark for removal if healed
		if severity <= 0:
			injuries_to_remove.append(injury_type)

		# Injuries affect pain
		if data.pain != null:
			data.pain = minf(100.0, data.pain + severity * 0.1 * float(maxi(1, tick_delta)))
	
	# Remove healed injuries
	for injury_type in injuries_to_remove:
		data.injuries.erase(injury_type)
	
	# Apply injury moodlets
	var total_severity: float = 0.0
	for injury_type in data.injuries.keys():
		total_severity += data.injuries[injury_type]
	
	if total_severity > INJURY_SEVERE_MAX:
		_apply_moodlet(data, "injured_severe")
	elif total_severity > INJURY_MODERATE_MAX:
		_apply_moodlet(data, "injured_moderate")
	elif total_severity > 0:
		_apply_moodlet(data, "injured_minor")


## Apply injury to pawn
func apply_injury(pawn: Node, injury_type: String, severity: float, cause: String = "") -> void:
	var data: RefCounted = pawn.data
	if data.injuries == null or not data.injuries is Dictionary:
		data.injuries = {}

	# Add or increase injury
	if data.injuries.has(injury_type):
		data.injuries[injury_type] = minf(INJURY_SEVERE_MAX, data.injuries[injury_type] + severity)
	else:
		data.injuries[injury_type] = minf(INJURY_SEVERE_MAX, severity)

	# Apply pain
	if data.pain != null:
		data.pain = minf(100.0, data.pain + severity * 0.2)
	
	# Record injury event
	if _world_memory != null:
		_world_memory.record_event({
			"type": "pawn_injured",
			"pawn_id": int(data.id),
			"injury_type": injury_type,
			"severity": severity,
			"cause": cause,
			"tick": GameManager.tick_count
		})


## Apply wound (bleeding injury)
func apply_wound(pawn: Node, severity: float, cause: String = "") -> void:
	apply_injury(pawn, "laceration", severity, cause)

	# Bleeding causes ongoing health loss
	var data: RefCounted = pawn.data
	if data.health != null:
		data.health = maxf(0.0, data.health - severity * 0.1)


## Heal injury
func heal_injury(pawn: Node, injury_type: String, amount: float) -> void:
	var data: RefCounted = pawn.data
	if data.injuries == null or not data.injuries.has(injury_type):
		return
	
	data.injuries[injury_type] = maxf(0.0, data.injuries[injury_type] - amount)
	
	# Reduce pain
	if data.pain != null:
		data.pain = maxf(0.0, data.pain - amount * 0.1)


# ==================== MOODLET SYSTEM ====================

var _active_moodlets: Dictionary = {}  # {pawn_id: {moodlet_key: end_tick}}

## Check current pawn conditions and apply/remove moodlets accordingly.
## This is separate from the decay functions because HeelKawnian.gd handles the actual
## hunger/thirst/rest decay with sleeping rates and personality multipliers.
func _apply_condition_moodlets(data: RefCounted) -> void:
	# Hunger moodlets
	if data.hunger != null:
		if data.hunger <= 0:
			_apply_moodlet(data, "starving")
			_remove_moodlet_if_active(data, "hungry")
			_remove_moodlet_if_active(data, "well_fed")
		elif data.hunger < 30:
			_apply_moodlet(data, "hungry")
			_remove_moodlet_if_active(data, "starving")
			_remove_moodlet_if_active(data, "well_fed")
		elif data.hunger > 80:
			_apply_moodlet(data, "well_fed")
			_remove_moodlet_if_active(data, "starving")
			_remove_moodlet_if_active(data, "hungry")
		else:
			_remove_moodlet_if_active(data, "starving")
			_remove_moodlet_if_active(data, "hungry")
			_remove_moodlet_if_active(data, "well_fed")
	# Thirst moodlets
	if data.thirst != null:
		if data.thirst <= 0:
			_apply_moodlet(data, "parched")
			_remove_moodlet_if_active(data, "thirsty")
			_remove_moodlet_if_active(data, "quenched")
		elif data.thirst < 30:
			_apply_moodlet(data, "thirsty")
			_remove_moodlet_if_active(data, "parched")
			_remove_moodlet_if_active(data, "quenched")
		elif data.thirst > 80:
			_apply_moodlet(data, "quenched")
			_remove_moodlet_if_active(data, "parched")
			_remove_moodlet_if_active(data, "thirsty")
		else:
			_remove_moodlet_if_active(data, "parched")
			_remove_moodlet_if_active(data, "thirsty")
			_remove_moodlet_if_active(data, "quenched")
	# Rest moodlets
	if data.rest != null:
		if data.rest > 70:
			_apply_moodlet(data, "rested")
			_remove_moodlet_if_active(data, "exhausted")
		elif data.rest < 15:
			_apply_moodlet(data, "exhausted")
			_remove_moodlet_if_active(data, "rested")
		else:
			_remove_moodlet_if_active(data, "rested")
			_remove_moodlet_if_active(data, "exhausted")
	# Temperature moodlets (HeelKawnianData uses body_temperature, normal 36-38°C)
	if data.body_temperature != null:
		if data.body_temperature < 35.0:
			_apply_moodlet(data, "hypothermia")
			_remove_moodlet_if_active(data, "heatstroke")
		elif data.body_temperature > 39.0:
			_apply_moodlet(data, "heatstroke")
			_remove_moodlet_if_active(data, "hypothermia")
		else:
			_remove_moodlet_if_active(data, "hypothermia")
			_remove_moodlet_if_active(data, "heatstroke")
	# Injury moodlets
	if data.health != null and data.max_health != null:
		var ratio: float = data.health / maxf(1.0, data.max_health)
		if ratio < 0.3:
			_apply_moodlet(data, "injured_severe")
			_remove_moodlet_if_active(data, "injured_moderate")
			_remove_moodlet_if_active(data, "injured_minor")
		elif ratio < 0.6:
			_apply_moodlet(data, "injured_moderate")
			_remove_moodlet_if_active(data, "injured_severe")
			_remove_moodlet_if_active(data, "injured_minor")
		elif ratio < 0.85:
			_apply_moodlet(data, "injured_minor")
			_remove_moodlet_if_active(data, "injured_severe")
			_remove_moodlet_if_active(data, "injured_moderate")
		else:
			_remove_moodlet_if_active(data, "injured_severe")
			_remove_moodlet_if_active(data, "injured_moderate")
			_remove_moodlet_if_active(data, "injured_minor")


## Remove a moodlet if it's currently active for this pawn (reverses the mood effect).
func _remove_moodlet_if_active(data: RefCounted, moodlet_key: String) -> void:
	if not MOODLETS.has(moodlet_key):
		return
	var pawn_id: int = int(data.id)
	if not _active_moodlets.has(pawn_id):
		return
	if not _active_moodlets[pawn_id].has(moodlet_key):
		return
	var moodlet: Dictionary = MOODLETS[moodlet_key]
	_active_moodlets[pawn_id].erase(moodlet_key)
	if data.mood != null:
		# Reverse the mood effect: if moodlet.mood was -20, add 20 back
		data.mood = clampf(data.mood - moodlet.mood, 0.0, 100.0)

func _apply_moodlet(data: RefCounted, moodlet_key: String) -> void:
	if not MOODLETS.has(moodlet_key):
		return

	var moodlet: Dictionary = MOODLETS[moodlet_key]
	var pawn_id: int = int(data.id)

	# Initialize moodlets for this pawn
	if not _active_moodlets.has(pawn_id):
		_active_moodlets[pawn_id] = {}

	# Check if moodlet already active
	if _active_moodlets[pawn_id].has(moodlet_key):
		var end_tick: int = _active_moodlets[pawn_id][moodlet_key]
		# end_tick == -1 means infinite duration (condition-based moodlet)
		if end_tick == -1 or end_tick > GameManager.tick_count:
			return  # Already active, don't refresh

	# Apply moodlet
	var duration: int = moodlet.duration
	var end_tick: int = GameManager.tick_count + duration if duration > 0 else -1
	_active_moodlets[pawn_id][moodlet_key] = end_tick

	if data.mood != null:
		data.mood = clampf(data.mood + moodlet.mood, 0.0, 100.0)


func _apply_moodlets(pawn: Node, tick: int) -> void:
	var data: RefCounted = pawn.data
	var pawn_id: int = int(data.id)

	if not _active_moodlets.has(pawn_id):
		return

	# Remove expired moodlets
	for moodlet_key in _active_moodlets[pawn_id].keys():
		var end_tick: int = _active_moodlets[pawn_id][moodlet_key]
		if end_tick >= 0 and end_tick < tick:
			_active_moodlets[pawn_id].erase(moodlet_key)

			# Remove moodlet effect
			if MOODLETS.has(moodlet_key):
				var moodlet: Dictionary = MOODLETS[moodlet_key]
				if data.mood != null:
					data.mood = maxf(0.0, data.mood - moodlet.mood)


# ==================== DEATH CONDITIONS ====================

func _check_death_conditions(pawn: Node, tick: int) -> void:
	var data: RefCounted = pawn.data

	# CRITICAL: Skip death checks for already-dead pawns
	if "is_dead" in data and bool(data.is_dead):
		return  # HeelKawnian is already dead - skip all death processing

	var birth_tick_val = data.birth_tick if "birth_tick" in data else 0
	var birth_tick: int = int(birth_tick_val) if birth_tick_val != null else 0
	var age: int = maxi(GameManager.tick_count - birth_tick, 0)
	var protected_age: int = EARLY_SURVIVAL_PROTECTION_DAYS * SimTime.TICKS_PER_VISUAL_DAY
	if age < protected_age:
		# During grace: clamp health to minimum 20 so survival damage can't kill
		if data.health != null and data.health < 20.0:
			data.health = 20.0
		if data.hunger != null and data.hunger < -3.0:
			data.hunger = -3.0
		if data.body_temperature != null:
			data.body_temperature = clampf(float(data.body_temperature), TEMP_HYPOTHERMIA, TEMP_HEATSTROKE)
		return

	var cause: String = ""

	# Starvation
	if data.hunger != null and data.hunger <= 0:
		cause = "starvation"

	# Dehydration
	if data.thirst != null and data.thirst <= 0:
		cause = "dehydration"

	# Hypothermia
	if data.body_temperature != null and data.body_temperature < TEMP_HYPOTHERMIA_SEVERE:
		cause = "hypothermia"

	# Heatstroke
	if data.body_temperature != null and data.body_temperature > TEMP_HEATSTROKE_SEVERE:
		cause = "heatstroke"

	# Health depletion
	if data.health != null and data.health <= 0:
		cause = "injuries"

	# Apply death
	if cause != "":
		_apply_death(pawn, cause)


func _apply_death(pawn: Node, cause: String) -> void:
	var data: RefCounted = pawn.data

	# CRITICAL: Prevent duplicate death events for already-dead pawns
	if "is_dead" in data and bool(data.get("is_dead")):
		return  # HeelKawnian already marked dead - skip duplicate death processing

	# Record death event
	if _world_memory != null:
		_world_memory.record_event({
			"type": "pawn_death",
			"pawn_id": int(data.id),
			"pawn_name": data.get("display_name") if data.get("display_name") != null else "Unknown",
			"cause": cause,
			"tick": GameManager.tick_count,
			"x": int(data.tile_pos.x) if data.tile_pos != null else 0,
			"y": int(data.tile_pos.y) if data.tile_pos != null else 0,
		})

	# Kill pawn
	if pawn.has_method("_die"):
		pawn.call("_die", cause)


func _harmful_pressure_scale(tick: int) -> float:
	if tick < EARLY_SURVIVAL_PROTECTION_DAYS * SimTime.TICKS_PER_VISUAL_DAY:
		return 0.0
	if tick < SimTime.TICKS_PER_SIM_YEAR:
		return 1.0 / FIRST_YEAR_HARMFUL_SLOWDOWN
	return 1.0


# ==================== PUBLIC API ====================

## Feed pawn (restore hunger)
func feed_pawn(pawn: Node, food_value: float) -> void:
	var data: RefCounted = pawn.data
	if data.hunger != null:
		data.hunger = minf(100.0, data.hunger + food_value)

## Water pawn (restore thirst)
func water_pawn(pawn: Node, water_value: float) -> void:
	var data: RefCounted = pawn.data
	if data.thirst != null:
		data.thirst = minf(100.0, data.thirst + water_value)

## Rest pawn (restore energy)
func rest_pawn(pawn: Node, rest_value: float) -> void:
	var data: RefCounted = pawn.data
	if data.rest != null:
		data.rest = minf(100.0, data.rest + rest_value)

## Get survival status for pawn
func get_survival_status(pawn: Node) -> Dictionary:
	var data: RefCounted = pawn.data
	var _h = data.get("hunger"); var hunger: float = _h if _h != null else 100.0
	var _t = data.get("thirst"); var thirst: float = _t if _t != null else 100.0
	var _r = data.get("rest")
	var rest: float = _r if _r != null else 100.0
	var _s = data.get("stamina"); var stamina: float = _s if _s != null else 100.0
	var _bt = data.get("body_temperature"); var temperature: float = _bt if _bt != null else 37.0
	var _p = data.get("pain"); var pain: float = _p if _p != null else 0.0
	var _inj = data.get("injuries"); var injuries = _inj if _inj != null else {}
	var _hp = data.get("health"); var health: float = _hp if _hp != null else 100.0
	return {
		"hunger": hunger,
		"thirst": thirst,
		"rest": rest,
		"stamina": stamina,
		"temperature": temperature,
		"pain": pain,
		"injuries": injuries.size(),
		"health": health
	}

## Clear all data (for world reroll)
func clear() -> void:
	_active_moodlets.clear()
