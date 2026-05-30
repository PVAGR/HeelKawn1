extends Node
## LibrarySystem — physical libraries as knowledge storage zones.
##
## Libraries are zone-like structures that preserve knowledge and enable
## research. Each library has a capacity, collection of knowledge items,
## and a preservation factor that slows knowledge decay.
##
## Integrates with SettlementMemory for population, BuildingRegistry for
## building quality, KnowledgeSystem for knowledge levels, EventBus for
## settlement lifecycle events, and WorldRNG for deterministic rolls.

signal library_founded(library_id: String, center: int, tick: int)
signal library_destroyed(library_id: String, center: int, tick: int)
signal book_added(library_id: String, book_id: String, knowledge_type: int, tick: int)
signal book_destroyed(library_id: String, book_id: String, tick: int)
signal preservation_critical(library_id: String, preservation: float, tick: int)

const LIBRARY_CHECK_INTERVAL: int = 2000
const MAINTENANCE_TICK_INTERVAL: int = 500
const BASE_PRESERVATION: float = 0.3
const MAX_PRESERVATION: float = 1.0
const DEGRADATION_PER_INTERVAL: float = 0.02
const SCHOLAR_MAINTENANCE_BONUS: float = 0.03
const CAPACITY_PER_POP: int = 2
const BASE_CAPACITY: int = 50
const MIN_POP_FOR_LIBRARY: int = 5
const COPY_WORK_TICKS: int = 300
const CRITICAL_PRESERVATION_THRESHOLD: float = 0.1
const MAX_LIBRARIES_PER_SETTLEMENT: int = 5
const CAPACITY_UPGRADE_COST_BASE: int = 20
const DESTRUCTION_RECOVERY_BOOK_FRACTION: float = 0.3

var _libraries: Dictionary = {}
var _settlement_library_index: Dictionary = {}
var _next_library_seq: int = 0
var _last_library_tick: int = -999999
var _last_maintenance_tick: int = -999999
var _total_books_ever_deposited: int = 0
var _total_books_destroyed: int = 0
var _total_libraries_destroyed: int = 0
var _emitted_critical_warnings: Dictionary = {}

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)
	var eb: Node = get_node_or_null("/root/EventBus")
	if eb != null and eb.has_method("subscribe"):
		eb.subscribe(EventBus.EVENT_SETTLEMENT_FOUNDED, self, "_on_settlement_founded")
		eb.subscribe(EventBus.EVENT_SETTLEMENT_ABANDONED, self, "_on_settlement_destroyed")
		eb.subscribe("settlement_destroyed", self, "_on_settlement_destroyed")
		eb.subscribe("building_constructed", self, "_on_building_constructed")

func _on_game_tick(tick: int) -> void:
	if tick - _last_library_tick < LIBRARY_CHECK_INTERVAL:
		return
	_last_library_tick = tick
	var sm: Node = get_node_or_null("/root/SettlementMemory")
	if sm == null:
		return
	if not sm.has_method("get_settlements"):
		return
	var settlements: Array = sm.get_settlements()
	for st_v in settlements:
		if not (st_v is Dictionary):
			continue
		var st: Dictionary = st_v as Dictionary
		var center: int = int(st.get("center_region", -1))
		if center < 0:
			continue
		_update_settlement_libraries(center, st, tick)
	if tick - _last_maintenance_tick >= MAINTENANCE_TICK_INTERVAL:
		_last_maintenance_tick = tick
		_run_maintenance_cycle(tick)

func _generate_library_id(center: int, zone_id: String, tick: int) -> String:
	_next_library_seq += 1
	return "lib_%d_%s_seq%d" % [center, zone_id, _next_library_seq]

func _generate_book_id(library_id: String, tick: int) -> String:
	return "bk_%s_t%d" % [library_id, tick]

func _settlement_key(center: int) -> String:
	return "st_%d" % center

func _library_exists(library_id: String) -> bool:
	return _libraries.has(library_id)

func _get_settlement_libraries(center: int) -> Array[String]:
	var key: String = _settlement_key(center)
	if not _settlement_library_index.has(key):
		return []
	return _settlement_library_index[key].duplicate()

func _index_library(center: int, library_id: String) -> void:
	var key: String = _settlement_key(center)
	if not _settlement_library_index.has(key):
		_settlement_library_index[key] = []
	if not library_id in _settlement_library_index[key]:
		_settlement_library_index[key].append(library_id)

func _unindex_library(center: int, library_id: String) -> void:
	var key: String = _settlement_key(center)
	if _settlement_library_index.has(key):
		_settlement_library_index[key].erase(library_id)
		if _settlement_library_index[key].is_empty():
			_settlement_library_index.erase(key)

func found_library(center: int, tick: int, zone_id: String = "main", custom_name: String = "") -> bool:
	if center < 0:
		return false
	var existing: Array[String] = _get_settlement_libraries(center)
	if existing.size() >= MAX_LIBRARIES_PER_SETTLEMENT:
		return false
	for lid in existing:
		var lib: Dictionary = _libraries.get(lid, {})
		if lib.get("zone_id", "") == zone_id and not lib.get("destroyed", false):
			return false
	var library_id: String = _generate_library_id(center, zone_id, tick)
	var display_name: String = custom_name
	if display_name.is_empty():
		display_name = "Library %d" % _next_library_seq
	var lib: Dictionary = {
		"library_id": library_id,
		"center": center,
		"zone_id": zone_id,
		"name": display_name,
		"capacity": BASE_CAPACITY,
		"items": [],
		"preservation": BASE_PRESERVATION,
		"scholars_assigned": 0,
		"building_quality": 0.5,
		"founded_tick": tick,
		"destroyed": false,
		"destroyed_tick": -1,
		"last_tick": tick,
		"total_books_ever": 0,
		"total_books_copied": 0,
		"total_maintenance_actions": 0,
	}
	_libraries[library_id] = lib
	_index_library(center, library_id)
	library_founded.emit(library_id, center, tick)
	var wm: Node = get_node_or_null("/root/WorldMemory")
	if wm != null and wm.has_method("record_event"):
		wm.record_event({
			"type": "library_founded",
			"library_id": library_id,
			"center": center,
			"zone_id": zone_id,
			"name": display_name,
			"capacity": BASE_CAPACITY,
			"tick": tick,
		})
	return true

