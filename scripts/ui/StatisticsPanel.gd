extends PanelContainer
## StatisticsPanel - Live colony metrics and charts
##
## Displays real-time statistics:
## - Population breakdown (by profession, age, gender)
## - Food production vs consumption
## - Knowledge preservation status
## - Settlement health metrics
## - Legacy milestone progress

var _vbox: VBoxContainer = null
var _stats_labels: Dictionary = {}
var _update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.5  # Update every 0.5 seconds

# References
@onready var _pawn_spawner: Node = null
@onready var _settlement_memory: Node = null
@onready var _knowledge_system: Node = null
@onready var _legacy_system: Node = null
@onready var _victory_system: Node = null
@onready var _farming_system: Node = null
@onready var _crafting_system: Node = null


func _ready() -> void:
	custom_minimum_size = Vector2(280, 400)
	
	# Get autoloads
	_pawn_spawner = get_node_or_null("/root/Main/WorldViewport/PawnSpawner")
	_settlement_memory = get_node_or_null("/root/SettlementMemory")
	_knowledge_system = get_node_or_null("/root/KnowledgeSystem")
	_legacy_system = get_node_or_null("/root/LegacySystem")
	_victory_system = get_node_or_null("/root/VictorySystem")
	_farming_system = get_node_or_null("/root/FarmingSystem")
	_crafting_system = get_node_or_null("/root/CraftingSystem")
	
	_build_ui()


func _process(delta: float) -> void:
	_update_timer += delta
	if _update_timer >= UPDATE_INTERVAL:
		_update_timer = 0.0
		_update_statistics()


func _build_ui() -> void:
	# Main container
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	
	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(_vbox)
	
	# Section headers
	_add_section_header("📊 Colony Statistics")
	
	# Population section
	_add_stat_label("population_total", "Population")
	_add_stat_label("population_by_profession", "By Profession")
	_add_stat_label("population_by_age", "By Age")
	
	_vbox.add_child(_make_separator())
	
	# Food section
	_add_section_header("🍖 Food Supply")
	_add_stat_label("food_stockpile", "Food in Stockpile")
	_add_stat_label("food_production", "Food Production/Day")
	_add_stat_label("food_consumption", "Food Consumption/Day")
	
	_vbox.add_child(_make_separator())
	
	# Knowledge section
	_add_section_header("📚 Knowledge")
	_add_stat_label("knowledge_preserved", "Knowledge Types Preserved")
	_add_stat_label("knowledge_carriers", "Knowledge Carriers")
	
	_vbox.add_child(_make_separator())
	
	# Legacy milestone progress
	_add_section_header("Legacy Milestones")
	_add_stat_label("victory_overall", "Overall Milestone Progress")
	_add_stat_label("victory_closest", "Closest Milestone")
	
	_vbox.add_child(_make_separator())
	
	# Production
	_add_section_header("⚙️ Production")
	_add_stat_label("farming_plots", "Active Farm Plots")
	_add_stat_label("crafting_jobs", "Active Crafting Jobs")


func _add_section_header(text: String) -> void:
	var header: Label = Label.new()
	header.text = text
	header.add_theme_font_size_override("font_size", 12)
	header.add_theme_color_override("font_color", Color8(255, 209, 102))
	_vbox.add_child(header)


func _add_stat_label(key: String, text: String) -> void:
	var label: Label = Label.new()
	label.name = key
	label.text = text + ": --"
	label.add_theme_font_size_override("font_size", 9)
	label.add_theme_color_override("font_color", Color8(200, 200, 210))
	_vbox.add_child(label)
	_stats_labels[key] = label


func _make_separator() -> Control:
	var sep: HSeparator = HSeparator.new()
	return sep


func _update_statistics() -> void:
	# Population
	var total_pawns: int = 0
	var profession_counts: Dictionary = {}
	var age_counts: Dictionary = {"child": 0, "teen": 0, "adult": 0, "elder": 0}
	
	if _pawn_spawner != null:
		for pawn in _pawn_spawner.pawns:
			if pawn == null or not is_instance_valid(pawn) or pawn.data == null:
				continue
			
			total_pawns += 1
			
			# Count by profession
			var prof_name: String = pawn.data.profession_name()
			profession_counts[prof_name] = profession_counts.get(prof_name, 0) + 1
			
			# Count by age
			var age: int = int(pawn.data.age)
			if age < 13:
				age_counts.child += 1
			elif age < 18:
				age_counts.teen += 1
			elif age < 60:
				age_counts.adult += 1
			else:
				age_counts.elder += 1
	
	_update_label("population_total", "Population: %d" % total_pawns)
	
	var prof_text: String = ""
	for prof in profession_counts.keys():
		prof_text += "%s: %d  " % [prof, profession_counts[prof]]
	_update_label("population_by_profession", prof_text if prof_text != "" else "No pawns")
	
	_update_label("population_by_age", "Child: %d | Teen: %d | Adult: %d | Elder: %d" % [
		age_counts.child, age_counts.teen, age_counts.adult, age_counts.elder
	])
	
	# Food (simplified - would need actual stockpile integration)
	_update_label("food_stockpile", "Food in Stockpile: Calculating...")
	_update_label("food_production", "Food Production/Day: --")
	_update_label("food_consumption", "Food Consumption/Day: %d" % (total_pawns * 2))
	
	# Knowledge
	var knowledge_count: int = 0
	var carrier_count: int = 0
	if _knowledge_system != null:
		if _knowledge_system.has("record_carriers"):
			var carriers: Dictionary = _knowledge_system.get("record_carriers")
			var knowledge_types: Dictionary = {}
			for carrier in carriers.values():
				carrier_count += 1
				for kt in carrier.get("knowledge_types", []):
					knowledge_types[kt] = true
			knowledge_count = knowledge_types.size()
	
	_update_label("knowledge_preserved", "Knowledge Types Preserved: %d/26" % knowledge_count)
	_update_label("knowledge_carriers", "Knowledge Carriers: %d" % carrier_count)
	
	# Legacy milestone progress
	var overall: float = 0.0
	var closest: String = "None"
	if _victory_system != null:
		overall = _victory_system.get_overall_completion()
		closest = _victory_system.get_closest_victory()
	
	_update_label("victory_overall", "Overall Milestone Progress: %.1f%%" % overall)
	_update_label("victory_closest", "Closest Milestone: %s" % closest)
	
	# Production
	var farm_plots: int = 0
	var crafting_jobs: int = 0
	if _farming_system != null:
		farm_plots = _farming_system.farm_plots.size()
	if _crafting_system != null:
		crafting_jobs = _crafting_system.active_crafting_jobs.size()
	
	_update_label("farming_plots", "Active Farm Plots: %d" % farm_plots)
	_update_label("crafting_jobs", "Active Crafting Jobs: %d" % crafting_jobs)


func _update_label(key: String, text: String) -> void:
	if _stats_labels.has(key):
		var label: Label = _stats_labels[key]
		if label != null and is_instance_valid(label):
			label.text = text


# ==================== Public API ====================

## Refresh statistics immediately
func refresh() -> void:
	_update_statistics()

## Toggle visibility
func toggle_visibility() -> void:
	visible = not visible
