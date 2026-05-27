extends Resource
class_name FactionVisualData

## Visual-only faction presentation data for territory overlays and realm UI.
## No simulation state lives here; it only describes colors and pulse timing.

@export var faction_id: int = -1
@export var realm_name: String = ""
@export var base_color: Color = Color(0.18, 0.58, 0.82, 1.0)
@export var border_color: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var fill_alpha: float = 0.20
@export var pulse_seconds: float = 0.8
@export var border_width: float = 2.0
@export var prestige: int = 0
@export var stability: float = 0.5


static func from_color(name: String, color: Color, uid: int = -1) -> FactionVisualData:
	var data: FactionVisualData = FactionVisualData.new()
	data.realm_name = name
	data.base_color = color
	data.border_color = color.lightened(0.18)
	data.faction_id = uid
	return data


func fill_color() -> Color:
	var fill: Color = base_color
	fill.a = fill_alpha
	return fill


func border_color_for_pulse(pulse_strength: float = 1.0) -> Color:
	var color: Color = border_color
	color.a = clampf(0.55 + 0.25 * pulse_strength, 0.0, 1.0)
	return color
