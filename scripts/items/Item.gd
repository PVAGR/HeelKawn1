class_name Item
extends RefCounted

## Item types the colony produces, carries, stockpiles, and consumes.
## Kept as a plain enum + lookup tables until we need item data (stacking rules,
## nutrition, stack size). Item.Type.NONE means "no item" (e.g. pawn not carrying).

enum Type {
	NONE,
	BERRY,   # produced by FORAGE;    eaten to restore hunger
	STONE,   # produced by MINE/MINE_WALL; raw building material
	WOOD,    # produced by CHOP;      future: beds, walls, doors
	MEAT,    # produced by HUNT;      heartier food than berries
	# --- Tools (human-scale progression: hand → stone/stick → fire → knife) ---
	FLINT,           # raw flint stone for knapping
	STICK,           # gathered branch
	FLINT_KNIFE,     # crafted: flint + stick = basic cutting tool
	TORCH,           # crafted: wood + stick = fire tool
	FLINT_PICK,      # crafted: flint + wood = mining tool
	WOODEN_SPEAR,    # crafted: stick + wood = hunting tool
	# --- Food chain (cooking, preservation, seeds) ---
	COOKED_MEAT,     # cooked: more hunger restore, no spoilage
	DRIED_MEAT,      # preserved: long shelf life, moderate hunger
	SEEDS,           # planting: future food production
	COOKED_BERRIES,  # cooked berries: better nutrition
	PAPER,
	LEATHER,
	INK,
	PEN,
	BOOK,
	WRITTEN_BOOK,
	# --- Fishing ---
	FISH,            # caught by FISH job; good hunger restore
	COOKED_FISH,     # cooked fish: better nutrition
	# --- Ammo & crafting materials ---
	BONE,            # hunting byproduct (crafting material)
	STONE_ARROW,     # crafted: flint + stick → basic ranged ammo
	BONE_ARROW,      # crafted: bone + stick → better ranged ammo
}

## Display color for the carry-indicator above a pawn and for the stockpile icon.
const COLORS: Dictionary = {
	Type.NONE:        Color(0, 0, 0, 0),
	Type.BERRY:       Color8(229, 57,  53),   # bright red
	Type.STONE:       Color8(189, 189, 189),  # light gray
	Type.WOOD:        Color8(141,  85,  36),  # warm brown
	Type.MEAT:        Color8(178,  60,  60),  # darker, blood-red -- distinct from berry
	Type.FLINT:       Color8(120, 120, 130),  # cool gray
	Type.STICK:       Color8(160, 130,  80),  # light tan
	Type.FLINT_KNIFE: Color8(100, 100, 110),  # dark steel-gray
	Type.TORCH:       Color8(255, 180,  50),  # warm orange
	Type.FLINT_PICK:  Color8(110,  95,  85),  # brownish-gray
	Type.WOODEN_SPEAR:Color8(130,  90,  50),  # dark wood
	Type.COOKED_MEAT:  Color8(120,  50,  40),  # dark cooked brown
	Type.DRIED_MEAT:   Color8(160,  90,  50),  # tan dried meat
	Type.SEEDS:        Color8(180, 160,  80),  # golden seed color
	Type.COOKED_BERRIES:Color8(180,  40,  60), # deep cooked berry
	Type.PAPER: Color8(255, 255, 240), # off-white paper
	Type.LEATHER: Color8(139, 69, 19), # saddle brown
	Type.INK: Color8(25, 25, 112), # midnight blue
	Type.PEN: Color8(210, 180, 140), # tan feather shaft
	Type.BOOK: Color8(101, 67, 33), # saddle brown cover
	Type.WRITTEN_BOOK: Color8(101, 67, 33), # same as book
	Type.FISH: Color8( 70, 130, 180), # steel blue
	Type.COOKED_FISH: Color8(210, 140,  80), # cooked golden
	Type.BONE: Color8(220, 210, 190), # off-white bone
	Type.STONE_ARROW: Color8(140, 140, 150), # gray arrowhead
	Type.BONE_ARROW: Color8(200, 185, 165), # bone arrowhead
}

