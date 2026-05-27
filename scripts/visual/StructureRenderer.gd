extends Node2D
class_name StructureRenderer

const _Buildings = preload("res://scripts/utils/BuildingsVisualizer.gd")

const MAX_VISIBLE_STRUCTURES: int = 200
const RESCAN_INTERVAL_TICKS: int = 30
const SPAWN_SECONDS: float = 0.40
const FADE_SECONDS: float = 0.50

const STORAGE_HUT_SIZE: Vector2 = Vector2(24.0, 18.0)
const SMALL_BUILDING_SIZE: Vector2 = Vector2(14.0, 14.0)
const BIG_BUILDING_SIZE: Vector2 = Vector2(22.0, 18.0)

var _world: World = null
var _camera: Camera2D = null
var _records: Array[Dictionary] = []
var _records_by_key: Dictionary = {}
var _last_scan_tick: int = -999999
var _needs_rescan: bool = true
var _detail_layer: CanvasLayer = null
var _detail_panel: PanelContainer = null
var _detail_title: Label = null
var _detail_body: RichTextLabel = null
var _selected_key: String = ""


func initialize(world_ref: World, camera_ref: Camera2D) -> void:
	_world = world_ref
	_camera = camera_ref
	z_index = 6
	set_process(true)
	set_process_unhandled_input(true)
	if _detail_layer == null:
		_build_detail_panel()
	_needs_rescan = true
	sync_from_world()


func sync_from_world() -> void:
	if _world == null or _world.data == null:
		return
	var data: WorldData = _world.data
	var seen: Dictionary = {}
	for y in range(WorldData.HEIGHT):
		for x in range(WorldData.WIDTH):
			var feature: int = int(data.get_feature(x, y))
			if not StructureCatalog.has_feature(feature):
				continue
			var tile: Vector2i = Vector2i(x, y)
			var key: String = _record_key(tile, feature)
			seen[key] = true
			var rec: Dictionary = _records_by_key.get(key, {})
			if rec.is_empty():
				rec = _make_record(tile, feature)
				_records.append(rec)
				_records_by_key[key] = rec
			else:
				rec["tile"] = tile
				rec["feature"] = feature
				rec["state"] = "live"
				if float(rec.get("spawn_t", 1.0)) >= 1.0:
					rec["spawn_t"] = 1.0
				var rehydrated: Dictionary = _rehydrate_record_from_world(tile, feature, rec)
				for k in rehydrated.keys():
					rec[k] = rehydrated[k]
	for rec_any in _records:
		var rec: Dictionary = rec_any as Dictionary
		if rec.is_empty():
			continue
		var key: String = str(rec.get("key", ""))
		if key.is_empty():
			continue
		if not seen.has(key) and str(rec.get("state", "live")) == "live":
			rec["state"] = "fading"
			rec["fade_t"] = 1.0
	_trim_records()
	_last_scan_tick = GameManager.tick_count if GameManager != null else _last_scan_tick
	_needs_rescan = false
	queue_redraw()


func notify_completed_job(job: Job) -> void:
	if job == null:
		return
	var feature: int = StructureCatalog.feature_for_job(int(job.type))
	if feature < 0:
		return
	var tile: Vector2i = job.tile
	var key: String = _record_key(tile, feature)
	var rec: Dictionary = _records_by_key.get(key, {})
	if rec.is_empty():
		rec = _make_record(tile, feature)
		_records.append(rec)
		_records_by_key[key] = rec
	rec["state"] = "spawning"
	rec["spawn_t"] = 0.0
	rec["fade_t"] = 1.0
	rec["built_tick"] = GameManager.tick_count if GameManager != null else int(rec.get("built_tick", 0))
	rec["builder_id"] = int(job.assigned_pawn.data.id) if job.assigned_pawn != null and is_instance_valid(job.assigned_pawn) and job.assigned_pawn.data != null else int(rec.get("builder_id", -1))
	rec["builder_name"] = String(job.assigned_pawn.data.display_name) if job.assigned_pawn != null and is_instance_valid(job.assigned_pawn) and job.assigned_pawn.data != null else String(rec.get("builder_name", "Unknown"))
	rec["settlement_id"] = int(job.settlement_id)
	rec["settlement_name"] = _settlement_name_for(tile, int(job.settlement_id))
	rec["contents"] = _contents_for(tile, feature, int(job.settlement_id))
	rec["source"] = "job_completed"
	var rehydrated: Dictionary = _rehydrate_record_from_world(tile, feature, rec)
	for k in rehydrated.keys():
		rec[k] = rehydrated[k]
	_trim_records()
	queue_redraw()


