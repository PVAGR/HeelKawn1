class_name Job
extends RefCounted

## A single unit of work to be performed by a pawn at a specific tile.
## Jobs are created by game systems (world generation, designations, events),
## posted to JobManager, claimed by idle pawns, and retired on completion.

enum Type {
	FORAGE,     # harvest a FERTILE_SOIL tile -> berry (food)
	MINE,       # mine an ORE_VEIN tile       -> stone (and clears the feature)
	MINE_WALL,  # mine a MOUNTAIN edge tile   -> stone, converts tile to STONE_FLOOR
	CHOP,       # chop a TREE tile            -> wood (and clears the feature)
	HUNT,       # hunt a RABBIT/DEER tile     -> meat (clears the feature; respawns)
	BUILD_BED,  # consume 1 wood, place a BED feature on the target tile
	BUILD_WALL, # consume 2 wood, place a WALL feature, marks tile impassable
	BUILD_DOOR, # consume 1 wood, place a DOOR feature (passable)
	TRADE_HAUL, # pick from trade_from stockpile, walk to trade_to; inter-settlement transfer
	# --- Tool jobs ---
	GATHER_FLINT, # search for flint on rocky/gravel tiles
	GATHER_STICK, # pick up sticks from forest floor
	CRAFT_KNIFE,  # craft flint knife from flint + stick
	CRAFT_TORCH,  # craft torch from wood + stick
	CRAFT_PICK,   # craft flint pick from flint + wood
	CRAFT_SPEAR,  # craft wooden spear from stick + wood
	# --- Shelter / Storage / Hearth / Marker ---
	BUILD_FIRE_PIT,    # craft fire pit: wood + stone = warmth/cooking hub
	BUILD_STORAGE_HUT, # expand storage: wood + wood = higher capacity
	BUILD_MARKER_STONE,# carve marker: stone + stick = territorial marker
	BUILD_SHRINE,      # build shrine: wood + stone + stone = ritual site
	# --- Record Carriers (Phase 5: Knowledge Preservation) ---
	CARVE_GRAVE_MARKER,    # carve grave: stone = memory preservation
	CARVE_KNOWLEDGE_STONE, # carve knowledge: stone + scholar = knowledge storage
	CARVE_LEDGER_STONE,    # carve ledger: stone = settlement history record
	# --- Food chain ---
	COOK_MEAT,         # cook raw meat at fire pit
	COOK_BERRIES,      # cook berries at fire pit
	DRY_MEAT,          # smoke/dry meat for preservation
	PLANT_SEEDS,       # plant seeds on fertile soil for future harvest
	HARVEST_CROPS,     # harvest planted crops
	# --- Progression / social job hooks (optional posts; Impact wired in JobManager) ---
	BUILD_SHELTER,
	BUILD_HEARTH,
	TEACH_SKILL,
	APPRENTICESHIP,
	GROW_FOOD,
	PROTECT,
	DEFEND,
	PAPER_MAKING,
	LEATHER_MAKING,
	INK_MAKING,
	TOOL_MAKING,
	BOOK_BINDING,
}

enum State {
	OPEN,       # not yet assigned
	CLAIMED,    # a pawn is walking to or performing this job
	COMPLETED,  # finished successfully
	CANCELLED,  # aborted (e.g. tile became impassable, world regen, pawn died)
}

var id: int = 0
var type: int = Type.FORAGE

## Target tile: the thing being worked on (feature tile). May be impassable
## (e.g. an ore vein on a mountain).
var tile: Vector2i = Vector2i.ZERO

## Where the pawn actually stands while performing the work. For FORAGE this
## equals `tile`; for MINE it's an adjacent passable neighbor.
var work_tile: Vector2i = Vector2i.ZERO

## Higher priority jobs are claimed first. Default 0; food runs can use higher.
var priority: int = 0

## Ticks of work the pawn must spend ON the target tile to finish. Move time
## is separate; this is only the "doing the thing" phase.
var work_ticks_needed: int = 20
var work_ticks_done: int = 0

var state: int = State.OPEN
var assigned_pawn: Pawn = null

## [TRADE_HAUL] only: source / destination stockpiles and resource batch.
var trade_from: Stockpile = null
var trade_to: Stockpile = null
var trade_item: int = 0
var trade_batch: int = 0

## Stage 1: Tool requirement for this job (Item.Type.NONE = no tool required)
## Pawns must have the required tool equipped or nearby to perform the job
var required_tool: int = 0