const NAMES: Dictionary = {
	Type.NONE:        "None",
	Type.BERRY:       "Berry",
	Type.STONE:       "Stone",
	Type.WOOD:        "Wood",
	Type.MEAT:        "Meat",
	Type.FLINT:       "Flint",
	Type.STICK:       "Stick",
	Type.FLINT_KNIFE: "Flint Knife",
	Type.TORCH:       "Torch",
	Type.FLINT_PICK:  "Flint Pick",
	Type.WOODEN_SPEAR:"Wooden Spear",
	Type.COOKED_MEAT:  "Cooked Meat",
	Type.DRIED_MEAT:   "Dried Meat",
	Type.SEEDS:        "Seeds",
	Type.COOKED_BERRIES:"Cooked Berries",
	Type.PAPER: "Paper",
	Type.LEATHER: "Leather",
	Type.INK: "Ink",
	Type.PEN: "Pen",
	Type.BOOK: "Book",
	Type.WRITTEN_BOOK: "Written Book",
	Type.FISH: "Fish",
	Type.COOKED_FISH: "Cooked Fish",
	Type.BONE: "Bone",
	Type.STONE_ARROW: "Stone Arrow",
	Type.BONE_ARROW: "Bone Arrow",
}

## Short single-letter label used in the stockpile's inventory readout.
const LABELS: Dictionary = {
	Type.NONE:        "-",
	Type.BERRY:       "B",
	Type.STONE:       "S",
	Type.WOOD:        "W",
	Type.MEAT:        "M",
	Type.FLINT:       "F",
	Type.STICK:       "T",
	Type.FLINT_KNIFE: "K",
	Type.TORCH:       "O",
	Type.FLINT_PICK:  "P",
	Type.WOODEN_SPEAR:"S",
	Type.COOKED_MEAT:  "C",
	Type.DRIED_MEAT:   "D",
	Type.SEEDS:        "E",
	Type.COOKED_BERRIES:"K",
	Type.PAPER: "P",
	Type.LEATHER: "L",
	Type.INK: "I",
	Type.PEN: "N",
	Type.BOOK: "B",
	Type.WRITTEN_BOOK: "W",
	Type.FISH: "F",
	Type.COOKED_FISH: "C",
	Type.BONE: "B",
	Type.STONE_ARROW: "a",
	Type.BONE_ARROW: "b",
}

## Hunger restored per unit when a pawn consumes this item. Non-food items
## map to 0 and won't be chosen by the "eat" behavior. Meat is significantly
## heartier than berries, so a single hunted deer is worth a meaningful chunk
## of the colony's daily food budget.
const HUNGER_RESTORE: Dictionary = {
	Type.NONE:        0.0,
	Type.BERRY:       60.0,
	Type.STONE:       0.0,
	Type.WOOD:        0.0,
	Type.MEAT:        85.0,
	Type.FLINT:       0.0,
	Type.STICK:       0.0,
	Type.FLINT_KNIFE: 0.0,
	Type.TORCH:       0.0,
	Type.FLINT_PICK:  0.0,
	Type.WOODEN_SPEAR:0.0,
	Type.COOKED_MEAT:  120.0,  # significantly better than raw
	Type.DRIED_MEAT:   95.0,   # preserved, slightly better than raw
	Type.SEEDS:        0.0,    # not eaten (unless famine)
	Type.COOKED_BERRIES:75.0,  # better than raw berries
	Type.PAPER: 0,
	Type.LEATHER: 0,
	Type.INK: 0,
	Type.PEN: 0,
	Type.BOOK: 0,
	Type.WRITTEN_BOOK: 0,
	Type.FISH: 75.0,       # raw fish, between berry and meat
	Type.COOKED_FISH: 110.0, # cooked, close to cooked meat
	Type.BONE: 0.0,
	Type.STONE_ARROW: 0.0,
	Type.BONE_ARROW: 0.0,
}


static func color_for(t: int) -> Color:
	return COLORS.get(t, Color.MAGENTA)


static func name_for(t: int) -> String:
	return NAMES.get(t, "Unknown")


static func label_for(t: int) -> String:
	return LABELS.get(t, "?")