func destroy_library(library_id: String, tick: int, cataclysm: String = "unknown") -> bool:
	if not _library_exists(library_id):
		return false
	var lib: Dictionary = _libraries[library_id]
	if lib.get("destroyed", false):
		return false
	var center: int = lib.get("center", -1)
	var book_count: int = lib.get("items", []).size()
	_total_libraries_destroyed += 1
	_total_books_destroyed += book_count
	var preserved_books: Array = []
	for bk in lib.get("items", []):
		var pf: float = bk.get("preservation_factor", 0.0)
		if pf >= 0.5 and tick > 0:
			var rng_seed: int = WorldRNG.stream_seed(StringName("lib_destroy_keep:%s" % library_id), bk.get("book_id", "").hash() + tick) if WorldRNG != null else tick
			var roll: float = float(rng_seed % 1000) / 1000.0 if rng_seed > 0 else 0.0
			if roll < DESTRUCTION_RECOVERY_BOOK_FRACTION:
				preserved_books.append(bk)
	lib["destroyed"] = true
	lib["destroyed_tick"] = tick
	lib["destroy_cataclysm"] = cataclysm
	lib["preserved_books"] = preserved_books
	_libraries[library_id] = lib
	library_destroyed.emit(library_id, center, tick)
	var wm: Node = get_node_or_null("/root/WorldMemory")
	if wm != null and wm.has_method("record_event"):
		wm.record_event({
			"type": "library_destroyed",
			"library_id": library_id,
			"center": center,
			"zone_id": lib.get("zone_id", ""),
			"name": lib.get("name", ""),
			"cataclysm": cataclysm,
			"books_lost": book_count - preserved_books.size(),
			"books_saved": preserved_books.size(),
			"tick": tick,
		})
	return true

func rebuild_library(library_id: String, tick: int) -> bool:
	if not _library_exists(library_id):
		return false
	var lib: Dictionary = _libraries[library_id]
	if not lib.get("destroyed", false):
		return false
	var center: int = lib.get("center", -1)
	var preserved: Array = lib.get("preserved_books", [])
	lib["items"] = preserved.duplicate()
	lib["destroyed"] = false
	lib["destroyed_tick"] = -1
	lib.erase("destroy_cataclysm")
	lib.erase("preserved_books")
	lib["preservation"] = BASE_PRESERVATION * 0.5
	lib["last_tick"] = tick
	_libraries[library_id] = lib
	library_founded.emit(library_id, center, tick)
	return true

func add_book(library_id: String, knowledge_type: int, carrier: int, tick: int, title: String = "") -> Dictionary:
	if not _library_exists(library_id):
		return {}
	var lib: Dictionary = _libraries[library_id]
	if lib.get("destroyed", false):
		return {}
	if lib.get("items", []).size() >= lib.get("capacity", BASE_CAPACITY):
		return {}
	var book_id: String = _generate_book_id(library_id, tick)
	var bk_preservation: float = lib.get("preservation", BASE_PRESERVATION)
	if bk_preservation < 0.1:
		bk_preservation = 0.1
	var book_title: String = title
	if book_title.is_empty():
		var ks: Node = get_node_or_null("/root/KnowledgeSystem")
		if ks != null and ks.has_method("_get_knowledge_type_name"):
			var type_name: String = ks._get_knowledge_type_name(knowledge_type)
			book_title = "%s Scroll" % type_name
		else:
			book_title = "Knowledge Scroll #%d" % knowledge_type
	var book: Dictionary = {
		"book_id": book_id,
		"knowledge_type": knowledge_type,
		"carrier": carrier,
		"tick": tick,
		"preservation_factor": clampf(bk_preservation, 0.0, MAX_PRESERVATION),
		"title": book_title,
		"copy_of": "",
		"last_restored_tick": tick,
	}
	var items: Array = lib.get("items", [])
	items.append(book)
	lib["items"] = items
	lib["total_books_ever"] = lib.get("total_books_ever", 0) + 1
	lib["last_tick"] = tick
	_libraries[library_id] = lib
	_total_books_ever_deposited += 1
	book_added.emit(library_id, book_id, knowledge_type, tick)
	var wm: Node = get_node_or_null("/root/WorldMemory")
	if wm != null and wm.has_method("record_event"):
		wm.record_event({
			"type": "book_deposited",
			"library_id": library_id,
			"book_id": book_id,
			"knowledge_type": knowledge_type,
			"carrier": carrier,
			"title": book_title,
			"tick": tick,
		})
	return book

