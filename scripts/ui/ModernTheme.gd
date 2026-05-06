extends Node
## ModernTheme - RimWorld-style UI theme and styling
##
## Features:
## - Color palette (dark, readable)
## - Font settings (clear, consistent)
## - Icon system (consistent style)
## - Panel styling
## - Button styling

# Color palette (RimWorld-inspired)
const COLORS: Dictionary = {
	# Background
	"bg_dark": Color8(24, 24, 24),
	"bg_medium": Color8(40, 40, 40),
	"bg_light": Color8(60, 60, 60),
	
	# Text
	"text_primary": Color8(240, 240, 240),
	"text_secondary": Color8(180, 180, 180),
	"text_disabled": Color8(100, 100, 100),
	
	# Accents
	"accent_primary": Color8(200, 180, 100),  # Gold
	"accent_secondary": Color8(100, 150, 200),  # Blue
	"accent_success": Color8(100, 180, 100),  # Green
	"accent_warning": Color8(200, 180, 50),  # Yellow
	"accent_danger": Color8(200, 80, 80),  # Red
	
	# Mood colors
	"mood_high": Color8(100, 180, 100),
	"mood_medium": Color8(200, 180, 50),
	"mood_low": Color8(200, 80, 80),
	
	# Profession colors
	"farmer": Color8(120, 180, 80),
	"builder": Color8(180, 140, 80),
	"warrior": Color8(180, 80, 80),
	"scholar": Color8(100, 140, 200),
	"trader": Color8(200, 180, 100),
	"smith": Color8(180, 100, 100),
	"healer": Color8(100, 200, 150),
	"gatherer": Color8(140, 180, 100),
	"hunter": Color8(160, 120, 80)
}

# Font settings
const FONTS: Dictionary = {
	"primary": "res://assets/fonts/NotoSans-Regular.ttf",
	"bold": "res://assets/fonts/NotoSans-Bold.ttf",
	"mono": "res://assets/fonts/SourceCodePro-Regular.ttf"
}

const FONT_SIZES: Dictionary = {
	"small": 10,
	"normal": 12,
	"large": 14,
	"title": 18,
	"heading": 24
}

# Icon paths (placeholder - replace with actual paths)
const ICONS: Dictionary = {
	# Resources
	"wood": "res://assets/icons/resources/wood.png",
	"stone": "res://assets/icons/resources/stone.png",
	"food": "res://assets/icons/resources/food.png",
	"metal": "res://assets/icons/resources/metal.png",
	
	# Professions
	"farmer": "res://assets/icons/professions/farmer.png",
	"builder": "res://assets/icons/professions/builder.png",
	"warrior": "res://assets/icons/professions/warrior.png",
	"scholar": "res://assets/icons/professions/scholar.png",
	
	# UI
	"settings": "res://assets/icons/ui/settings.png",
	"close": "res://assets/icons/ui/close.png",
	"info": "res://assets/icons/ui/info.png"
}


func _ready() -> void:
	# Apply theme to all UI elements
	_apply_theme()


func _apply_theme() -> void:
	# Get all UI elements
	var root: Node = get_tree().get_root()
	if root == null:
		return
	
	# Apply to all Label nodes
	_apply_to_labels(root)
	
	# Apply to all Button nodes
	_apply_to_buttons(root)
	
	# Apply to all Panel nodes
	_apply_to_panels(root)


func _apply_to_labels(root: Node) -> void:
	for node in root.get_children():
		if node is Label:
			_style_label(node)
		_apply_to_labels(node)


func _apply_to_buttons(root: Node) -> void:
	for node in root.get_children():
		if node is Button:
			_style_button(node)
		_apply_to_buttons(node)


func _apply_to_panels(root: Node) -> void:
	for node in root.get_children():
		if node is Panel or node is PanelContainer:
			_style_panel(node)
		_apply_to_panels(node)


func _style_label(label: Label) -> void:
	label.add_theme_color_override("font_color", COLORS.text_primary)
	label.add_theme_font_size_override("font_size", FONT_SIZES.normal)


func _style_button(button: Button) -> void:
	button.add_theme_color_override("font_color", COLORS.text_primary)
	button.add_theme_font_size_override("font_size", FONT_SIZES.normal)
	
	# StyleBox for button
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLORS.bg_light
	style.set_corner_radius_all(4)
	button.add_theme_stylebox_override("normal", style)
	
	var hover_style: StyleBoxFlat = StyleBoxFlat.new()
	hover_style.bg_color = COLORS.bg_medium
	hover_style.set_corner_radius_all(4)
	button.add_theme_stylebox_override("hover", hover_style)


func _style_panel(panel: Control) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLORS.bg_medium
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)


# ==================== PUBLIC API ====================

## Get color by name
func get_color(color_name: String) -> Color:
	return COLORS.get(color_name, Color.WHITE)

## Get font by name
func get_font(font_name: String) -> String:
	return FONTS.get(font_name, FONTS.primary)

## Get font size by name
func get_font_size(size_name: String) -> int:
	return FONT_SIZES.get(size_name, FONT_SIZES.normal)

## Get icon path by name
func get_icon(icon_name: String) -> String:
	return ICONS.get(icon_name, "")

## Get profession color
func get_profession_color(profession: String) -> Color:
	return COLORS.get(profession.to_lower(), COLORS.text_primary)

## Get mood color based on value
func get_mood_color(mood_value: float) -> Color:
	if mood_value >= 70:
		return COLORS.mood_high
	elif mood_value >= 40:
		return COLORS.mood_medium
	else:
		return COLORS.mood_low

## Create styled label
func create_styled_label(text: String = "", size: String = "normal") -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", COLORS.text_primary)
	label.add_theme_font_size_override("font_size", FONT_SIZES.get(size, FONT_SIZES.normal))
	return label

## Create styled button
func create_styled_button(text: String = "") -> Button:
	var button: Button = Button.new()
	button.text = text
	_style_button(button)
	return button

## Create styled panel
func create_styled_panel() -> Panel:
	var panel: Panel = Panel.new()
	_style_panel(panel)
	return panel