func _process(delta: float) -> void:
	var tick_now: int = GameManager.tick_count if GameManager != null else 0
	if _needs_rescan or (tick_now - _last_scan_tick) >= RESCAN_INTERVAL_TICKS:
		sync_from_world()
		return
	var animating: bool = false
	for rec_any in _records:
		var rec: Dictionary = rec_any as Dictionary
		if rec.is_empty():
			continue
		var scale_t: float = float(rec.get("spawn_t", 1.0))
		if scale_t < 1.0:
			scale_t = minf(1.0, scale_t + (delta / SPAWN_SECONDS))
			rec["spawn_t"] = scale_t
			animating = true
		if str(rec.get("state", "live")) == "fading":
			var fade_t: float = float(rec.get("fade_t", 1.0))
			fade_t = maxf(0.0, fade_t - (delta / FADE_SECONDS))
			rec["fade_t"] = fade_t
			animating = true
	if animating:
		queue_redraw()
	if _selected_key != "" and _detail_panel != null and _detail_panel.visible and tick_now % 20 == 0:
		_refresh_selected_details()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var clicked: Dictionary = _record_at_world_pos(get_global_mouse_position())
		if clicked.is_empty():
			_hide_details()
			return
		_select_record(clicked)


func _draw() -> void:
	if _world == null or _world.data == null:
		return
	var draw_list: Array = _visible_records()
	draw_list.sort_custom(Callable(self, "_sort_records_by_y"))
	for rec_any in draw_list:
		var rec: Dictionary = rec_any as Dictionary
		if rec.is_empty():
			continue
		_draw_record(rec)


func _sort_records_by_y(a: Variant, b: Variant) -> bool:
	var ar: Dictionary = a as Dictionary
	var br: Dictionary = b as Dictionary
	var ay: int = int((ar.get("tile", Vector2i.ZERO) as Vector2i).y)
	var by: int = int((br.get("tile", Vector2i.ZERO) as Vector2i).y)
	if ay == by:
		return int((ar.get("tile", Vector2i.ZERO) as Vector2i).x) < int((br.get("tile", Vector2i.ZERO) as Vector2i).x)
	return ay < by