func remove_book(library_id: String, book_id: String) -> bool:
	if not _library_exists(library_id):
		return false
	var lib: Dictionary = _libraries[library_id]
	var items: Array = lib.get("items", [])
	var found_idx: int = -1
	for i in range(items.size()):
		if items[i].get("book_id", "") == book_id:
			found_idx = i
			break
	if found_idx < 0:
		return false
	var removed: Dictionary = items[found_idx]
	items.remove_at(found_idx)
	lib["items"] = items
	lib["last_tick"] = GameManager.tick_count if GameManager != null else 0
	_libraries[library_id] = lib
	_total_books_destroyed += 1
	book_destroyed.emit(library_id, book_id, GameManager.tick_count if GameManager != null else 0)
	var wm: Node = get_node_or_null("/root/WorldMemory")
	if wm != null and wm.has_method("record_event"):
		wm.record_event({
			"type": "book_destroyed",
			"library_id": library_id,
			"book_id": book_id,
			"knowledge_type": removed.get("knowledge_type", -1),
			"reason": "removed",
			"tick": GameManager.tick_count if GameManager != null else 0,
		})
	return true

func copy_book(source_library_id: String, book_id: String, target_library_id: String, scholar_id: int, tick: int) -> Dictionary:
	if not _library_exists(source_library_id):
		return {}
	if not _library_exists(target_library_id):
		return {}
	var src_lib: Dictionary = _libraries[source_library_id]
	var tgt_lib: Dictionary = _libraries[target_library_id]
	if src_lib.get("destroyed", false) or tgt_lib.get("destroyed", false):
		return {}
	var src_items: Array = src_lib.get("items", [])
	var source_book: Dictionary = {}
	for bk in src_items:
		if bk.get("book_id", "") == book_id:
			source_book = bk
			break
	if source_book.is_empty():
		return {}
	var tgt_items: Array = tgt_lib.get("items", [])
	if tgt_items.size() >= tgt_lib.get("capacity", BASE_CAPACITY):
		return {}
	var ks: Node = get_node_or_null("/root/KnowledgeSystem")
	if ks != null and ks.has_method("has_knowledge"):
		if not ks.has_knowledge(scholar_id, source_book.get("knowledge_type", -1)):
			return {}
	var rng_seed: int = WorldRNG.stream_seed(StringName("book_copy:%s" % book_id), scholar_id + tick) if WorldRNG != null else tick
	var copy_preservation: float = source_book.get("preservation_factor", 0.5) * 0.9
	var copy_quality_roll: float = float(rng_seed % 1000) / 1000.0 if rng_seed > 0 else 0.5
	if copy_quality_roll < 0.1:
		copy_preservation *= 0.7
	elif copy_quality_roll > 0.9:
		copy_preservation *= 1.1
	copy_preservation = clampf(copy_preservation, 0.05, MAX_PRESERVATION)
	var book_id_copy: String = _generate_book_id(target_library_id, tick) + "_copy"
	var copy_title: String = "Copy of %s" % source_book.get("title", "Unknown")
	var copy_book: Dictionary = {
		"book_id": book_id_copy,
		"knowledge_type": source_book.get("knowledge_type", -1),
		"carrier": scholar_id,
		"tick": tick,
		"preservation_factor": copy_preservation,
		"title": copy_title,
		"copy_of": book_id,
		"last_restored_tick": tick,
	}
	tgt_items.append(copy_book)
	tgt_lib["items"] = tgt_items
	tgt_lib["total_books_ever"] = tgt_lib.get("total_books_ever", 0) + 1
	tgt_lib["total_books_copied"] = tgt_lib.get("total_books_copied", 0) + 1
	tgt_lib["last_tick"] = tick
	_libraries[target_library_id] = tgt_lib
	_total_books_ever_deposited += 1
	book_added.emit(target_library_id, book_id_copy, source_book.get("knowledge_type", -1), tick)
	var wm: Node = get_node_or_null("/root/WorldMemory")
	if wm != null and wm.has_method("record_event"):
		wm.record_event({
			"type": "book_copied",
			"source_library_id": source_library_id,
			"source_book_id": book_id,
			"target_library_id": target_library_id,
			"target_book_id": book_id_copy,
			"scholar_id": scholar_id,
			"tick": tick,
		})
	return copy_book

func _calculate_preservation(lib: Dictionary, st: Dictionary) -> float:
	var pop: int = int(st.get("population", 0))
	var building_count: int = int(st.get("buildings_constructed", 0))
	var scholars: int = lib.get("scholars_assigned", 0)
	var building_quality: float = 0.5
	if building_count > 0:
		var raw_quality: float = float(building_count % 20) / 20.0 + 0.3
		building_quality = clampf(raw_quality, 0.2, 1.0)
	var era_tech_level: float = 0.0
	var te: Node = get_node_or_null("/root/TechnologyEras")
	if te != null and te.has_method("get_settlement_era"):
		var era: int = te.get_settlement_era(lib.get("center", -1))
		era_tech_level = float(era) * 0.05
	var scholar_factor: float = float(scholars) * SCHOLAR_MAINTENANCE_BONUS
	var pop_factor: float = float(mini(pop, 100)) / 200.0
	var base: float = BASE_PRESERVATION + building_quality * 0.2 + scholar_factor + pop_factor * 0.1 + era_tech_level
	lib["building_quality"] = building_quality
	return clampf(base, 0.05, MAX_PRESERVATION)

