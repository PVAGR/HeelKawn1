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
	COOK_FISH,         # cook fish at fire pit
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
	# --- Agriculture buildings (Phase 6: Civilization Progression) ---
	BUILD_FARM_WHEAT,
	BUILD_FARM_CORN,
	BUILD_FARM_VEGETABLES,
	BUILD_HERB_GARDEN,
	# --- Production buildings (Phase 6) ---
	BUILD_WORKSHOP,
	BUILD_LOOM,
	BUILD_KILN,
	BUILD_SMELTER,
	# --- Maritime buildings (Phase 6) ---
	BUILD_BOATYARD,
	BUILD_DOCK,
	BUILD_FISHERMAN_HUT,
	# --- Medicine buildings (Phase 6) ---
	BUILD_APOTHECARY,
	# --- Knowledge buildings (Phase 6) ---
	BUILD_LIBRARY,
	BUILD_SCHOOL,
	# --- Military buildings (Phase 6) ---
	BUILD_BARRACKS,
	BUILD_WATCHTOWER,
	# --- Trade buildings (Phase 6) ---
	BUILD_MARKET,
	BUILD_TRADING_POST,
	# --- Infrastructure (Phase 6) ---
	BUILD_ROAD,
	# --- Storage buildings (Phase 6) ---
	BUILD_GRANARY,
	BUILD_CELLAR,
	# --- Fishing (Phase 6) ---
	FISH,            # catch fish at RIVER tiles; yields FISH item
	# --- River Crossings ---
	BUILD_FORD,      # build a ford crossing on river tile
	# --- Production (Phase 6) ---
	BUILD_WATER_MILL,# build a water mill adjacent to river
	# --- Prisoner / Guard ---
	GUARD,           # guard prisoners to prevent escape and enable recruitment
	# --- Social / Ritual ---
	VISIT_GRAVE,     # internal: pawn visits a grave marker for mood recovery
	# --- Living settlement upkeep ---
	MAINTAIN_STRUCTURE, # repair / preserve homes, walls, roads, hearths before decay
	# --- Brewing & Social (Phase 7) ---
	BUILD_BREWERY,   # build a brewery near water
	BUILD_TAVERN,    # build a tavern for social drinking
	BREW_MEAD,       # brew mead at brewery
	BREW_ALE,        # brew ale at brewery
	DRINK,           # drink at tavern (mood boost, intoxication)
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
var assigned_pawn: HeelKawnian = null

## [TRADE_HAUL] only: source / destination stockpiles and resource batch.
var trade_from: Stockpile = null
var trade_to: Stockpile = null
var trade_item: int = 0
var trade_batch: int = 0

## Stage 1: Tool requirement for this job (Item.Type.NONE = no tool required)
## Pawns must have the required tool equipped or nearby to perform the job
var required_tool: int = 0

