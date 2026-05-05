extends RefCounted
class_name SettlementLegend

## Phase 5: Settlement Legends Generator
## Generates emergent stories and myths about settlements based on their history.
## Legends are derived from actual events, not hardcoded.

const LEGEND_SECTIONS: int = 5

## Generate a legend for a settlement based on its history.
static func generate_legend(settlement_id: int, settlement_name: String, events: Array[Dictionary]) -> String:
	if events.is_empty():
		return _generate_founding_legend(settlement_name)
	
	var text: String = ""
	
	# Header
	text += "[color=#FFD166][b]━━━ THE LEGEND OF %s ━━━[/b][/color]\n\n" % settlement_name.to_upper()
	
	# Analyze settlement history
	var stats: Dictionary = _analyze_settlement_history(events)
	
	# Section 1: Founding
	text += "[color=#B084CC][b]THE FOUNDING[/b][/color]\n"
	text += _generate_founding_story(settlement_name, stats)
	text += "\n"
	
	# Section 2: Character
	text += "[color=#B084CC][b]THE SETTLEMENT'S CHARACTER[/b][/color]\n"
	text += _generate_character_story(settlement_name, stats)
	text += "\n"
	
	# Section 3: Trials
	text += "[color=#B084CC][b]TRIALS OVERCOME[/b][/color]\n"
	text += _generate_trials_story(settlement_name, stats)
	text += "\n"
	
	# Section 4: Heroes
	text += "[color=#B084CC][b]REMEMBERED HEROES[/b][/color]\n"
	text += _generate_heroes_story(settlement_name, events)
	text += "\n"
	
	# Section 5: Legacy
	text += "[color=#FFD166][b]THE ENDURING LEGACY[/b][/color]\n"
	text += _generate_legacy_story(settlement_name, stats)
	
	return text


## Analyze settlement history for story generation.
static func _analyze_settlement_history(events: Array[Dictionary]) -> Dictionary:
	var stats: Dictionary = {
		"births": 0,
		"deaths": 0,
		"buildings": 0,
		"knowledge_inscribed": 0,
		"teachings": 0,
		"friendships": 0,
		"abandonments": 0,
		"revivals": 0,
		"total_events": events.size()
	}
	
	for ev in events:
		var event_type: String = str(ev.get("type", "unknown"))
		match event_type:
			"birth", "pawn_birth":
				stats.births = int(stats.get("births", 0)) + 1
			"pawn_death":
				stats.deaths = int(stats.get("deaths", 0)) + 1
			"building_constructed":
				stats.buildings = int(stats.buildings) + 1
			"knowledge_inscribed":
				stats.knowledge_inscribed = int(stats.knowledge_inscribed) + 1
			"teaching_event":
				stats.teachings = int(stats.teachings) + 1
			"social_bond_milestone":
				stats.friendships = int(stats.friendships) + 1
			"settlement_abandoned":
				stats.abandonments = int(stats.abandonments) + 1
			"settlement_revived":
				stats.revivals = int(stats.revivals) + 1
	
	return stats


## Generate founding story.
static func _generate_founding_story(settlement_name: String, stats: Dictionary) -> String:
	var total: int = stats.get("total_events", 0)
	var births: int = stats.get("births", 0)
	
	if total < 10:
		return "  In the beginning, [color=#FFD166]%s[/color] was but a dream in the mind of its founder. A single soul walked these lands, seeking a place to call home. The first fire was lit, the first shelter raised, and from that humble beginning, a community was born.\n" % settlement_name
	elif births > 20:
		return "  [color=#FFD166]%s[/color] began as a beacon of hope. Many came seeking a new life, drawn by tales of fertile lands and kind hearts. Children were born under its sky, and the settlement grew from a single hearth to a thriving home for many families.\n" % settlement_name
	else:
		return "  The story of [color=#FFD166]%s[/color] began with determination. Its founders chose this place with purpose, building shelter from the raw land. Each dawn brought new work, each dusk brought rest, and slowly, a home emerged from the wilderness.\n" % settlement_name


## Generate character story.
static func _generate_character_story(settlement_name: String, stats: Dictionary) -> String:
	var knowledge: int = stats.get("knowledge_inscribed", 0)
	var teachings: int = stats.get("teachings", 0)
	var buildings: int = stats.get("buildings", 0)
	var friendships: int = stats.get("friendships", 0)
	
	if knowledge > 5 or teachings > 10:
		return "  The people of [color=#FFD166]%s[/color] are known for their wisdom. Knowledge is passed from elder to youth, from teacher to student. Stones are carved with learning, and the settlement stands as a beacon of understanding in a dark world. They believe that knowledge, once gained, must never be lost.\n" % settlement_name
	elif buildings > 15:
		return "  [color=#FFD166]%s[/color] is a monument to perseverance. Its people build with care and purpose, raising structures that will outlast their mortal lives. Each wall, each shelter, each storage hut speaks of a community that plans for tomorrow, even as it lives today.\n" % settlement_name
	elif friendships > 10:
		return "  The heart of [color=#FFD166]%s[/color] beats with friendship. Bonds are formed easily here, and neighbors treat each other as family. When one struggles, many hands reach to help. The settlement thrives not because of its buildings, but because of the love between its people.\n" % settlement_name
	else:
		return "  [color=#FFD166]%s[/color] is defined by resilience. Its people face each dawn with determination, each challenge with courage. They are neither the largest nor the wealthiest, but they endure. And in endurance, there is its own kind of greatness.\n" % settlement_name