func _update_settlement_libraries(center: int, st: Dictionary, tick: int) -> void:
	var pop: int = int(st.get("population", 0))
	var existing: Array[String] = _get_settlement_libraries(center)
	if pop < MIN_POP_FOR_LIBRARY:
		var max_scholars: int = 0
		for lid in existing:
			var lb: Dictionary = _libraries.get(lid, {})
			if lb.get("destroyed", false):
				continue
			if lb.get("scholars_assigned", 0) > 0:
				lb["scholars_assigned"] = 0
				_libraries[lid] = lb
		return
	if existing.is_empty():
		var rng_seed: int = WorldRNG.stream_seed(StringName("library_auto_found:%d" % center), tick) if WorldRNG != null else tick
		var roll: float = float(rng_seed % 1000) / 1000.0 if rng_seed > 0 else 0.0
		var threshold: float = 0.05 + float(mini(pop, 200)) / 400.0
		if roll < threshold:
			found_library(center, tick, "auto_zone", "")
		return
	for lid in existing:
		var lib: Dictionary = _libraries.get(lid, {})
		if lib.is_empty():
			continue
		if lib.get("destroyed", false):
			continue
		var new_capacity: int = BASE_CAPACITY + pop * CAPACITY_PER_POP
		var old_capacity: int = lib.get("capacity", BASE_CAPACITY)
		if new_capacity > old_capacity:
			lib["capacity"] = new_capacity
		var old_scholars: int = lib.get("scholars_assigned", 0)
		var ideal_scholars: int = maxi(0, pop / 20)
		if old_scholars < ideal_scholars:
			lib["scholars_assigned"] = old_scholars + 1
		elif old_scholars > ideal_scholars + 2 and old_scholars > 0:
			lib["scholars_assigned"] = maxi(0, old_scholars - 1)
		lib["preservation"] = _calculate_preservation(lib, st)
		_degrade_books(lib, tick)
		lib["last_tick"] = tick
		_libraries[lid] = lib

func _degrade_books(lib: Dictionary, tick: int) -> void:
	var items: Array = lib.get("items", [])
	if items.is_empty():
		return
	var base_preservation: float = lib.get("preservation", BASE_PRESERVATION)
	var degradation_this_cycle: float = DEGRADATION_PER_INTERVAL
	if base_preservation > 0.5:
		degradation_this_cycle *= 1.0 - (base_preservation - 0.5)
	var scholars: int = lib.get("scholars_assigned", 0)
	if scholars > 0:
		degradation_this_cycle *= maxf(0.1, 1.0 - float(scholars) * 0.2)
	if degradation_this_cycle <= 0.001:
		return
	var destroyed_any: bool = false
	var surviving: Array = []
	for bk in items:
		var pf: float = bk.get("preservation_factor", 0.5)
		var age_penalty: float = 0.0
		if tick - bk.get("tick", tick) > 10000:
			age_penalty = 0.005
		pf = clampf(pf - degradation_this_cycle - age_penalty, 0.0, MAX_PRESERVATION)
		bk["preservation_factor"] = pf
		if pf <= 0.001:
			destroyed_any = true
			_total_books_destroyed += 1
			book_destroyed.emit(lib.get("library_id", ""), bk.get("book_id", ""), tick)
		else:
			surviving.append(bk)
	if destroyed_any:
		var destroyed_count: int = items.size() - surviving.size()
		lib["items"] = surviving
		var wm: Node = get_node_or_null("/root/WorldMemory")
		if wm != null and wm.has_method("record_event"):
			wm.record_event({
				"type": "books_degraded_to_dust",
				"library_id": lib.get("library_id", ""),
				"count": destroyed_count,
				"tick": tick,
			})
		_check_preservation_critical(lib, tick)
	_libraries[lib.get("library_id", "")] = lib

func _check_preservation_critical(lib: Dictionary, tick: int) -> void:
	var average_pf: float = _average_preservation(lib)
	if average_pf < CRITICAL_PRESERVATION_THRESHOLD:
		var lid: String = lib.get("library_id", "")
		var last_warn: int = _emitted_critical_warnings.get(lid, -1)
		if tick - last_warn > 2000 or last_warn < 0:
			_emitted_critical_warnings[lid] = tick
			preservation_critical.emit(lid, average_pf, tick)
			var wm: Node = get_node_or_null("/root/WorldMemory")
			if wm != null and wm.has_method("record_event"):
				wm.record_event({
					"type": "library_preservation_critical",
					"library_id": lid,
					"average_preservation": average_pf,
					"tick": tick,
				})

func _average_preservation(lib: Dictionary) -> float:
	var items: Array = lib.get("items", [])
	if items.is_empty():
		return 0.0
	var total: float = 0.0
	for bk in items:
		total += bk.get("preservation_factor", 0.0)
	return total / float(items.size())

func _run_maintenance_cycle(tick: int) -> void:
	for lid in _libraries:
		var lib: Dictionary = _libraries[lid]
		if lib.get("destroyed", false):
			continue
		var scholars: int = lib.get("scholars_assigned", 0)
		if scholars <= 0:
			continue
		var items: Array = lib.get("items", [])
		var maintenance_per_scholar: int = maxi(1, items.size() / maxi(1, scholars))
		var restored_count: int = 0
		for i in range(items.size()):
			if i % maxi(1, scholars) == 0:
				var bk: Dictionary = items[i]
				var pf: float = bk.get("preservation_factor", 0.0)
				if pf < 0.3:
					var boost: float = float(scholars) * 0.01
					bk["preservation_factor"] = clampf(pf + boost, 0.0, MAX_PRESERVATION)
					bk["last_restored_tick"] = tick
					restored_count += 1
				elif pf < 0.8:
					var boost: float = float(scholars) * 0.005
					bk["preservation_factor"] = clampf(pf + boost, 0.0, MAX_PRESERVATION)
					bk["last_restored_tick"] = tick
					restored_count += 1
		if restored_count > 0:
			lib["total_maintenance_actions"] = lib.get("total_maintenance_actions", 0) + restored_count
			_libraries[lid] = lib

