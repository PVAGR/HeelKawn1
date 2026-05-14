## Urge.gd — A single push from a drive.
##
## An urge is not a command. It's a desire. The UrgeQueue resolves competing
## urges and the body acts on the strongest one. Drives produce urges;
## the queue decides which one wins.
##
## The whole point: behavior emerges from competing internal pushes,
## not from a procedural checklist.
extends RefCounted
class_name Urge


enum Type {
	## ── Survival (from BodyDrive) ──
	EAT,            ## hunger → seek food (stockpile or direct forage)
	DRINK,          ## thirst → seek water
	SLEEP,          ## rest → sleep (bed or ground)
	WARM,           ## cold → seek fire/shelter
	HEAL,           ## injury → seek healing
	FLEE,           ## danger → flee to safety
	FORAGE,         ## hunger + no stockpile → direct forage (no job system)
	EAT_FROM_HAND,  ## starving + carrying food → eat it now

	## ── Emotional (from MemoryDrive) ──
	MOURN,          ## grief → visit grave
	CONFRONT,       ## grudge → confront target pawn
	AVOID,          ## trauma → avoid area/person
	PILGRIMAGE,     ## loss → visit memorial
	REMEMBER,       ## nostalgia / dream → visit meaningful place
	DREAM_NUDGE,    ## dream → follow dream suggestion

	## ── Social (from SocialDrive) ──
	SOCIALIZE,      ## loneliness → seek company
	TEACH,          ## knowledge → teach nearby pawn
	CHALLENGE,      ## authority → challenge peer
	AFFILIATE,      ## belonging → join household/clan
	GUARD,          ## warrior → patrol/defend settlement

	## ── Growth (from AmbitionDrive) ──
	WORK,           ## profession → do job matching skill
	BUILD,          ## settlement → build structure
	MASTER,         ## mastery → practice skill
	LEAD,           ## leadership → direct construction
	LEGACY,         ## legacy → create lasting work

	## ── Discovery (from CuriosityDrive) ──
	EXPLORE,        ## curiosity → visit unexplored tile
	REDISCOVER,     ## knowledge → visit dormant knowledge site
	FORGE,          ## crafting → try new recipe
	INNOVATE,       ## invention → attempt innovation
	WANDER,         ## restlessness → wander aimlessly
}

## Which drive produced this urge. Used for logging and interrupt rules.
enum Source {
	BODY,
	MEMORY,
	SOCIAL,
	AMBITION,
	CURIOSITY,
}

var type: Type
var priority: float
var source: Source
var target_tile: Vector2i = Vector2i(-999999, -999999)
var target_pawn_id: int = -1
var context: Dictionary = {}
var tick: int = 0

## Can this urge interrupt a committed action? Higher = more likely.
## Survival urges can always interrupt. Emotional urges only if very strong.
## Social/ambition/curiosity never interrupt.
var interrupt_strength: float = 0.0

## Human-readable label for debug/UI
var label: String = ""


func _init(p_type: Type = Type.WANDER, p_priority: float = 0.0, p_source: Source = Source.CURIOSITY, p_tick: int = 0) -> void:
	type = p_type
	priority = p_priority
	source = p_source
	tick = p_tick
	_compute_interrupt_strength()
	label = _type_label(p_type)


func _compute_interrupt_strength() -> void:
	match source:
		Source.BODY:
			# Survival urges can always interrupt. Strength scales with priority.
			interrupt_strength = priority * 0.5
		Source.MEMORY:
			# Only very strong emotional urges can interrupt (trauma, grief)
			if priority >= 7.0:
				interrupt_strength = priority * 0.3
			else:
				interrupt_strength = 0.0
		_:
			# Social, ambition, curiosity never interrupt a committed action
			interrupt_strength = 0.0


func _type_label(t: Type) -> String:
	match t:
		Type.EAT: return "eat"
		Type.DRINK: return "drink"
		Type.SLEEP: return "sleep"
		Type.WARM: return "warm"
		Type.HEAL: return "heal"
		Type.FLEE: return "flee"
		Type.FORAGE: return "forage"
		Type.EAT_FROM_HAND: return "eat_hand"
		Type.MOURN: return "mourn"
		Type.CONFRONT: return "confront"
		Type.AVOID: return "avoid"
		Type.PILGRIMAGE: return "pilgrimage"
		Type.REMEMBER: return "remember"
		Type.DREAM_NUDGE: return "dream"
		Type.SOCIALIZE: return "social"
		Type.TEACH: return "teach"
		Type.CHALLENGE: return "challenge"
		Type.AFFILIATE: return "affiliate"
		Type.GUARD: return "guard"
		Type.WORK: return "work"
		Type.BUILD: return "build"
		Type.MASTER: return "master"
		Type.LEAD: return "lead"
		Type.LEGACY: return "legacy"
		Type.EXPLORE: return "explore"
		Type.REDISCOVER: return "rediscover"
		Type.FORGE: return "forge"
		Type.INNOVATE: return "innovate"
		Type.WANDER: return "wander"
		_: return "unknown"


func describe() -> String:
	var s: String = "%s(%.1f)" % [label, priority]
	if target_tile.x >= -999000:
		s += " → %s" % [target_tile]
	if target_pawn_id >= 0:
		s += " → pawn#%d" % [target_pawn_id]
	if not context.is_empty():
		s += " %s" % [str(context)]
	return s