static func describe_type(t: int) -> String:
	match t:
		Type.FORAGE:     return "Forage"
		Type.MINE:       return "Mine"
		Type.MINE_WALL:  return "MineWall"
		Type.CHOP:       return "Chop"
		Type.HUNT:       return "Hunt"
		Type.BUILD_BED:  return "BuildBed"
		Type.BUILD_WALL: return "BuildWall"
		Type.BUILD_DOOR: return "BuildDoor"
		Type.TRADE_HAUL: return "TradeHaul"
		Type.GATHER_FLINT: return "GatherFlint"
		Type.GATHER_STICK: return "GatherStick"
		Type.CRAFT_KNIFE:  return "CraftKnife"
		Type.CRAFT_TORCH:  return "CraftTorch"
		Type.CRAFT_PICK:   return "CraftPick"
		Type.CRAFT_SPEAR:  return "CraftSpear"
		Type.BUILD_FIRE_PIT:    return "BuildFirePit"
		Type.BUILD_STORAGE_HUT: return "BuildStorageHut"
		Type.BUILD_MARKER_STONE:return "BuildMarker"
		Type.BUILD_SHRINE:      return "BuildShrine"
		Type.CARVE_GRAVE_MARKER:    return "CarveGrave"
		Type.CARVE_KNOWLEDGE_STONE: return "CarveKnowledge"
		Type.CARVE_LEDGER_STONE:    return "CarveLedger"
		Type.COOK_MEAT:         return "CookMeat"
		Type.COOK_BERRIES:      return "CookBerries"
		Type.DRY_MEAT:          return "DryMeat"
		Type.PLANT_SEEDS:       return "PlantSeeds"
		Type.HARVEST_CROPS:     return "HarvestCrops"
		Type.BUILD_SHELTER:     return "BuildShelter"
		Type.BUILD_HEARTH:      return "BuildHearth"
		Type.TEACH_SKILL:       return "TeachSkill"
		Type.APPRENTICESHIP:    return "Apprenticeship"
		Type.GROW_FOOD:         return "GrowFood"
		Type.PROTECT:           return "Protect"
		Type.DEFEND:            return "Defend"
		Type.PAPER_MAKING:      return "PaperMaking"
		Type.LEATHER_MAKING:    return "LeatherMaking"
		Type.INK_MAKING:        return "InkMaking"
		Type.TOOL_MAKING:       return "ToolMaking"
		Type.BOOK_BINDING:      return "BookBinding"
	return "Unknown"


static func describe_state(s: int) -> String:
	match s:
		State.OPEN:      return "open"
		State.CLAIMED:   return "claimed"
		State.COMPLETED: return "completed"
		State.CANCELLED: return "cancelled"
	return "?"


func describe() -> String:
	return "Job#%d %s target=(%d,%d) work=(%d,%d) %s p=%d (%d/%d)" % [
		id, describe_type(type), tile.x, tile.y, work_tile.x, work_tile.y,
		describe_state(state), priority, work_ticks_done, work_ticks_needed
	]


# --- Tool job metadata ---

## Output item type produced when this job completes.
static func tool_job_output(job_type: int) -> int:
	match job_type:
		Type.GATHER_FLINT: return Item.Type.FLINT
		Type.GATHER_STICK: return Item.Type.STICK
		Type.CRAFT_KNIFE:  return Item.Type.FLINT_KNIFE
		Type.CRAFT_TORCH:  return Item.Type.TORCH
		Type.CRAFT_PICK:   return Item.Type.FLINT_PICK
		Type.CRAFT_SPEAR:  return Item.Type.WOODEN_SPEAR
		Type.COOK_MEAT:    return Item.Type.COOKED_MEAT
		Type.COOK_BERRIES: return Item.Type.COOKED_BERRIES
		Type.DRY_MEAT:     return Item.Type.DRIED_MEAT
		Type.PLANT_SEEDS:  return Item.Type.NONE  # transforms tile, no carry output
		Type.HARVEST_CROPS:return Item.Type.BERRY  # harvest yields berries (or better)
	return Item.Type.NONE


## Work ticks needed for each tool job type.
static func tool_job_work_ticks(job_type: int) -> int:
	match job_type:
		Type.GATHER_FLINT: return 15
		Type.GATHER_STICK: return 8
		Type.CRAFT_KNIFE:  return 20
		Type.CRAFT_TORCH:  return 12
		Type.CRAFT_PICK:   return 25
		Type.CRAFT_SPEAR:  return 18
		Type.BUILD_FIRE_PIT:    return 30
		Type.BUILD_STORAGE_HUT: return 35
		Type.BUILD_MARKER_STONE:return 25
		Type.BUILD_SHRINE:      return 45
		Type.CARVE_GRAVE_MARKER:    return 30  # Grave carving
		Type.CARVE_KNOWLEDGE_STONE: return 50  # Knowledge inscription takes longer
		Type.CARVE_LEDGER_STONE:    return 60  # Ledger requires detailed records
		Type.COOK_MEAT:         return 15
		Type.COOK_BERRIES:      return 10
		Type.DRY_MEAT:          return 25
		Type.PLANT_SEEDS:       return 12
		Type.HARVEST_CROPS:     return 15
	return 20  # default


## Which skill this job trains.
static func tool_job_skill(job_type: int) -> int:
	match job_type:
		Type.GATHER_FLINT: return PawnData.Skill.MINING
		Type.GATHER_STICK: return PawnData.Skill.FORAGING
		Type.CRAFT_KNIFE:  return PawnData.Skill.BUILDING
		Type.CRAFT_TORCH:  return PawnData.Skill.BUILDING
		Type.CRAFT_PICK:   return PawnData.Skill.BUILDING
		Type.CRAFT_SPEAR:  return PawnData.Skill.HUNTING
		Type.COOK_MEAT:    return PawnData.Skill.BUILDING
		Type.COOK_BERRIES: return PawnData.Skill.FORAGING
		Type.DRY_MEAT:     return PawnData.Skill.BUILDING
		Type.PLANT_SEEDS:  return PawnData.Skill.FORAGING
		Type.HARVEST_CROPS:return PawnData.Skill.FORAGING
		Type.CARVE_GRAVE_MARKER:    return PawnData.Skill.BUILDING  # Carving/inscription
		Type.CARVE_KNOWLEDGE_STONE: return PawnData.Skill.BUILDING  # Knowledge inscription
		Type.CARVE_LEDGER_STONE:    return PawnData.Skill.BUILDING  # Record-keeping
	return PawnData.Skill.FORAGING