func assign_scholar(library_id: String, count: int) -> bool:
	if not _library_exists(library_id):
		return false
	var lib: Dictionary = _libraries[library_id]
	if lib.get("destroyed", false):
		return false
	var new_count: int = maxi(0, lib.get("scholars_assigned", 0) + count)
	var center: int = lib.get("center", -1)
	var sm: Node = get_node_or_null("/root/SettlementMemory")
	var pop: int = 0
	if sm != null and sm.has_method("get_settlement_at_region"):
		var st_v: Variant = sm.get_settlement_at_region(center)
		if st_v != null and (st_v is Dictionary):
			var st: Dictionary = st_v as Dictionary
			pop = int(st.get("population", 0))
	var max_scholars: int = maxi(0, pop / 15)
	lib["scholars_assigned"] = clampi(new_count, 0, max_scholars)
	_libraries[library_id] = lib
	return true

func get_preservation_factor(library_id: String) -> float:
	if not _library_exists(library_id):
		return 0.0
	return _libraries[library_id].get("preservation", 0.0)

func has_library(library_id: String) -> bool:
	return _library_exists(library_id)

func has_any_library_at(center: int) -> bool:
	var existing: Array[String] = _get_settlement_libraries(center)
	for lid in existing:
		var lib: Dictionary = _libraries.get(lid, {})
		if not lib.get("destroyed", false):
			return true
	return false

func get_scholar_count(library_id: String) -> int:
	if not _library_exists(library_id):
		return 0
	return _libraries[library_id].get("scholars_assigned", 0)

func get_settlement_scholar_count(center: int) -> int:
	var total: int = 0
	for lid in _get_settlement_libraries(center):
		var lib: Dictionary = _libraries.get(lid, {})
		if not lib.get("destroyed", false):
			total += lib.get("scholars_assigned", 0)
	return total

func find_books_by_knowledge_type(knowledge_type: int) -> Array:
	var results: Array = []
	for lid in _libraries:
		var lib: Dictionary = _libraries[lid]
		if lib.get("destroyed", false):
			continue
		for bk in lib.get("items", []):
			if bk.get("knowledge_type", -1) == knowledge_type:
				var entry: Dictionary = bk.duplicate()
				entry["_library_id"] = lid
				results.append(entry)
	return results

func find_oldest_book(library_id: String) -> Dictionary:
	if not _library_exists(library_id):
		return {}
	var items: Array = _libraries[library_id].get("items", [])
	if items.is_empty():
		return {}
	var oldest: Dictionary = items[0]
	for bk in items:
		if bk.get("tick", 0) < oldest.get("tick", 0):
			oldest = bk
	return oldest.duplicate()

func find_newest_book(library_id: String) -> Dictionary:
	if not _library_exists(library_id):
		return {}
	var items: Array = _libraries[library_id].get("items", [])
	if items.is_empty():
		return {}
	var newest: Dictionary = items[0]
	for bk in items:
		if bk.get("tick", 0) > newest.get("tick", 0):
			newest = bk
	return newest.duplicate()

func find_books_by_carrier(carrier_id: int) -> Array:
	var results: Array = []
	for lid in _libraries:
		var lib: Dictionary = _libraries[lid]
		if lib.get("destroyed", false):
			continue
		for bk in lib.get("items", []):
			if bk.get("carrier", -1) == carrier_id:
				var entry: Dictionary = bk.duplicate()
				entry["_library_id"] = lid
				results.append(entry)
	return results

func get_all_knowledge_in_library(library_id: String) -> Array:
	if not _library_exists(library_id):
		return []
	var items: Array = _libraries[library_id].get("items", [])
	if items.is_empty():
		return []
	var seen: Dictionary = {}
	var result: Array = []
	for bk in items:
		var kt: int = bk.get("knowledge_type", -1)
		if kt >= 0 and not seen.has(kt):
			seen[kt] = true
			result.append(kt)
	return result

func get_rarest_books(library_id: String, limit: int = 5) -> Array:
	if not _library_exists(library_id):
		return []
	var items: Array = _libraries[library_id].get("items", [])
	if items.is_empty():
		return []
	var type_freq: Dictionary = {}
	for bk in items:
		var kt: int = bk.get("knowledge_type", -1)
		type_freq[kt] = type_freq.get(kt, 0) + 1
	var scored: Array = []
	for bk in items:
		var kt: int = bk.get("knowledge_type", -1)
		var freq: int = type_freq.get(kt, 1)
		var rarity_score: float = 1.0 / float(freq)
		var entry: Dictionary = bk.duplicate()
		entry["_rarity_score"] = rarity_score
		scored.append(entry)
	scored.sort_custom(func(a, b): return a.get("_rarity_score", 0.0) > b.get("_rarity_score", 0.0))
	return scored.slice(0, mini(limit, scored.size()))

func get_most_preserved_books(library_id: String, limit: int = 5) -> Array:
	if not _library_exists(library_id):
		return []
	var items: Array = _libraries[library_id].get("items", [])
	if items.is_empty():
		return []
	var sorted: Array = items.duplicate()
	sorted.sort_custom(func(a, b): return a.get("preservation_factor", 0.0) > b.get("preservation_factor", 0.0))
	var result: Array = []
	for bk in sorted.slice(0, mini(limit, sorted.size())):
		result.append(bk.duplicate())
	return result