## === Authority / social metadata ===
var issuer_pawn_id: int = -1
var issuer_role: String = "" # leader, architect, elder, household_head, self, emergency, player_intent, debug
var authority_scope: String = "nearby" # self, household, band, proto_camp, formal_settlement, guild, faction, nearby, all
var settlement_id: int = -1
var proto_camp_id: int = -1
var region_key: int = -1
var eligible_member_ids: Array = []
var reason: String = "" # hunger, shelter, wall_plan, repair, harvest, defense, teaching, ritual, exploration
var plan_id: int = -1
var visible_to: String = "nearby" # local, settlement, nearby, all, self
var social_weight: float = 1.0


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
		Type.COOK_FISH:         return "CookFish"
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
		# Phase 6: new buildings
		Type.BUILD_FARM_WHEAT:       return "BuildWheatFarm"
		Type.BUILD_FARM_CORN:        return "BuildCornFarm"
		Type.BUILD_FARM_VEGETABLES:  return "BuildVegGarden"
		Type.BUILD_HERB_GARDEN:      return "BuildHerbGarden"
		Type.BUILD_WORKSHOP:         return "BuildWorkshop"
		Type.BUILD_LOOM:             return "BuildLoom"
		Type.BUILD_KILN:             return "BuildKiln"
		Type.BUILD_SMELTER:          return "BuildSmelter"
		Type.BUILD_BOATYARD:         return "BuildBoatyard"
		Type.BUILD_DOCK:             return "BuildDock"
		Type.BUILD_FISHERMAN_HUT:    return "BuildFishermanHut"
		Type.BUILD_APOTHECARY:       return "BuildApothecary"
		Type.BUILD_LIBRARY:          return "BuildLibrary"
		Type.BUILD_SCHOOL:           return "BuildSchool"
		Type.BUILD_BARRACKS:         return "BuildBarracks"
		Type.BUILD_WATCHTOWER:       return "BuildWatchtower"
		Type.BUILD_MARKET:           return "BuildMarket"
		Type.BUILD_TRADING_POST:     return "BuildTradingPost"
		Type.BUILD_ROAD:             return "BuildRoad"
		Type.BUILD_GRANARY:          return "BuildGranary"
		Type.BUILD_CELLAR:           return "BuildCellar"
		Type.FISH:                  return "Fish"
		Type.BUILD_FORD:            return "BuildFord"
		Type.BUILD_WATER_MILL:      return "BuildWaterMill"
		Type.GUARD:                return "Guard"
		Type.VISIT_GRAVE:          return "VisitGrave"
		Type.MAINTAIN_STRUCTURE:   return "MaintainStructure"
		Type.BUILD_BREWERY:         return "BuildBrewery"
		Type.BUILD_TAVERN:          return "BuildTavern"
		Type.BREW_MEAD:            return "BrewMead"
		Type.BREW_ALE:             return "BrewAle"
		Type.DRINK:                return "Drink"
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
		Type.COOK_FISH:    return Item.Type.COOKED_FISH
		Type.DRY_MEAT:     return Item.Type.DRIED_MEAT
		Type.PLANT_SEEDS:  return Item.Type.NONE  # transforms tile, no carry output
		Type.HARVEST_CROPS:return Item.Type.BERRY  # harvest yields berries (or better)
	return Item.Type.NONE


## Work ticks needed for each tool job type.
static func tool_job_work_ticks(job_type: int) -> int:
	match job_type:
		Type.GATHER_FLINT: return 8   # Faster (was 15)
		Type.GATHER_STICK: return 4   # Faster (was 8)
		Type.CRAFT_KNIFE:  return 10  # Faster (was 20)
		Type.CRAFT_TORCH:  return 6   # Faster (was 12)
		Type.CRAFT_PICK:   return 12  # Faster (was 25)
		Type.CRAFT_SPEAR:  return 8   # Faster (was 18)
		Type.BUILD_FIRE_PIT:    return 12  # Much faster (was 30)
		Type.BUILD_STORAGE_HUT: return 15  # Much faster (was 35)
		Type.BUILD_MARKER_STONE:return 10  # Much faster (was 25)
		Type.BUILD_SHRINE:      return 20  # Much faster (was 45)
		Type.CARVE_GRAVE_MARKER:    return 15  # Faster (was 30)
		Type.CARVE_KNOWLEDGE_STONE: return 25  # Faster (was 50)
		Type.CARVE_LEDGER_STONE:    return 30  # Faster (was 60)
		Type.COOK_MEAT:         return 8   # Faster (was 15)
		Type.COOK_BERRIES:      return 5   # Faster (was 10)
		Type.COOK_FISH:         return 6
		Type.DRY_MEAT:          return 12  # Faster (was 25)
		Type.PLANT_SEEDS:       return 6   # Faster (was 12)
		Type.HARVEST_CROPS:     return 8   # Faster (was 15)
		# Phase 6: new building work ticks
		Type.BUILD_FARM_WHEAT:       return 30
		Type.BUILD_FARM_CORN:        return 30
		Type.BUILD_FARM_VEGETABLES:  return 30
		Type.BUILD_HERB_GARDEN:      return 30
		Type.BUILD_WORKSHOP:         return 40
		Type.BUILD_LOOM:             return 35
		Type.BUILD_KILN:             return 40
		Type.BUILD_SMELTER:          return 50
		Type.BUILD_BOATYARD:         return 60
		Type.BUILD_DOCK:             return 45
		Type.BUILD_FISHERMAN_HUT:    return 30
		Type.BUILD_APOTHECARY:       return 40
		Type.BUILD_LIBRARY:          return 50
		Type.BUILD_SCHOOL:           return 40
		Type.BUILD_BARRACKS:         return 45
		Type.BUILD_WATCHTOWER:       return 35
		Type.BUILD_MARKET:           return 40
		Type.BUILD_TRADING_POST:     return 35
		Type.BUILD_ROAD:             return 15
		Type.BUILD_GRANARY:          return 35
		Type.BUILD_CELLAR:           return 40
		Type.BUILD_BREWERY:         return 50
		Type.BUILD_TAVERN:          return 60
		Type.BREW_MEAD:            return 30
		Type.BREW_ALE:             return 25
		Type.DRINK:                return 5
		Type.MAINTAIN_STRUCTURE:     return 8
	return 10  # Faster default (was 20)