func _draw_record(rec: Dictionary) -> void:
	var tile: Vector2i = rec.get("tile", Vector2i.ZERO)
	var feature: int = int(rec.get("feature", TileFeature.Type.NONE))
	var wp: Vector2 = _world.tile_to_world(tile)
	var scale_t: float = float(rec.get("spawn_t", 1.0))
	var fade_t: float = float(rec.get("fade_t", 1.0))
	var alpha: float = clampf(fade_t, 0.0, 1.0)
	if scale_t <= 0.0 or alpha <= 0.0:
		return
	match feature:
		TileFeature.Type.STORAGE_HUT:
			_draw_storage_hut(wp, scale_t, alpha, rec)
		TileFeature.Type.BED:
			_Buildings.draw_bed(self, wp, 11.0 * scale_t, Color8(220, 180, 120, int(255 * alpha)), scale_t)
		TileFeature.Type.FIRE_PIT:
			_Buildings.draw_fire_pit(self, wp, 12.0 * scale_t, Color8(255, 140, 30, int(255 * alpha)), float(GameManager.tick_count) * 0.01 if GameManager != null else 0.0)
		TileFeature.Type.WALL:
			_Buildings.draw_wall(self, wp, 12.0 * scale_t, Color8(120, 75, 40, int(255 * alpha)), 1.0)
		TileFeature.Type.DOOR:
			_Buildings.draw_door(self, wp, 12.0 * scale_t, Color8(160, 100, 45, int(255 * alpha)), 1.0, false)
		TileFeature.Type.WORKSHOP:
			_draw_workshop(wp, scale_t, alpha)
		TileFeature.Type.GRANARY:
			_draw_granary(wp, scale_t, alpha)
		TileFeature.Type.APOTHECARY:
			_draw_apothecary(wp, scale_t, alpha)
		TileFeature.Type.LIBRARY:
			_draw_library(wp, scale_t, alpha)
		TileFeature.Type.BARRACKS:
			_draw_barracks(wp, scale_t, alpha)
		TileFeature.Type.ROAD:
			_draw_road_marker(wp, scale_t, alpha)
		TileFeature.Type.CELLAR:
			_draw_cellar(wp, scale_t, alpha)
		TileFeature.Type.MARKET:
			_draw_market(wp, scale_t, alpha)
		_:
			_draw_generic_structure(wp, scale_t, alpha, feature)
	if _selected_key == str(rec.get("key", "")):
		var bounds: Rect2 = _record_bounds(rec)
		draw_rect(bounds.grow(1.5), Color8(255, 220, 140, 220), false, 1.2)


func _draw_storage_hut(wp: Vector2, scale_t: float, alpha: float, rec: Dictionary) -> void:
	var tint: Color = Color8(150, 120, 70, int(255 * alpha))
	var roof: Color = Color8(110, 85, 45, int(255 * alpha))
	var door: Color = Color8(65, 45, 25, int(255 * alpha))
	var body: Vector2 = STORAGE_HUT_SIZE * scale_t
	draw_rect(Rect2(wp + Vector2(-body.x * 0.5, -body.y * 0.4), Vector2(body.x, body.y * 0.9)), tint, true)
	draw_rect(Rect2(wp + Vector2(-body.x * 0.52, -body.y * 0.62), Vector2(body.x * 1.04, body.y * 0.38)), roof, true)
	draw_rect(Rect2(wp + Vector2(-2.0 * scale_t, 0.0), Vector2(4.0 * scale_t, 7.0 * scale_t)), door, true)
	draw_rect(Rect2(wp + Vector2(-body.x * 0.36, -body.y * 0.08), Vector2(body.x * 0.15, body.y * 0.14)), Color8(245, 235, 180, int(220 * alpha)), true)
	draw_rect(Rect2(wp + Vector2(body.x * 0.16, -body.y * 0.08), Vector2(body.x * 0.15, body.y * 0.14)), Color8(245, 235, 180, int(220 * alpha)), true)
	var inv: Dictionary = rec.get("contents", {})
	if not inv.is_empty():
		var bar_y: float = wp.y + body.y * 0.62
		var x: float = wp.x - body.x * 0.42
		for item_type in inv.keys():
			var qty: int = int(inv[item_type])
			var bar_h: float = clampf(float(qty) * 0.8, 2.0, 10.0)
			draw_rect(Rect2(x, bar_y - bar_h, 2.2 * scale_t, bar_h), Item.color_for(int(item_type)), true)
			x += 2.6 * scale_t