func upgrade_library_capacity(library_id: String, additional: int) -> bool:
	if not _library_exists(library_id):
		return false
	var lib: Dictionary = _libraries[library_id]
	if lib.get("destroyed", false):
		return false
	if additional <= 0:
		return false
	lib["capacity"] = lib.get("capacity", BASE_CAPACITY) + additional
	_libraries[library_id] = lib
	return true

func get_library_inventory(library_id: String) -> Dictionary:
	if not _library_exists(library_id):
		return {}
	var lib: Dictionary = _libraries[library_id]
	var items: Array = lib.get("items", [])
	var type_counts: Dictionary = {}
	for bk in items:
		var kt: int = bk.get("knowledge_type", -1)
		var kt_str: String = str(kt)
		type_counts[kt_str] = type_counts.get(kt_str, 0) + 1
	var avg_pres: float = _average_preservation(lib)
	var scholar_count: int = lib.get("scholars_assigned", 0)
	return {
		"library_id": library_id,
		"name": lib.get("name", ""),
		"center": lib.get("center", -1),
		"zone_id": lib.get("zone_id", ""),
		"capacity": lib.get("capacity", BASE_CAPACITY),
		"book_count": items.size(),
		"total_books_ever": lib.get("total_books_ever", 0),
		"preservation": lib.get("preservation", 0.0),
		"average_book_preservation": avg_pres,
		"scholars_assigned": scholar_count,
		"building_quality": lib.get("building_quality", 0.0),
		"founded_tick": lib.get("founded_tick", -1),
		"destroyed": lib.get("destroyed", false),
		"knowledge_type_breakdown": type_counts,
		"fullness_pct": float(items.size()) / float(maxi(1, lib.get("capacity", BASE_CAPACITY))) * 100.0,
	}

func get_stats() -> Dictionary:
	var total_libraries: int = 0
	var active_libraries: int = 0
	var destroyed_count: int = 0
	var total_items: int = 0
	var total_capacity: int = 0
	var total_scholars: int = 0
	var sum_preservation: float = 0.0
	var items_per_lib: Array = []
	var empty_libs: int = 0
	var fully_degraded_libs: int = 0
	for lid in _libraries:
		var lib: Dictionary = _libraries[lid]
		total_libraries += 1
		if lib.get("destroyed", false):
			destroyed_count += 1
			continue
		active_libraries += 1
		var items: Array = lib.get("items", [])
		var count: int = items.size()
		total_items += count
		total_capacity += lib.get("capacity", BASE_CAPACITY)
		total_scholars += lib.get("scholars_assigned", 0)
		sum_preservation += lib.get("preservation", 0.0)
		items_per_lib.append(count)
		if count == 0:
			empty_libs += 1
		var has_degraded: bool = true
		for bk in items:
			if bk.get("preservation_factor", 0.0) > 0.1:
				has_degraded = false
				break
		if has_degraded and count > 0:
			fully_degraded_libs += 1
	var avg_preservation: float = 0.0
	if active_libraries > 0:
		avg_preservation = sum_preservation / float(active_libraries)
	var total_known_types: int = 0
	var ks: Node = get_node_or_null("/root/KnowledgeSystem")
	if ks != null and ks.has_method("get_knowledge_status"):
		var status: Dictionary = ks.get_knowledge_status()
		total_known_types = status.size()
	return {
		"total_libraries": total_libraries,
		"active_libraries": active_libraries,
		"destroyed_libraries": destroyed_count,
		"total_books": total_items,
		"total_capacity": total_capacity,
		"total_scholars": total_scholars,
		"total_books_ever_deposited": _total_books_ever_deposited,
		"total_books_destroyed": _total_books_destroyed,
		"total_libraries_destroyed": _total_libraries_destroyed,
		"average_preservation": avg_preservation,
		"average_books_per_library": float(total_items) / float(maxi(1, active_libraries)),
		"empty_libraries": empty_libs,
		"fully_degraded_libraries": fully_degraded_libs,
		"capacity_utilization_pct": float(total_items) / float(maxi(1, total_capacity)) * 100.0,
		"total_known_knowledge_types": total_known_types,
		"books_per_type": _books_per_type(),
	}

func _books_per_type() -> Dictionary:
	var counts: Dictionary = {}
	for lid in _libraries:
		var lib: Dictionary = _libraries[lid]
		if lib.get("destroyed", false):
			continue
		for bk in lib.get("items", []):
			var kt: int = bk.get("knowledge_type", -1)
			var kt_str: String = str(kt)
			counts[kt_str] = counts.get(kt_str, 0) + 1
	return counts

func get_settlement_library_stats(center: int) -> Dictionary:
	var libs: Array[String] = _get_settlement_libraries(center)
	if libs.is_empty():
		return {
			"center": center,
			"library_count": 0,
			"active_libraries": 0,
			"total_books": 0,
			"total_capacity": 0,
			"total_scholars": 0,
		}
	var total_books: int = 0
	var total_capacity: int = 0
	var total_scholars: int = 0
	var active: int = 0
	var library_summaries: Array = []
	for lid in libs:
		var inv: Dictionary = get_library_inventory(lid)
		if inv.is_empty():
			continue
		library_summaries.append({
			"library_id": inv.get("library_id", ""),
			"name": inv.get("name", ""),
			"books": inv.get("book_count", 0),
			"capacity": inv.get("capacity", 0),
			"scholars": inv.get("scholars_assigned", 0),
			"preservation": inv.get("preservation", 0.0),
			"destroyed": inv.get("destroyed", false),
		})
		if not inv.get("destroyed", false):
			active += 1
			total_books += inv.get("book_count", 0)
			total_capacity += inv.get("capacity", 0)
			total_scholars += inv.get("scholars_assigned", 0)
	return {
		"center": center,
		"library_count": libs.size(),
		"active_libraries": active,
		"total_books": total_books,
		"total_capacity": total_capacity,
		"total_scholars": total_scholars,
		"libraries": library_summaries,
	}

