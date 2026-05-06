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

# Decay rates (per tick at rest)
const HUNGER_DECAY_RATE: float = 0.03  # ~33 ticks to starve from full
const THIRST_DECAY_RATE: float = 0.05  # ~20 ticks to dehydrate from full
const ENERGY_DECAY_RATE: float = 0.02  # ~50 ticks to exhaust from full
const STAMINA_DECAY_RATE: float = 0.04  # ~25 ticks to deplete from full

# Work multipliers (faster decay when working)
const WORK_HUNGER_MULT: float = 2.0    # Working pawns get hungry 2x faster
const WORK_THIRST_MULT: float = 1.5   # Working pawns get thirsty 1.5x faster
const WORK_ENERGY_MULT: float = 3.0   # Working pawns tire 3x faster
const WORK_STAMINA_MULT: float = 4.0  # Working pawns exhaust 4x faster

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


func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)
	_world_memory = get_node_or_null("/root/WorldMemory")
	_pawn_spawner = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	_body_risk_manager = get_node_or_null("/root/BodyRiskManager")


func _on_game_tick(tick: int) -> void:
	# Process survival for all pawns
	if _pawn_spawner == null:
		return
	
	for pawn in _pawn_spawner.pawns:
		if pawn == null or not is_instance_valid(pawn) or pawn.data == null:
			continue
		
		_process_survival(pawn, tick)


# ==================== MAIN SURVIVAL PROCESS ====================

func _process_survival(pawn: Node, tick: int) -> void:
	var data: RefCounted = pawn.data
	
	# Check if pawn is working (increases decay)
	var state_val = pawn.get("state")
	var is_working: bool = (state_val if state_val != null else "") == "working"
	var work_mult: float = 1.0
	if is_working:
		work_mult = WORK_HUNGER_MULT
	
	# Decay needs
	_decay_hunger(data, work_mult)
	_decay_thirst(data, work_mult)
	_decay_energy(data, work_mult)
	_decay_stamina(data, work_mult)
	
	# Regulate body temperature
	_regulate_temperature(pawn, tick)
	
	# Process injuries
	_process_injuries(data, tick)
	
	# Apply moodlets from conditions
	_apply_moodlets(pawn, tick)
	
	# Check for death conditions
	_check_death_conditions(pawn, tick)


# ==================== NEEDS DECAY ====================

func _decay_hunger(data: RefCounted, work_mult: float) -> void:
	if not data.has("hunger"):
		return
	
	var decay: float = HUNGER_DECAY_RATE * work_mult
	
	# Traits can affect hunger decay
	if data.has("traits"):
		for tr in data.traits:
			if tr.has("hunger_decay_mult"):
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
	if not data.has("thirst"):
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
	if not data.has("rest") and not data.has("energy"):
		return
	
	var energy_key: String = "energy" if data.has("energy") else "rest"
	var decay: float = ENERGY_DECAY_RATE * work_mult
	
	var cur_energy = data.get(energy_key)
	var energy_val: float = cur_energy if cur_energy != null else 100.0
	data.set(energy_key, maxf(0.0, energy_val - decay))

	# Apply moodlet
	var check_energy = data.get(energy_key)
	var check_val: float = check_energy if check_energy != null else 100.0
	if check_val < 20:
		_apply_moodlet(data, "exhausted")
	elif check_val > 80:
		_apply_moodlet(data, "rested")


func _decay_stamina(data: RefCounted, work_mult: float) -> void:
	if not data.has("stamina"):
		return
	
	var decay: float = STAMINA_DECAY_RATE * work_mult
	data.stamina = maxf(0.0, data.stamina - decay)


# ==================== TEMPERATURE REGULATION ====================