static func hunger_restore(t: int) -> float:
	return HUNGER_RESTORE.get(t, 0.0)


static func is_food(t: int) -> bool:
	return HUNGER_RESTORE.get(t, 0.0) > 0.0


# --- Tool system ---

## Whether this item type is a tool (equipable, degrades, enables jobs).
const IS_TOOL: Dictionary = {
	Type.NONE:        false,
	Type.BERRY:       false,
	Type.STONE:       false,
	Type.WOOD:        false,
	Type.MEAT:        false,
	Type.FLINT:       false,   # raw material, not a tool
	Type.STICK:       false,   # raw material
	Type.FLINT_KNIFE: true,
	Type.TORCH:       true,
	Type.FLINT_PICK:  true,
	Type.WOODEN_SPEAR:true,
	Type.PAPER: false,
	Type.LEATHER: false,
	Type.INK: false,
	Type.PEN: false,
	Type.BOOK: false,
	Type.WRITTEN_BOOK: false,
	Type.FISH: false,
	Type.COOKED_FISH: false,
	Type.BONE: false,
	Type.STONE_ARROW: false,
	Type.BONE_ARROW: false,
}

## Durability: max uses before the tool breaks. Each job completion consumes 1 use.
const TOOL_DURABILITY: Dictionary = {
	Type.NONE:        0,
	Type.BERRY:       0,
	Type.STONE:       0,
	Type.WOOD:        0,
	Type.MEAT:        0,
	Type.FLINT:       0,
	Type.STICK:       0,
	Type.FLINT_KNIFE: 25,
	Type.TORCH:       40,
	Type.FLINT_PICK:  30,
	Type.WOODEN_SPEAR:20,
	Type.PAPER: 0,
	Type.LEATHER: 0,
	Type.INK: 0,
	Type.PEN: 0,
	Type.BOOK: 0,
	Type.WRITTEN_BOOK: 0,
	Type.FISH: 0,
	Type.COOKED_FISH: 0,
	Type.BONE: 0,
	Type.STONE_ARROW: 0,
	Type.BONE_ARROW: 0,
}

## Job efficacy multiplier per tool type. Maps Job.Type -> multiplier.
## Hand (no tool) always has a base multiplier; tools boost specific jobs.
const TOOL_EFFICACY: Dictionary = {
	Type.FLINT_KNIFE: {
		Job.Type.FORAGE: 1.3,
		Job.Type.HUNT:   1.2,
		Job.Type.CHOP:   1.1,
	},
	Type.TORCH: {
		Job.Type.FORAGE: 1.1,  # light helps find berries
		Job.Type.HUNT:   1.0,
	},
	Type.FLINT_PICK: {
		Job.Type.MINE:      1.5,
		Job.Type.MINE_WALL: 1.5,
	},
	Type.WOODEN_SPEAR: {
		Job.Type.HUNT: 1.6,
	},
}

## Crafting recipes: output_type -> [{input_type, qty}, ...]
## Only basic hand-crafting for now (no workbench required).
const CRAFTING_RECIPES: Dictionary = {
	Type.FLINT_KNIFE: [
		{"type": Type.FLINT, "qty": 1},
		{"type": Type.STICK, "qty": 1},
	],
	Type.TORCH: [
		{"type": Type.WOOD, "qty": 1},
		{"type": Type.STICK, "qty": 1},
	],
	Type.FLINT_PICK: [
		{"type": Type.FLINT, "qty": 2},
		{"type": Type.WOOD,  "qty": 1},
	],
	Type.WOODEN_SPEAR: [
		{"type": Type.STICK, "qty": 2},
		{"type": Type.WOOD,  "qty": 1},
	],
	Type.PAPER: [
		{"type": Type.STICK, "qty": 3},  # plant fibers proxy
	],
	Type.LEATHER: [
		{"type": Type.MEAT, "qty": 2},  # hides proxy
	],
	Type.INK: [
		{"type": Type.BERRY, "qty": 1},
		{"type": Type.STONE, "qty": 1},  # coal proxy
	],
	Type.PEN: [
		{"type": Type.STICK, "qty": 1},  # feather proxy
		{"type": Type.WOOD, "qty": 1},
		{"type": Type.MEAT, "qty": 1},  # leather strip proxy
	],
	Type.BOOK: [
		{"type": Type.PAPER, "qty": 5},
		{"type": Type.LEATHER, "qty": 2},
		{"type": Type.INK, "qty": 1},
	],
	# WRITTEN_BOOK crafted post-placement/write
	Type.BONE: [
		{"type": Type.MEAT, "qty": 1},  # bones from meat processing
	],
	Type.STONE_ARROW: [
		{"type": Type.FLINT, "qty": 1},
		{"type": Type.STICK, "qty": 1},
	],
	Type.BONE_ARROW: [
		{"type": Type.BONE, "qty": 1},
		{"type": Type.STICK, "qty": 1},
	],
}