func _draw_workshop(wp: Vector2, scale_t: float, alpha: float) -> void:
	var base: Color = Color8(160, 120, 80, int(255 * alpha))
	var roof: Color = Color8(120, 90, 60, int(255 * alpha))
	var sz: Vector2 = BIG_BUILDING_SIZE * scale_t
	draw_rect(Rect2(wp + Vector2(-sz.x * 0.5, -sz.y * 0.5), sz), base, true)
	draw_rect(Rect2(wp + Vector2(-sz.x * 0.5, -sz.y * 0.5), Vector2(sz.x, sz.y * 0.34)), roof, true)
	draw_rect(Rect2(wp + Vector2(-sz.x * 0.2, -sz.y * 0.05), Vector2(sz.x * 0.08, sz.y * 0.4)), Color8(80, 55, 35, int(255 * alpha)), true)
	draw_rect(Rect2(wp + Vector2(sz.x * 0.08, -sz.y * 0.05), Vector2(sz.x * 0.08, sz.y * 0.4)), Color8(80, 55, 35, int(255 * alpha)), true)


func _draw_granary(wp: Vector2, scale_t: float, alpha: float) -> void:
	_draw_roundish_building(wp, scale_t, alpha, Color8(180, 160, 80, int(255 * alpha)), Color8(140, 120, 55, int(255 * alpha)))


func _draw_apothecary(wp: Vector2, scale_t: float, alpha: float) -> void:
	_draw_roundish_building(wp, scale_t, alpha, Color8(60, 150, 80, int(255 * alpha)), Color8(40, 110, 55, int(255 * alpha)))
	var cross_c: Color = Color8(240, 240, 240, int(255 * alpha))
	draw_rect(Rect2(wp + Vector2(-1.0 * scale_t, -4.0 * scale_t), Vector2(2.0 * scale_t, 8.0 * scale_t)), cross_c, true)
	draw_rect(Rect2(wp + Vector2(-4.0 * scale_t, -1.0 * scale_t), Vector2(8.0 * scale_t, 2.0 * scale_t)), cross_c, true)


func _draw_library(wp: Vector2, scale_t: float, alpha: float) -> void:
	_draw_roundish_building(wp, scale_t, alpha, Color8(100, 80, 140, int(255 * alpha)), Color8(70, 55, 100, int(255 * alpha)))


func _draw_barracks(wp: Vector2, scale_t: float, alpha: float) -> void:
	_draw_roundish_building(wp, scale_t, alpha, Color8(160, 60, 50, int(255 * alpha)), Color8(120, 40, 35, int(255 * alpha)))


func _draw_cellar(wp: Vector2, scale_t: float, alpha: float) -> void:
	_draw_roundish_building(wp, scale_t, alpha, Color8(100, 90, 80, int(255 * alpha)), Color8(80, 70, 60, int(255 * alpha)))


func _draw_market(wp: Vector2, scale_t: float, alpha: float) -> void:
	_draw_roundish_building(wp, scale_t, alpha, Color8(220, 180, 50, int(255 * alpha)), Color8(180, 145, 35, int(255 * alpha)))


func _draw_road_marker(wp: Vector2, scale_t: float, alpha: float) -> void:
	draw_rect(Rect2(wp + Vector2(-3.0 * scale_t, -1.0 * scale_t), Vector2(6.0 * scale_t, 2.0 * scale_t)), Color8(160, 150, 130, int(180 * alpha)), true)


func _draw_generic_structure(wp: Vector2, scale_t: float, alpha: float, feature: int) -> void:
	var col: Color = TileFeature.color_for(feature)
	col.a = alpha
	draw_rect(Rect2(wp + Vector2(-6.0 * scale_t, -6.0 * scale_t), Vector2(12.0 * scale_t, 12.0 * scale_t)), col, true)


func _draw_roundish_building(wp: Vector2, scale_t: float, alpha: float, body: Color, roof: Color) -> void:
	var sz: Vector2 = BIG_BUILDING_SIZE * scale_t
	draw_rect(Rect2(wp + Vector2(-sz.x * 0.5, -sz.y * 0.5), sz), body, true)
	draw_rect(Rect2(wp + Vector2(-sz.x * 0.52, -sz.y * 0.55), Vector2(sz.x * 1.04, sz.y * 0.32)), roof, true)
	draw_rect(Rect2(wp + Vector2(-1.5 * scale_t, -1.5 * scale_t), Vector2(3.0 * scale_t, 3.0 * scale_t)), Color8(35, 25, 20, int(255 * alpha)), true)