func _regulate_temperature(pawn: Node, tick: int) -> void:
	var data: RefCounted = pawn.data
	if not data.has("body_temperature"):
		return
	
	var current_temp: float = data.body_temperature
	var target_temp: float = 37.0  # Normal body temperature
	
	# Get environmental temperature (from tile/weather)
	var env_temp: float = _get_environmental_temperature(pawn)
	
	# Wetness affects cold exposure
	var wet_mult: float = 1.0
	if data.has("wetness") and data.wetness > 50:
		wet_mult = WET_COLD_MULT
	
	# Adjust towards environmental temperature
	if env_temp < 10:  # Cold environment
		target_temp = lerpf(35.0, 37.0, clampf((env_temp + 10) / 20.0, 0.0, 1.0))
		target_temp *= wet_mult
	elif env_temp > 35:  # Hot environment
		target_temp = lerpf(37.0, 39.0, clampf((env_temp - 35) / 10.0, 0.0, 1.0))
	
	# Gradually adjust body temperature
	var temp_change: float = lerp(current_temp, target_temp, 0.01)
	data.body_temperature = temp_change
	
	# Apply temperature moodlets
	if current_temp < TEMP_HYPOTHERMIA:
		_apply_moodlet(data, "hypothermia")
	elif current_temp > TEMP_HEATSTROKE:
		_apply_moodlet(data, "heatstroke")
	
	# Temperature affects health
	if current_temp < TEMP_HYPOTHERMIA_SEVERE or current_temp > TEMP_HEATSTROKE_SEVERE:
		data.health = maxf(0.0, data.health - 0.1)


func _get_environmental_temperature(pawn: Node) -> float:
	# Get temperature from tile/weather
	# TODO: Integrate with weather/climate system
	# For now, return base temperature with seasonal variation
	var base_temp: float = 20.0  # Base comfortable temperature
	
	# Seasonal variation (simplified)
	var tick: int = GameManager.tick_count
	var day_in_year: int = tick % 360
	var seasonal_mult: float = sin((day_in_year / 360.0) * 2.0 * PI)
	base_temp += seasonal_mult * 10.0
	
	# Time of day variation
	var hour: int = (tick % 1440) / 60  # 24 hours = 1440 ticks
	if hour < 6 or hour > 20:
		base_temp -= 5.0  # Night is colder
	elif hour > 12 and hour < 16:
		base_temp += 3.0  # Midday is warmer
	
	return base_temp


# ==================== INJURY SYSTEM ====================

func _process_injuries(data: RefCounted, tick: int) -> void:
	if not data.has("injuries") or not data.injuries is Dictionary:
		data.injuries = {}
		return
	
	# Process each injury
	var injuries_to_remove: Array = []
	
	for injury_type in data.injuries.keys():
		var severity: float = data.injuries[injury_type]
		
		# Natural healing (1 severity per 100 ticks)
		severity -= 0.01
		data.injuries[injury_type] = maxf(0.0, severity)
		
		# Mark for removal if healed
		if severity <= 0:
			injuries_to_remove.append(injury_type)
		
		# Injuries affect pain
		if data.has("pain"):
			data.pain = minf(100.0, data.pain + severity * 0.1)
	
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
	if not data.has("injuries") or not data.injuries is Dictionary:
		data.injuries = {}
	
	# Add or increase injury
	if data.injuries.has(injury_type):
		data.injuries[injury_type] = minf(INJURY_SEVERE_MAX, data.injuries[injury_type] + severity)
	else:
		data.injuries[injury_type] = minf(INJURY_SEVERE_MAX, severity)
	
	# Apply pain
	if data.has("pain"):
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
	if data.has("health"):
		data.health = maxf(0.0, data.health - severity * 0.1)


## Heal injury
func heal_injury(pawn: Node, injury_type: String, amount: float) -> void:
	var data: RefCounted = pawn.data
	if not data.has("injuries") or not data.injuries.has(injury_type):
		return
	
	data.injuries[injury_type] = maxf(0.0, data.injuries[injury_type] - amount)
	
	# Reduce pain
	if data.has("pain"):
		data.pain = maxf(0.0, data.pain - amount * 0.1)


# ==================== MOODLET SYSTEM ====================