static func is_tool_type(t: int) -> bool:
	return IS_TOOL.get(t, false)


static func tool_durability(t: int) -> int:
	return TOOL_DURABILITY.get(t, 0)


## Returns efficacy multiplier for a given job type when using this tool.
## Returns 1.0 if the tool provides no bonus for that job.
static func tool_efficacy(t: int, job_type: int) -> float:
	var efficacy_map: Dictionary = TOOL_EFFICACY.get(t, {})
	return float(efficacy_map.get(job_type, 1.0))


## Returns true if the item type can be crafted (has a recipe).
static func is_craftable(t: int) -> bool:
	return CRAFTING_RECIPES.has(t)


## Returns the recipe for a craftable item, or empty array if none.
static func get_recipe(t: int) -> Array:
	return CRAFTING_RECIPES.get(t, [])


# --- Food chain properties ---

## Spoilage rate: ticks until the item spoils (becomes unusable). 0 = never spoils.
## Raw meat spoils quickly; cooked/dried lasts much longer.
const FOOD_SPOILAGE_TICKS: Dictionary = {
	Type.NONE:         0,
	Type.BERRY:        8000,   # berries last a while
	Type.MEAT:         3000,   # raw meat spoils fast
	Type.COOKED_MEAT:  12000,  # cooking extends life significantly
	Type.DRIED_MEAT:   20000,  # drying extends life even more
	Type.COOKED_BERRIES:10000, # slightly better than raw
	Type.SEEDS:        50000,  # seeds last longest (meant for planting)
	Type.FISH:         2500,   # raw fish spoils fast
	Type.COOKED_FISH:  12000,  # cooked fish lasts
	Type.BONE:         0,
	Type.STONE_ARROW:  0,
	Type.BONE_ARROW:   0,
}

## Cooking recipes: output_type -> [{input_type, qty}, ...]
## Requires a fire pit (hearth) nearby.
const COOKING_RECIPES: Dictionary = {
	Type.COOKED_MEAT: [
		{"type": Type.MEAT, "qty": 1},
		{"type": Type.WOOD, "qty": 1},  # fuel
	],
	Type.COOKED_BERRIES: [
		{"type": Type.BERRY, "qty": 2},
		{"type": Type.WOOD, "qty": 1},  # fuel
	],
	Type.DRIED_MEAT: [
		{"type": Type.MEAT, "qty": 2},
		{"type": Type.WOOD, "qty": 1},  # fuel for smoking
	],
	Type.COOKED_FISH: [
		{"type": Type.FISH, "qty": 1},
		{"type": Type.WOOD, "qty": 1},  # fuel
	],
}

## Famine food: items pawns will eat when starving (even seeds).
const IS_FAMINE_FOOD: Dictionary = {
	Type.SEEDS: true,
}


static func food_spoilage_ticks(t: int) -> int:
	return FOOD_SPOILAGE_TICKS.get(t, 0)


static func is_perishable(t: int) -> bool:
	return food_spoilage_ticks(t) > 0


static func can_cook(t: int) -> bool:
	return COOKING_RECIPES.has(t)


static func get_cooking_recipe(t: int) -> Array:
	return COOKING_RECIPES.get(t, [])


static func is_famine_food(t: int) -> bool:
	return IS_FAMINE_FOOD.get(t, false)