func _record_key(tile: Vector2i, feature: int) -> String:
	return "%d,%d:%d" % [tile.x, tile.y, feature]


func _make_record(tile: Vector2i, feature: int) -> Dictionary:
	return {
		"key": _record_key(tile, feature),
		"tile": tile,
		"feature": feature,
		"state": "spawning",
		"spawn_t": 0.0,
		"fade_t": 1.0,
		"builder_id": -1,
		"builder_name": "Unknown",
		"built_tick": GameManager.tick_count if GameManager != null else 0,
		"settlement_id": -1,
		"settlement_name": "",
		"contents": {},
		"source": "sync",
	}


func _rehydrate_record_from_world(tile: Vector2i, feature: int, rec: Dictionary) -> Dictionary:
	var extra: Dictionary = {}
	if WorldMemory != null and WorldMemory.has_method("get_events_for_tile"):
		var events: Array = WorldMemory.get_events_for_tile(tile)
		for i in range(events.size() - 1, -1, -1):
			var ev_any: Variant = events[i]
			if not (ev_any is Dictionary):
				continue
			var ev: Dictionary = ev_any as Dictionary
			var typ: String = str(ev.get("type", ""))
			if typ in ["structure_built", "building_constructed", "job_completed"]:
				extra["builder_name"] = str(ev.get("worker_name", ev.get("pawn_name", rec.get("builder_name", "Unknown"))))
				extra["builder_id"] = int(ev.get("worker_id", ev.get("pawn_id", rec.get("builder_id", -1))))
				extra["built_tick"] = int(ev.get("tick", rec.get("built_tick", 0)))
				break
	if not extra.has("built_tick"):
		extra["built_tick"] = int(rec.get("built_tick", GameManager.tick_count if GameManager != null else 0))
	if not extra.has("builder_name"):
		extra["builder_name"] = String(rec.get("builder_name", "Unknown"))
	if not extra.has("builder_id"):
		extra["builder_id"] = int(rec.get("builder_id", -1))
	if not extra.has("settlement_name"):
		extra["settlement_name"] = _settlement_name_for(tile, int(rec.get("settlement_id", -1)))
	if not extra.has("contents"):
		extra["contents"] = _contents_for(tile, feature, int(rec.get("settlement_id", -1)))
	return extra


func _settlement_name_for(tile: Vector2i, settlement_id: int) -> String:
	if settlement_id < 0 and SettlementMemory != null and SettlementMemory.has_method("get_settlement_id_for_region"):
		var region_key: int = _WM._region_key(tile.x, tile.y)
		settlement_id = int(SettlementMemory.get_settlement_id_for_region(region_key))
	if settlement_id >= 0 and SettlementMemory != null and SettlementMemory.has_method("get_settlement_at_region"):
		var region_key2: int = _WM._region_key(tile.x, tile.y)
		var sd: Variant = SettlementMemory.get_settlement_at_region(region_key2)
		if sd is Dictionary:
			var sdict: Dictionary = sd as Dictionary
			return str(sdict.get("name", sdict.get("intent", "")))
	return settlement_id >= 0 ? ("Settlement %d" % settlement_id) : ""


func _contents_for(tile: Vector2i, feature: int, settlement_id: int) -> Dictionary:
	if feature != TileFeature.Type.STORAGE_HUT or StockpileManager == null:
		return {}
	for zone in StockpileManager.zones():
		if zone == null or not is_instance_valid(zone):
			continue
		if int(zone.settlement_id) >= 0 and settlement_id >= 0 and int(zone.settlement_id) != settlement_id:
			continue
		if zone.contains_tile(tile) or zone.nearest_tile_to(tile) == tile:
			return zone.inventory.duplicate(true)
	return {}