var _active_moodlets: Dictionary = {}  # {pawn_id: {moodlet_key: end_tick}}

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
		if end_tick > GameManager.tick_count:
			return  # Already active, don't refresh
	
	# Apply moodlet
	var duration: int = moodlet.duration
	var end_tick: int = GameManager.tick_count + duration if duration > 0 else -1
	_active_moodlets[pawn_id][moodlet_key] = end_tick
	
	if data.has("mood"):
		data.mood = minf(100.0, data.mood + moodlet.mood)


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
				if data.has("mood"):
					data.mood = maxf(0.0, data.mood - moodlet.mood)


# ==================== DEATH CONDITIONS ====================

func _check_death_conditions(pawn: Node, tick: int) -> void:
	var data: RefCounted = pawn.data
	
	var cause: String = ""
	
	# Starvation
	if data.has("hunger") and data.hunger <= 0:
		cause = "starvation"
	
	# Dehydration
	if data.has("thirst") and data.thirst <= 0:
		cause = "dehydration"
	
	# Hypothermia
	if data.has("body_temperature") and data.body_temperature < TEMP_HYPOTHERMIA_SEVERE:
		cause = "hypothermia"
	
	# Heatstroke
	if data.has("body_temperature") and data.body_temperature > TEMP_HEATSTROKE_SEVERE:
		cause = "heatstroke"
	
	# Health depletion
	if data.has("health") and data.health <= 0:
		cause = "injuries"
	
	# Apply death
	if cause != "":
		_apply_death(pawn, cause)


func _apply_death(pawn: Node, cause: String) -> void:
	var data: RefCounted = pawn.data
	
	# Record death event
	if _world_memory != null:
		_world_memory.record_event({
			"type": "pawn_death",
			"pawn_id": int(data.id),
			"pawn_name": data.get("display_name") if data.get("display_name") != null else "Unknown",
			"cause": cause,
			"tick": GameManager.tick_count
		})
	
	# Kill pawn
	if pawn.has_method("_die"):
		pawn.call("_die", cause)


# ==================== PUBLIC API ====================

## Feed pawn (restore hunger)
func feed_pawn(pawn: Node, food_value: float) -> void:
	var data: RefCounted = pawn.data
	if data.has("hunger"):
		data.hunger = minf(100.0, data.hunger + food_value)

## Water pawn (restore thirst)
func water_pawn(pawn: Node, water_value: float) -> void:
	var data: RefCounted = pawn.data
	if data.has("thirst"):
		data.thirst = minf(100.0, data.thirst + water_value)

## Rest pawn (restore energy)
func rest_pawn(pawn: Node, rest_value: float) -> void:
	var data: RefCounted = pawn.data
	var energy_key: String = "energy" if data.has("energy") else "rest"
	if data.has(energy_key):
		var ev = data.get(energy_key)
		var e_val: float = ev if ev != null else 100.0
		data.set(energy_key, minf(100.0, e_val + rest_value))

## Get survival status for pawn
func get_survival_status(pawn: Node) -> Dictionary:
	var data: RefCounted = pawn.data
	var _h = data.get("hunger"); var hunger: float = _h if _h != null else 100.0
	var _t = data.get("thirst"); var thirst: float = _t if _t != null else 100.0
	var _e = data.get("energy"); var _r = data.get("rest")
	var energy: float = (_e if _e != null else (_r if _r != null else 100.0))
	var _s = data.get("stamina"); var stamina: float = _s if _s != null else 100.0
	var _bt = data.get("body_temperature"); var temperature: float = _bt if _bt != null else 37.0
	var _p = data.get("pain"); var pain: float = _p if _p != null else 0.0
	var _inj = data.get("injuries"); var injuries = _inj if _inj != null else {}
	var _hp = data.get("health"); var health: float = _hp if _hp != null else 100.0
	return {
		"hunger": hunger,
		"thirst": thirst,
		"energy": energy,
		"stamina": stamina,
		"temperature": temperature,
		"pain": pain,
		"injuries": injuries.size(),
		"health": health
	}

## Clear all data (for world reroll)
func clear() -> void:
	_active_moodlets.clear()
