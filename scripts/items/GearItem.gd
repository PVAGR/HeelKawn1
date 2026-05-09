class_name GearItem
extends RefCounted

## Individual equipment piece with stats, quality, durability, and enchantments.
## All gear is crafted by HeelKawnians — no gear spawns from nothing.
## Caves of Qud meets Baldur's Gate: each piece has its own identity.

enum Slot { WEAPON, ARMOR, TOOL, ACCESSORY, OFFHAND }

const SLOT_NAMES: Dictionary = {
	Slot.WEAPON: "Weapon",
	Slot.ARMOR: "Armor",
	Slot.TOOL: "Tool",
	Slot.ACCESSORY: "Accessory",
	Slot.OFFHAND: "Offhand",
}

## Quality tiers
enum Quality { POOR, NORMAL, FINE, MASTERWORK }

const QUALITY_NAMES: Dictionary = {
	Quality.POOR: "Poor",
	Quality.NORMAL: "Normal",
	Quality.FINE: "Fine",
	Quality.MASTERWORK: "Masterwork",
}

const QUALITY_MULT: Dictionary = {
	Quality.POOR: 0.6,
	Quality.NORMAL: 1.0,
	Quality.FINE: 1.3,
	Quality.MASTERWORK: 1.7,
}

const QUALITY_MIN_MULT: Dictionary = {
	Quality.POOR: 0.5,
	Quality.NORMAL: 0.8,
	Quality.FINE: 1.2,
	Quality.MASTERWORK: 1.5,
}

## Unique instance ID for this gear piece
var item_id: String = ""
## Base item type this gear is derived from (Item.Type)
var base_type: int = 0
## Which equipment slot this occupies
var slot: int = Slot.WEAPON
## Display name (may be custom, e.g. "Ashhold's Fine Flint Knife")
var name: String = ""
## Quality tier
var quality: int = Quality.NORMAL
## Quality multiplier (computed from tier + RNG within tier range)
var quality_mult: float = 1.0
## Current durability (uses remaining)
var durability: int = 0
## Maximum durability
var max_durability: int = 0
## Combat stats
var attack: float = 0.0
var defense: float = 0.0
## Work stat
var work_speed: float = 0.0
## Warmth bonus
var warmth: float = 0.0
## Passive buff description
var buff_description: String = ""
## Enchantments on this item
var enchantments: Array = []  # Array of {name: String, effect: String, potency: float}
## ID of the HeelKawnian who crafted this (-1 = natural/found)
var crafter_id: int = -1
## Display name of the crafter
var crafter_name: String = ""
## Tick when this was crafted
var crafted_tick: int = 0


static func make_id() -> String:
	# Deterministic ID from tick + random
	var tick: int = GameManager.tick_count if GameManager != null else 0
	return "gear_%d_%d" % [tick, WorldRNG.range_for(StringName("gear_id:%d" % tick), 0, 999999)]


## Create a basic gear item from an Item.Type
static func from_item_type(item_type: int, crafter: HeelKawnianData = null) -> GearItem:
	var g: GearItem = GearItem.new()
	g.item_id = make_id()
	g.base_type = item_type
	g.crafted_tick = GameManager.tick_count if GameManager != null else 0

	# Determine slot from item type
	g.slot = _slot_for_item_type(item_type)
	g.name = Item.name_for(item_type)

	# Quality from crafter skill (or NORMAL if no crafter)
	if crafter != null:
		var craft_skill: int = int(crafter.skills.get("crafting", 0))
		if craft_skill >= 90:
			g.quality = Quality.MASTERWORK
		elif craft_skill >= 60:
			g.quality = Quality.FINE
		elif craft_skill >= 30:
			g.quality = Quality.NORMAL
		else:
			g.quality = Quality.POOR
		g.crafter_id = int(crafter.id)
		g.crafter_name = str(crafter.display_name)
	else:
		g.quality = Quality.NORMAL

	# Quality multiplier (random within tier range)
	var min_m: float = float(QUALITY_MIN_MULT.get(g.quality, 0.8))
	var max_m: float = float(QUALITY_MULT.get(g.quality, 1.0))
	g.quality_mult = WorldRNG.range_for(
		StringName("gear_quality:%s:%d" % [g.item_id, g.crafted_tick]),
		min_m, max_m
	)

	# Base stats from item type
	g._apply_base_stats(item_type)

	# Apply quality multiplier
	g.attack *= g.quality_mult
	g.defense *= g.quality_mult
	g.work_speed *= g.quality_mult
	g.warmth *= g.quality_mult

	# Durability
	var base_dur: int = Item.tool_durability(item_type)
	if base_dur <= 0:
		base_dur = 50  # Default for non-tool items
	g.max_durability = int(float(base_dur) * g.quality_mult)
	g.durability = g.max_durability

	# Name prefix for quality
	if g.quality == Quality.FINE:
		g.name = "Fine " + g.name
	elif g.quality == Quality.MASTERWORK:
		if g.crafter_name != "":
			g.name = "%s's %s" % [g.crafter_name, g.name]
		else:
			g.name = "Masterwork " + g.name
	elif g.quality == Quality.POOR:
		g.name = "Crude " + g.name

	return g


