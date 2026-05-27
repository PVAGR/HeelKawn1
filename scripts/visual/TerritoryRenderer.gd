extends Node
class_name TerritoryRenderer

## Lightweight controller for territory visuals.
## It does not replace the existing territory overlay; it keeps that overlay
## invalidated when settlements change and prepares realm summary data for the
## UI panel.

var _world: World = null
var _camera: Camera2D = null
var _territory_overlay: Node = null
var _realm_panel: RealmViewPanel = null
var _faction_visuals: Dictionary = {}
var _last_sync_tick: int = -999999


func initialize(world_ref: World, camera_ref: Camera2D, territory_overlay_ref: Node, realm_panel_ref: RealmViewPanel) -> void:
	_world = world_ref
	_camera = camera_ref
	_territory_overlay = territory_overlay_ref
	_realm_panel = realm_panel_ref
	set_process(true)
	_sync_from_world()


func register_faction_visual_data(visual_data: FactionVisualData) -> void:
	if visual_data == null:
		return
	_faction_visuals[int(visual_data.faction_id)] = visual_data


func sync_from_world() -> void:
	_sync_from_world()


func _process(_delta: float) -> void:
	var tick_now: int = GameManager.tick_count if GameManager != null else 0
	if tick_now - _last_sync_tick >= 120:
		_sync_from_world()


func _sync_from_world() -> void:
	if _territory_overlay != null and _territory_overlay.has_method("invalidate_territories"):
		_territory_overlay.invalidate_territories()
	if _realm_panel != null and _realm_panel.has_method("refresh_from_world"):
		_realm_panel.refresh_from_world(build_realm_summaries())
	_last_sync_tick = GameManager.tick_count if GameManager != null else _last_sync_tick


func build_realm_summaries() -> Array:
	var summaries: Array = []
	if SettlementMemory == null or not SettlementMemory.has_method("get_settlements"):
		return summaries
	for settlement_any in SettlementMemory.get_settlements():
		if not (settlement_any is Dictionary):
			continue
		var settlement: Dictionary = settlement_any.duplicate(true)
		var faction_id: int = int(settlement.get("faction_id", settlement.get("house_id", -1)))
		var visual: FactionVisualData = _visual_for_faction(faction_id, settlement)
		settlement["faction_id"] = faction_id
		settlement["faction_name"] = _faction_name_for(faction_id, settlement)
		settlement["faction_color"] = visual.fill_color()
		settlement["faction_border"] = visual.border_color_for_pulse(1.0)
		settlement["region_count"] = _region_count_for(settlement)
		summaries.append(settlement)
	summaries.sort_custom(Callable(self, "_sort_summary_by_region_count"))
	return summaries


func _sort_summary_by_region_count(a: Variant, b: Variant) -> bool:
	var left: Dictionary = a as Dictionary
	var right: Dictionary = b as Dictionary
	return int(left.get("region_count", 0)) > int(right.get("region_count", 0))


func _visual_for_faction(faction_id: int, settlement: Dictionary) -> FactionVisualData:
	if _faction_visuals.has(faction_id):
		return _faction_visuals[faction_id] as FactionVisualData
	var name: String = _faction_name_for(faction_id, settlement)
	var visual: FactionVisualData = FactionVisualData.from_color(name, _palette_color_for(faction_id), faction_id)
	_faction_visuals[faction_id] = visual
	return visual


func _palette_color_for(faction_id: int) -> Color:
	var seed: int = abs(faction_id * 97 + 41)
	var r: float = 0.24 + float(seed % 5) * 0.12
	var g: float = 0.32 + float((seed / 5) % 5) * 0.10
	var b: float = 0.42 + float((seed / 25) % 5) * 0.08
	return Color(clampf(r, 0.15, 0.92), clampf(g, 0.15, 0.92), clampf(b, 0.15, 0.92), 1.0)


func _faction_name_for(faction_id: int, settlement: Dictionary) -> String:
	if FactionManager != null and FactionManager.has_method("get_faction") and faction_id >= 0:
		var faction: Dictionary = FactionManager.get_faction(faction_id)
		if not faction.is_empty():
			return str(faction.get("name", faction.get("house_name", "")))
	return str(settlement.get("name", settlement.get("house_name", settlement.get("intent", "Independent"))))


func _region_count_for(settlement: Dictionary) -> int:
	var regions: Variant = settlement.get("regions", null)
	if regions is PackedInt32Array:
		return (regions as PackedInt32Array).size()
	if regions is Array:
		return (regions as Array).size()
	return int(settlement.get("region_count", 0))