func _record_at_world_pos(world_pos: Vector2) -> Dictionary:
	for i in range(_records.size() - 1, -1, -1):
		var rec: Dictionary = _records[i] as Dictionary
		if rec == null or rec.is_empty():
			continue
		if _record_bounds(rec).has_point(world_pos):
			return rec
	return {}


func _select_record(rec: Dictionary) -> void:
	_selected_key = str(rec.get("key", ""))
	_show_details(rec)
	queue_redraw()


func _show_details(rec: Dictionary) -> void:
	if _detail_panel == null:
		return
	_detail_panel.visible = true
	_refresh_detail_panel(rec)


func _hide_details() -> void:
	_selected_key = ""
	if _detail_panel != null:
		_detail_panel.visible = false


func _refresh_selected_details() -> void:
	if _selected_key.is_empty() or _detail_panel == null or not _detail_panel.visible:
		return
	for rec_any in _records:
		var rec: Dictionary = rec_any as Dictionary
		if rec.is_empty():
			continue
		if str(rec.get("key", "")) == _selected_key:
			_refresh_detail_panel(rec)
			return


func _refresh_detail_panel(rec: Dictionary) -> void:
	if _detail_title == null or _detail_body == null:
		return
	var feature: int = int(rec.get("feature", TileFeature.Type.NONE))
	var label: String = StructureCatalog.label_for_feature(feature)
	var built_tick: int = int(rec.get("built_tick", 0))
	var age_ticks: int = max(0, (GameManager.tick_count if GameManager != null else built_tick) - built_tick)
	_detail_title.text = label
	var lines: PackedStringArray = []
	lines.append("Tile: %s" % str(rec.get("tile", Vector2i.ZERO)))
	lines.append("Builder: %s" % str(rec.get("builder_name", "Unknown")))
	lines.append("Age: %d ticks" % age_ticks)
	lines.append("Settlement: %s" % str(rec.get("settlement_name", "")))
	lines.append("Feature: %s" % TileFeature.name_for(feature))
	var contents: Dictionary = rec.get("contents", {})
	if contents.is_empty():
		lines.append("Contents: none")
	else:
		var content_bits: PackedStringArray = []
		for item_type in contents.keys():
			content_bits.append("%s x%d" % [Item.name_for(int(item_type)), int(contents[item_type])])
		lines.append("Contents: %s" % ", ".join(content_bits))
	_detail_body.text = "\n".join(lines)


func _build_detail_panel() -> void:
	_detail_layer = CanvasLayer.new()
	_detail_layer.layer = 150
	add_child(_detail_layer)
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_detail_layer.add_child(root)
	_detail_panel = PanelContainer.new()
	_detail_panel.custom_minimum_size = Vector2(280, 180)
	_detail_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.07, 0.92)
	style.border_color = Color(0.88, 0.80, 0.48, 0.75)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	_detail_panel.add_theme_stylebox_override("panel", style)
	root.add_child(_detail_panel)
	_detail_panel.anchor_left = 1.0
	_detail_panel.anchor_right = 1.0
	_detail_panel.anchor_top = 0.0
	_detail_panel.anchor_bottom = 0.0
	_detail_panel.offset_left = -300.0
	_detail_panel.offset_top = 12.0
	_detail_panel.offset_right = -12.0
	_detail_panel.offset_bottom = 200.0
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_detail_panel.add_child(margin)
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	margin.add_child(vbox)
	_detail_title = Label.new()
	_detail_title.add_theme_font_size_override("font_size", 14)
	_detail_title.modulate = Color(1.0, 0.92, 0.65)
	vbox.add_child(_detail_title)
	_detail_body = RichTextLabel.new()
	_detail_body.fit_content = true
	_detail_body.bbcode_enabled = false
	_detail_body.scroll_active = false
	_detail_body.custom_minimum_size = Vector2(0, 120)
	vbox.add_child(_detail_body)
	_detail_panel.visible = false