## Which skill this job trains.
static func tool_job_skill(job_type: int) -> int:
	match job_type:
		Type.GATHER_FLINT: return HeelKawnianData.Skill.MINING
		Type.GATHER_STICK: return HeelKawnianData.Skill.FORAGING
		Type.CRAFT_KNIFE:  return HeelKawnianData.Skill.BUILDING
		Type.CRAFT_TORCH:  return HeelKawnianData.Skill.BUILDING
		Type.CRAFT_PICK:   return HeelKawnianData.Skill.BUILDING
		Type.CRAFT_SPEAR:  return HeelKawnianData.Skill.HUNTING
		Type.COOK_MEAT:    return HeelKawnianData.Skill.BUILDING
		Type.COOK_BERRIES: return HeelKawnianData.Skill.FORAGING
		Type.COOK_FISH:    return HeelKawnianData.Skill.FORAGING
		Type.DRY_MEAT:     return HeelKawnianData.Skill.BUILDING
		Type.PLANT_SEEDS:  return HeelKawnianData.Skill.FORAGING
		Type.HARVEST_CROPS:return HeelKawnianData.Skill.FORAGING
		Type.CARVE_GRAVE_MARKER:    return HeelKawnianData.Skill.BUILDING  # Carving/inscription
		Type.CARVE_KNOWLEDGE_STONE: return HeelKawnianData.Skill.BUILDING  # Knowledge inscription
		Type.CARVE_LEDGER_STONE:    return HeelKawnianData.Skill.BUILDING  # Record-keeping
		# Phase 6: new building skills
		Type.BUILD_FARM_WHEAT, Type.BUILD_FARM_CORN, Type.BUILD_FARM_VEGETABLES, Type.BUILD_HERB_GARDEN:
			return HeelKawnianData.Skill.FORAGING  # Agriculture
		Type.BUILD_WORKSHOP, Type.BUILD_LOOM, Type.BUILD_KILN, Type.BUILD_SMELTER:
			return HeelKawnianData.Skill.BUILDING  # Production
		Type.BUILD_BOATYARD, Type.BUILD_DOCK, Type.BUILD_FISHERMAN_HUT:
			return HeelKawnianData.Skill.BUILDING  # Maritime construction
		Type.BUILD_APOTHECARY:
			return HeelKawnianData.Skill.BUILDING  # Medicine
		Type.BUILD_LIBRARY, Type.BUILD_SCHOOL:
			return HeelKawnianData.Skill.BUILDING  # Knowledge
		Type.BUILD_BARRACKS, Type.BUILD_WATCHTOWER:
			return HeelKawnianData.Skill.BUILDING  # Military
		Type.BUILD_MARKET, Type.BUILD_TRADING_POST:
			return HeelKawnianData.Skill.BUILDING  # Trade
		Type.BUILD_ROAD:
			return HeelKawnianData.Skill.BUILDING  # Infrastructure
		Type.BUILD_GRANARY, Type.BUILD_CELLAR:
			return HeelKawnianData.Skill.BUILDING  # Storage
		Type.BUILD_BREWERY, Type.BUILD_TAVERN:
			return HeelKawnianData.Skill.BUILDING  # Brewing & social
		Type.BREW_MEAD, Type.BREW_ALE:
			return HeelKawnianData.Skill.BUILDING  # Brewing
		Type.DRINK:
			return HeelKawnianData.Skill.FORAGING  # Drinking is easy
		Type.MAINTAIN_STRUCTURE:
			return HeelKawnianData.Skill.BUILDING
	return HeelKawnianData.Skill.FORAGING