func _on_settlement_founded(payload: Dictionary) -> void:
	if payload.is_empty():
		return
	var center: int = int(payload.get("center_region", payload.get("center", -1)))
	var tick: int = int(payload.get("tick", GameManager.tick_count if GameManager != null else 0))
	if center < 0:
		return
	var existing: Array[String] = _get_settlement_libraries(center)
	if not existing.is_empty():
		return
	var sm: Node = get_node_or_null("/root/SettlementMemory")
	if sm == null or not sm.has_method("get_settlement_at_region"):
		return
	var st_v: Variant = sm.get_settlement_at_region(center)
	if st_v == null or not (st_v is Dictionary):
		return
	var st: Dictionary = st_v as Dictionary
	var pop: int = int(st.get("population", 0))
	if pop < 10:
		return
	found_library(center, tick, "main", "")

func _on_settlement_destroyed(payload: Dictionary) -> void:
	if payload.is_empty():
		return
	var center: int = int(payload.get("center_region", payload.get("center", -1)))
	var tick: int = int(payload.get("tick", GameManager.tick_count if GameManager != null else 0))
	var cataclysm: String = str(payload.get("reason", payload.get("cataclysm", "settlement_destroyed")))
	if center < 0:
		return
	var lib_ids: Array[String] = _get_settlement_libraries(center)
	if lib_ids.is_empty():
		return
	for lid in lib_ids:
		var lib: Dictionary = _libraries.get(lid, {})
		if lib.is_empty():
			continue
		if lib.get("destroyed", false):
			continue
		var rng_seed: int = WorldRNG.stream_seed(StringName("lib_destruction:%s" % lid), tick) if WorldRNG != null else tick
		var survival_roll: float = float(rng_seed % 100) / 100.0 if rng_seed > 0 else 0.0
		var survival_chance: float = lib.get("preservation", 0.3) * 0.5
		if survival_roll < survival_chance:
			var preserved: Array = []
			var items: Array = lib.get("items", [])
			for bk in items:
				if bk.get("preservation_factor", 0.0) > 0.3:
					preserved.append(bk)
			lib["items"] = preserved
			lib["preservation"] = lib.get("preservation", 0.3) * 0.3
			_libraries[lid] = lib
		else:
			var book_count: int = lib.get("items", []).size()
			_total_books_destroyed += book_count
			_total_libraries_destroyed += 1
			lib["items"] = []
			lib["destroyed"] = true
			lib["destroyed_tick"] = tick
			lib["destroy_cataclysm"] = cataclysm
			_libraries[lid] = lib
			library_destroyed.emit(lid, center, tick)
			var wm: Node = get_node_or_null("/root/WorldMemory")
			if wm != null and wm.has_method("record_event"):
				wm.record_event({
					"type": "library_destroyed",
					"library_id": lid,
					"center": center,
					"zone_id": lib.get("zone_id", ""),
					"name": lib.get("name", ""),
					"cataclysm": cataclysm,
					"books_lost": book_count,
					"tick": tick,
				})

func _on_building_constructed(payload: Dictionary) -> void:
	if payload.is_empty():
		return
	var center: int = int(payload.get("center_region", payload.get("center", -1)))
	var tick: int = int(payload.get("tick", GameManager.tick_count if GameManager != null else 0))
	var building_type: String = str(payload.get("building_type", ""))
	if center < 0:
		return
	if building_type.to_lower().find("library") >= 0 or building_type.to_lower().find("archive") >= 0 or building_type.to_lower().find("scriptorium") >= 0:
		var existing: Array[String] = _get_settlement_libraries(center)
		var zone_key: String = "building_%s" % building_type
		var already_exists: bool = false
		for lid in existing:
			var lib: Dictionary = _libraries.get(lid, {})
			if lib.get("zone_id", "") == zone_key and not lib.get("destroyed", false):
				already_exists = true
				break
		if not already_exists and existing.size() < MAX_LIBRARIES_PER_SETTLEMENT:
			var lib_name: String = "%s Library" % building_type.capitalize()
			found_library(center, tick, zone_key, lib_name)
	var lib_ids: Array[String] = _get_settlement_libraries(center)
	if lib_ids.is_empty():
		return
	for lid in lib_ids:
		var lib: Dictionary = _libraries.get(lid, {})
		if lib.is_empty() or lib.get("destroyed", false):
			continue
		var st_v: Variant = null
		var sm: Node = get_node_or_null("/root/SettlementMemory")
		if sm != null and sm.has_method("get_settlement_at_region"):
			st_v = sm.get_settlement_at_region(center)
		if st_v != null and (st_v is Dictionary):
			var st: Dictionary = st_v as Dictionary
			lib["preservation"] = _calculate_preservation(lib, st)
			_libraries[lid] = lib

func get_library_info(library_id: String) -> Dictionary:
	return _libraries.get(library_id, {}).duplicate()

func get_library_by_id(library_id: String) -> Dictionary:
	return _libraries.get(library_id, {}).duplicate()

func get_all_library_ids() -> Array[String]:
	return _libraries.keys()