func _record_bounds(rec: Dictionary) -> Rect2:
	var tile: Vector2i = rec.get("tile", Vector2i.ZERO)
	var feature: int = int(rec.get("feature", TileFeature.Type.NONE))
	var scale_t: float = max(0.25, float(rec.get("spawn_t", 1.0)))
	var sz: Vector2 = _size_for_feature(feature) * scale_t
	var center: Vector2 = _world.tile_to_world(tile)
	return Rect2(center - sz * 0.5, sz)


func _size_for_feature(feature: int) -> Vector2:
	match feature:
		TileFeature.Type.STORAGE_HUT:
			return STORAGE_HUT_SIZE
		TileFeature.Type.WORKSHOP, TileFeature.Type.GRANARY, TileFeature.Type.APOTHECARY, TileFeature.Type.LIBRARY, TileFeature.Type.BARRACKS, TileFeature.Type.CELLAR, TileFeature.Type.MARKET:
			return BIG_BUILDING_SIZE
		TileFeature.Type.BED, TileFeature.Type.FIRE_PIT, TileFeature.Type.WALL, TileFeature.Type.DOOR, TileFeature.Type.ROAD:
			return SMALL_BUILDING_SIZE
	return SMALL_BUILDING_SIZE


func _visible_records() -> Array:
	var out: Array = []
	var cam_rect: Rect2i = _camera_viewport_tiles().grow(3)
	for rec_any in _records:
		var rec: Dictionary = rec_any as Dictionary
		if rec.is_empty():
			continue
		var tile: Vector2i = rec.get("tile", Vector2i.ZERO)
		if cam_rect.has_point(tile):
			out.append(rec)
	if out.size() > MAX_VISIBLE_STRUCTURES:
		out = out.slice(0, MAX_VISIBLE_STRUCTURES)
	return out


func _camera_viewport_tiles() -> Rect2i:
	if _camera == null or _world == null:
		return Rect2i(0, 0, WorldData.WIDTH, WorldData.HEIGHT)
	var cam_pos: Vector2 = _camera.global_position
	var zoom: float = _camera.zoom.x if _camera.zoom.x > 0.0 else 1.0
	var viewport_size: Vector2 = _camera.get_viewport().get_visible_rect().size
	var half_tiles: Vector2 = viewport_size / (2.0 * zoom * World.TILE_PIXELS)
	var min_x: int = int(cam_pos.x / World.TILE_PIXELS - half_tiles.x) - 2
	var min_y: int = int(cam_pos.y / World.TILE_PIXELS - half_tiles.y) - 2
	var max_x: int = int(cam_pos.x / World.TILE_PIXELS + half_tiles.x) + 2
	var max_y: int = int(cam_pos.y / World.TILE_PIXELS + half_tiles.y) + 2
	return Rect2i(
		maxi(0, min_x), maxi(0, min_y),
		mini(WorldData.WIDTH, max_x) - maxi(0, min_x),
		mini(WorldData.HEIGHT, max_y) - maxi(0, min_y)
	)


func _trim_records() -> void:
	if _records.size() <= MAX_VISIBLE_STRUCTURES:
		return
	_records.sort_custom(Callable(self, "_sort_records_by_tick_desc"))
	while _records.size() > MAX_VISIBLE_STRUCTURES:
		var rec: Dictionary = _records.pop_back() as Dictionary
		if rec != null:
			_records_by_key.erase(str(rec.get("key", "")))


func _sort_records_by_tick_desc(a: Variant, b: Variant) -> bool:
	var ar: Dictionary = a as Dictionary
	var br: Dictionary = b as Dictionary
	return int(ar.get("built_tick", 0)) > int(br.get("built_tick", 0))