## Generate trials story.
static func _generate_trials_story(settlement_name: String, stats: Dictionary) -> String:
	var deaths: int = stats.get("deaths", 0)
	var abandonments: int = stats.get("abandonments", 0)
	var revivals: int = stats.get("revivals", 0)
	
	if revivals > 0:
		return "  [color=#FFD166]%s[/color] has known darkness. There were times when the fires went cold, when the shelters stood empty, when all seemed lost. But the settlement did not die. Like a ember glowing in ash, it waited. And when new souls came, the fire was rekindled. This is the power of place: it outlasts us all.\n" % settlement_name
	elif deaths > 10:
		return "  Death has visited [color=#FFD166]%s[/color] many times. Each loss left its mark on the community - a empty seat at the fire, a voice silenced, a story ended. But the living remembered. They carried forward the names, the lessons, the dreams of those who came before. In this way, the dead still walk these streets.\n" % settlement_name
	else:
		return "  The path of [color=#FFD166]%s[/color] has been blessed with peace. No great catastrophe has marked its history, no tragedy has defined it. Some might call this unremarkable. But those who live here know the truth: peace is the greatest fortune a settlement can know.\n" % settlement_name


## Generate heroes story.
static func _generate_heroes_story(settlement_name: String, events: Array[Dictionary]) -> String:
	# Find most impactful pawns
	var pawn_contributions: Dictionary = {}
	
	for ev in events:
		var pawn_id: int = int(ev.get("pawn_id", ev.get("pid", -1)))
		if pawn_id < 0:
			continue
		
		if not pawn_contributions.has(pawn_id):
			pawn_contributions[pawn_id] = {"name": "", "teachings": 0, "buildings": 0, "knowledge": 0}
		
		var event_type: String = str(ev.get("type", "unknown"))
		match event_type:
			"teaching_event":
				pawn_contributions[pawn_id].teachings = int(pawn_contributions[pawn_id].teachings) + 1
			"building_constructed":
				pawn_contributions[pawn_id].buildings = int(pawn_contributions[pawn_id].buildings) + 1
			"knowledge_inscribed":
				pawn_contributions[pawn_id].knowledge = int(pawn_contributions[pawn_id].knowledge) + 1
		
		# Get name if available
		if ev.has("pawn_name"):
			pawn_contributions[pawn_id].name = str(ev.get("pawn_name", ""))
	
	# Find top contributors
	var heroes: Array = []
	for pawn_id in pawn_contributions:
		var data: Dictionary = pawn_contributions[pawn_id]
		var score: int = data.teachings * 3 + data.buildings + data.knowledge * 5
		if score >= 3 and data.name != "":
			heroes.append({"name": data.name, "score": score, "data": data})
	
	heroes.sort_custom(func(a, b): return a.score > b.score)
	
	if heroes.is_empty():
		return "  Many souls have walked the streets of [color=#FFD166]%s[/color]. Most lived quiet lives of work and rest. But even quiet lives, woven together, create the tapestry of a community. Each contributed their thread, and the settlement is richer for it.\n" % settlement_name
	
	var text: String = ""
	var shown: int = 0
	for hero in heroes:
		if shown >= 3:
			break
		
		text += "  [color=#FFD166]%s[/color]: " % hero.name
		var parts: Array[String] = []
		if hero.data.teachings > 0:
			parts.append("taught %d students" % hero.data.teachings)
		if hero.data.buildings > 0:
			parts.append("built %d structures" % hero.data.buildings)
		if hero.data.knowledge > 0:
			parts.append("preserved knowledge on stone")
		text += ", ".join(parts) + ".\n"
		
		shown += 1
	
	return text


## Generate legacy story.
static func _generate_legacy_story(settlement_name: String, stats: Dictionary) -> String:
	var total: int = stats.get("total_events", 0)
	var births: int = stats.get("births", 0)
	var knowledge: int = stats.get("knowledge_inscribed", 0)
	
	if knowledge > 3:
		return "  What will [color=#FFD166]%s[/color] leave behind? Stones carved with knowledge will outlast its founders. Students taught will carry lessons to new places. The settlement's true legacy is not in what it builds, but in what it preserves and passes on.\n" % settlement_name
	elif births > 10:
		return "  The legacy of [color=#FFD166]%s[/color] lives in its children. They carry the blood of founders, the names of ancestors, the stories of their elders. When they leave, they take pieces of home with them. When they stay, they build upon what came before. This is how settlements become eternal.\n" % settlement_name
	else:
		return "  [color=#FFD166]%s[/color] continues. Each dawn brings new work, each dusk brings rest. The future is unwritten, but the past is solid. What comes next depends on those who call this place home. The story is not finished - it is being written now, by living hands.\n" % settlement_name


## Generate short founding legend for new settlements.
static func _generate_founding_legend(settlement_name: String) -> String:
	return "[color=#FFD166][b]━━━ THE LEGEND OF %s ━━━[/b][/color]\n\n  In the beginning, [color=#FFD166]%s[/color] was but a dream. A single soul chose this place, lit the first fire, and raised the first shelter. From that humble beginning, a community was born. The story continues...\n" % [settlement_name.to_upper(), settlement_name]
