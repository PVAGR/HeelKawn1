extends CanvasLayer
## SurvivalHUD - Player-facing survival status display
##
## Shows:
## - Hunger bar (0-100%)
## - Thirst bar (0-100%)
## - Energy bar (0-100%)
## - Temperature (°C with color coding)
## - Health bar (0-100%)
## - Status effects (injuries, moodlets)
##
## Minecraft/Rust style survival HUD.

@onready var hunger_bar: ProgressBar = $MarginContainer/Panel/VBoxContainer/HungerBox/HungerBar
@onready var thirst_bar: ProgressBar = $MarginContainer/Panel/VBoxContainer/ThirstBox/ThirstBar
@onready var energy_bar: ProgressBar = $MarginContainer/Panel/VBoxContainer/EnergyBox/EnergyBar
@onready var temp_label: Label = $MarginContainer/Panel/VBoxContainer/TempBox/TempLabel
@onready var health_bar: ProgressBar = $MarginContainer/Panel/VBoxContainer/HealthBox/HealthBar
@onready var status_container: VBoxContainer = $MarginContainer/Panel/VBoxContainer/StatusContainer

var _survival_system: Node = null
var _player_pawn: Node = null
var _update_timer: float = 0.0


func _ready() -> void:
	_survival_system = get_node_or_null("/root/SurvivalSystem")
	
	# Verify all required nodes exist before using them
	if not _verify_nodes():
		push_error("[SurvivalHUD] Missing required nodes - HUD will not display correctly")
		set_process(false)
		return
	
	# Hide status container initially
	status_container.visible = false


func _verify_nodes() -> bool:
	# Check all @onready variables are valid
	return (
		hunger_bar != null and
		thirst_bar != null and
		energy_bar != null and
		temp_label != null and
		health_bar != null and
		status_container != null
	)


func _process(delta: float) -> void:
	_update_timer += delta
	
	# Update every 0.5 seconds
	if _update_timer >= 0.5:
		_update_timer = 0.0
		_update_display()


func _update_display() -> void:
	# Get player pawn
	_player_pawn = _get_player_pawn()
	
	if _player_pawn == null or _player_pawn.data == null:
		visible = false
		return
	
	visible = true

	var data: RefCounted = _player_pawn.data

	# Update bars (RefCounted uses direct property access, not .has())
	if data.hunger != null:
		hunger_bar.value = data.hunger
		hunger_bar.modulate = _get_bar_color(data.hunger)

	if data.thirst != null:
		thirst_bar.value = data.thirst
		thirst_bar.modulate = _get_bar_color(data.thirst)

	if data.rest != null:
		var energy: float = data.rest
		energy_bar.value = energy
		energy_bar.modulate = _get_bar_color(energy)

	if data.health != null:
		health_bar.value = data.health
		health_bar.modulate = _get_bar_color(data.health)

	# Update temperature
	if data.body_temperature != null:
		var temp: float = data.body_temperature
		temp_label.text = "%.1f°C" % temp
		temp_label.modulate = _get_temp_color(temp)
	
	# Update status effects
	_update_status_effects(data)


func _get_bar_color(value: float) -> Color:
	if value >= 75:
		return Color(0.2, 0.8, 0.2)  # Green (good)
	elif value >= 50:
		return Color(0.8, 0.8, 0.2)  # Yellow (warning)
	elif value >= 25:
		return Color(0.8, 0.5, 0.2)  # Orange (danger)
	else:
		return Color(0.8, 0.2, 0.2)  # Red (critical)


func _get_temp_color(temp: float) -> Color:
	if temp >= 36.0 and temp <= 37.5:
		return Color(0.2, 0.8, 0.2)  # Normal (green)
	elif temp < 35.0 or temp > 39.0:
		return Color(0.8, 0.2, 0.2)  # Dangerous (red)
	else:
		return Color(0.8, 0.8, 0.2)  # Warning (yellow)


func _update_status_effects(data: RefCounted) -> void:
	# Clear existing status labels
	for child in status_container.get_children():
		child.queue_free()
	
	# Check for status effects
	var effects: Array[String] = []

	# Hunger effects
	if data.hunger != null:
		if data.hunger <= 0:
			effects.append("🍖 STARVING (-20 mood)")
		elif data.hunger < 30:
			effects.append("🍖 Hungry (-5 mood)")
		elif data.hunger > 80:
			effects.append("🍖 Well Fed (+10 mood)")

	# Thirst effects
	if data.thirst != null:
		if data.thirst <= 0:
			effects.append("💧 PARCHED (-25 mood)")
		elif data.thirst < 30:
			effects.append("💧 Thirsty (-8 mood)")
		elif data.thirst > 80:
			effects.append("💧 Quenched (+5 mood)")

	# Temperature effects
	if data.body_temperature != null:
		var temp: float = data.body_temperature
		if temp < 33.0:
			effects.append("🥶 SEVERE HYPOTHERMIA")
		elif temp < 35.0:
			effects.append("🥶 Hypothermia (-20 mood)")
		elif temp > 41.0:
			effects.append("🥵 SEVERE HEATSTROKE")
		elif temp > 39.0:
			effects.append("🥵 Heatstroke (-20 mood)")

	# Injury effects
	if data.injuries != null and data.injuries is Dictionary:
		var injury_count: int = data.injuries.size()
		if injury_count > 0:
			var total_severity: float = 0.0
			for injury_type in data.injuries.keys():
				total_severity += data.injuries[injury_type]
			
			if total_severity > 60:
				effects.append("🩸 SEVERE INJURIES (-30 mood)")
			elif total_severity > 25:
				effects.append("🩸 Moderate Injuries (-15 mood)")
			else:
				effects.append("🩸 Minor Injuries (-5 mood)")
	
	# Add status labels
	for effect in effects:
		var label: Label = Label.new()
		label.text = effect
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_font_size_override("font_size", 10)
		status_container.add_child(label)
	
	status_container.visible = effects.size() > 0


func _get_player_pawn() -> Node:
	# Get player pawn from Main
	var main: Node = get_node_or_null("/root/Main")
	if main == null or not main.has_method("get_player_pawn"):
		# Fallback: check PawnSpawner first pawn
		var pawn_spawner: Node = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
		if pawn_spawner != null:
			var pawns: Array = pawn_spawner.get("pawns")
			if pawns.size() > 0:
				return pawns[0]
		return null
	
	return main.call("get_player_pawn")


## Toggle HUD visibility
func toggle_hud() -> void:
	visible = not visible


## Show HUD
func show_hud() -> void:
	visible = true


## Hide HUD
func hide_hud() -> void:
	visible = false