func get_libraries_near(center: int, radius: int) -> Array[String]:
	var results: Array[String] = []
	for lid in _libraries:
		var lib: Dictionary = _libraries[lid]
		if lib.get("destroyed", false):
			continue
		var lib_center: int = lib.get("center", -1)
		if lib_center < 0:
			continue
		if abs(lib_center - center) <= radius:
			results.append(lid)
	return results

func get_total_books_in_settlement(center: int) -> int:
	var total: int = 0
	for lid in _get_settlement_libraries(center):
		var lib: Dictionary = _libraries.get(lid, {})
		if not lib.get("destroyed", false):
			total += lib.get("items", []).size()
	return total

func get_average_preservation_in_settlement(center: int) -> float:
	var total_pf: float = 0.0
	var count: int = 0
	for lid in _get_settlement_libraries(center):
		var lib: Dictionary = _libraries.get(lid, {})
		if lib.get("destroyed", false):
			continue
		for bk in lib.get("items", []):
			total_pf += bk.get("preservation_factor", 0.0)
			count += 1
	if count == 0:
		return 0.0
	return total_pf / float(count)

func get_books_needing_restoration(library_id: String, threshold: float = 0.3) -> Array:
	if not _library_exists(library_id):
		return []
	var items: Array = _libraries[library_id].get("items", [])
	var result: Array = []
	for bk in items:
		if bk.get("preservation_factor", 0.0) < threshold:
			result.append(bk.duplicate())
	return result

func has_knowledge_in_libraries(center: int, knowledge_type: int) -> bool:
	for lid in _get_settlement_libraries(center):
		var lib: Dictionary = _libraries.get(lid, {})
		if lib.get("destroyed", false):
			continue
		for bk in lib.get("items", []):
			if bk.get("knowledge_type", -1) == knowledge_type:
				return true
	return false

func count_books_by_type(knowledge_type: int) -> int:
	var count: int = 0
	for lid in _libraries:
		var lib: Dictionary = _libraries[lid]
		if lib.get("destroyed", false):
			continue
		for bk in lib.get("items", []):
			if bk.get("knowledge_type", -1) == knowledge_type:
				count += 1
	return count

func save() -> Dictionary:
	var libs_save: Dictionary = {}
	for lid in _libraries:
		var lib: Dictionary = _libraries[lid]
		libs_save[lid] = lib.duplicate(true)
	return {
		"libraries": libs_save,
		"settlement_library_index": _settlement_library_index.duplicate(true),
		"next_seq": _next_library_seq,
		"last_tick": _last_library_tick,
		"last_maint_tick": _last_maintenance_tick,
		"total_deposited": _total_books_ever_deposited,
		"total_destroyed": _total_books_destroyed,
		"total_libs_destroyed": _total_libraries_destroyed,
		"critical_warnings": _emitted_critical_warnings.duplicate(true),
	}

func load(data: Dictionary) -> void:
	if data.is_empty():
		return
	clear()
	if data.has("libraries"):
		var libs: Dictionary = data["libraries"]
		for lid in libs:
			var lib: Dictionary = libs[lid]
			_libraries[lid] = lib.duplicate(true)
			var center: int = lib.get("center", -1)
			if center >= 0:
				_index_library(center, lid)
	if data.has("settlement_library_index"):
		_settlement_library_index = data["settlement_library_index"].duplicate(true)
	_next_library_seq = data.get("next_seq", 0)
	_last_library_tick = data.get("last_tick", -999999)
	_last_maintenance_tick = data.get("last_maint_tick", -999999)
	_total_books_ever_deposited = data.get("total_deposited", 0)
	_total_books_destroyed = data.get("total_destroyed", 0)
	_total_libraries_destroyed = data.get("total_libs_destroyed", 0)
	if data.has("critical_warnings"):
		_emitted_critical_warnings = data["critical_warnings"].duplicate(true)

func clear() -> void:
	_libraries.clear()
	_settlement_library_index.clear()
	_next_library_seq = 0
	_last_library_tick = -999999
	_last_maintenance_tick = -999999
	_total_books_ever_deposited = 0
	_total_books_destroyed = 0
	_total_libraries_destroyed = 0
	_emitted_critical_warnings.clear()

func get_books_above_preservation(library_id: String, threshold: float) -> Array:
	if not _library_exists(library_id):
		return []
	var items: Array = _libraries[library_id].get("items", [])
	var result: Array = []
	for bk in items:
		if bk.get("preservation_factor", 0.0) >= threshold:
			result.append(bk.duplicate())
	return result

func get_books_below_preservation(library_id: String, threshold: float) -> Array:
	if not _library_exists(library_id):
		return []
	var items: Array = _libraries[library_id].get("items", [])
	var result: Array = []
	for bk in items:
		if bk.get("preservation_factor", 0.0) < threshold:
			result.append(bk.duplicate())
	return result

func get_destroyed_libraries() -> Array:
	var result: Array = []
	for lid in _libraries:
		var lib: Dictionary = _libraries[lid]
		if lib.get("destroyed", false):
			var entry: Dictionary = lib.duplicate()
			entry["library_id"] = lid
			result.append(entry)
	return result

func get_library_count_by_settlement(center: int) -> int:
	return _get_settlement_libraries(center).size()

func get_total_library_count() -> int:
	return _libraries.size()

func get_global_book_count() -> int:
	var total: int = 0
	for lid in _libraries:
		var lib: Dictionary = _libraries[lid]
		if not lib.get("destroyed", false):
			total += lib.get("items", []).size()
	return total