## Apply base stats from Item.Type
func _apply_base_stats(item_type: int) -> void:
	match item_type:
		Item.Type.FLINT_KNIFE:
			attack = 5.0
			work_speed = 0.3
		Item.Type.WOODEN_SPEAR:
			attack = 8.0
		Item.Type.FLINT_PICK:
			attack = 3.0
			work_speed = 0.5
		Item.Type.TORCH:
			attack = 2.0
			warmth = 3.0
		Item.Type.LEATHER:
			defense = 3.0
			warmth = 2.0
		_:
			attack = 1.0  # Bare fists default


## Determine equipment slot from Item.Type
static func _slot_for_item_type(item_type: int) -> int:
	match item_type:
		Item.Type.FLINT_KNIFE, Item.Type.WOODEN_SPEAR:
			return Slot.WEAPON
		Item.Type.LEATHER:
			return Slot.ARMOR
		Item.Type.FLINT_PICK, Item.Type.TORCH:
			return Slot.TOOL
		_:
			return Slot.WEAPON  # Default


## Use the item (decrement durability). Returns true if still usable.
func use() -> bool:
	if durability <= 0:
		return false
	durability -= 1
	return durability > 0


## Is this item broken?
func is_broken() -> bool:
	return durability <= 0


## Add an enchantment to this item
func add_enchantment(enchant_name: String, effect: String, potency: float) -> void:
	if enchantments.size() >= 1:  # Max 1 enchantment initially
		return
	enchantments.append({
		"name": enchant_name,
		"effect": effect,
		"potency": potency,
	})
	# Update name
	if not name.begins_with("Enchanted"):
		name = "Enchanted " + name
	# Apply enchantment effects
	match effect:
		"attack_bonus":
			attack += potency
		"defense_bonus":
			defense += potency
		"work_speed_bonus":
			work_speed += potency
		"warmth_bonus":
			warmth += potency


## Serialize for save
func to_dict() -> Dictionary:
	var ench_ser: Array = []
	for e in enchantments:
		ench_ser.append(e.duplicate(true))
	return {
		"item_id": item_id,
		"base_type": base_type,
		"slot": slot,
		"name": name,
		"quality": quality,
		"quality_mult": quality_mult,
		"durability": durability,
		"max_durability": max_durability,
		"attack": attack,
		"defense": defense,
		"work_speed": work_speed,
		"warmth": warmth,
		"buff_description": buff_description,
		"enchantments": ench_ser,
		"crafter_id": crafter_id,
		"crafter_name": crafter_name,
		"crafted_tick": crafted_tick,
	}


## Deserialize from save
static func from_dict(d: Dictionary) -> GearItem:
	var g: GearItem = GearItem.new()
	g.item_id = str(d.get("item_id", ""))
	g.base_type = int(d.get("base_type", 0))
	g.slot = int(d.get("slot", Slot.WEAPON))
	g.name = str(d.get("name", ""))
	g.quality = int(d.get("quality", Quality.NORMAL))
	g.quality_mult = float(d.get("quality_mult", 1.0))
	g.durability = int(d.get("durability", 0))
	g.max_durability = int(d.get("max_durability", 0))
	g.attack = float(d.get("attack", 0.0))
	g.defense = float(d.get("defense", 0.0))
	g.work_speed = float(d.get("work_speed", 0.0))
	g.warmth = float(d.get("warmth", 0.0))
	g.buff_description = str(d.get("buff_description", ""))
	g.enchantments = []
	if d.has("enchantments") and d["enchantments"] is Array:
		for e in d["enchantments"]:
			if e is Dictionary:
				g.enchantments.append((e as Dictionary).duplicate(true))
	g.crafter_id = int(d.get("crafter_id", -1))
	g.crafter_name = str(d.get("crafter_name", ""))
	g.crafted_tick = int(d.get("crafted_tick", 0))
	return g


## Short description for tooltip
func short_desc() -> String:
	var parts: PackedStringArray = []
	if attack > 0.0:
		parts.append("ATK %.0f" % attack)
	if defense > 0.0:
		parts.append("DEF %.0f" % defense)
	if work_speed > 0.0:
		parts.append("SPD +%.0f%%" % (work_speed * 100.0))
	if warmth > 0.0:
		parts.append("WRM +%.0f" % warmth)
	var desc: String = " | ".join(parts)
	if not enchantments.is_empty():
		desc += " *"
	return desc
