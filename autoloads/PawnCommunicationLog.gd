extends Node
## PawnCommunicationLog - Tracks pawn conversations, plans, and social coordination
##
## Logs:
## - Job claim announcements ("I'm building a wall here!")
## - Resource requests ("I need wood for the shelter")
## - Group coordination ("Let's build together")
## - Religious/cultural discussions
## - Clan formation events
## - Teaching moments
## - Gossip exchanges
##
## Output: F10 → #50 · Communication Log

const MAX_LOG_ENTRIES: int = 200  # Keep last 200 conversations
const LOG_EXPIRY_TICKS: int = 18000  # Entries expire after 18000 ticks (~30 days)

var communication_log: Array[Dictionary] = []
var clan_formations: Array[Dictionary] = []
var religious_events: Array[Dictionary] = []
var group_projects: Dictionary = {}  # project_id -> {leader, members, goal, progress}


func _ready() -> void:
	GameManager.game_tick.connect(_on_game_tick)


func _on_game_tick(tick: int) -> void:
	# Expire old log entries
	if communication_log.size() > MAX_LOG_ENTRIES:
		var trimmed: Array[Dictionary] = []
		for i in range(communication_log.size() - MAX_LOG_ENTRIES, communication_log.size()):
			if communication_log[i] is Dictionary:
				trimmed.append(communication_log[i])
		communication_log = trimmed
	
	# Expire very old entries
	var expiry_threshold: int = tick - LOG_EXPIRY_TICKS
	var kept: Array[Dictionary] = []
	for entry in communication_log:
		if entry is Dictionary and int(entry.get("tick", 0)) > expiry_threshold:
			kept.append(entry)
	communication_log = kept


## Log pawn communication about job/work
func log_work_announcement(pawn_id: int, pawn_name: String, job_type: int, tile: Vector2i, reason: String = "") -> void:
	var entry: Dictionary = {
		"tick": GameManager.tick_count,
		"type": "work_announcement",
		"pawn_id": pawn_id,
		"pawn_name": pawn_name,
		"job_type": _job_type_name(job_type),
		"tile": {"x": tile.x, "y": tile.y},
		"reason": reason,
		"message": _generate_work_message(pawn_name, job_type, reason)
	}
	communication_log.append(entry)


## Log social interaction (conversation, gossip, teaching)
func log_social_interaction(pawn_a_id: int, pawn_a_name: String, pawn_b_id: int, pawn_b_name: String, interaction_type: String, topic: String = "") -> void:
	var entry: Dictionary = {
		"tick": GameManager.tick_count,
		"type": "social_interaction",
		"pawn_a_id": pawn_a_id,
		"pawn_a_name": pawn_a_name,
		"pawn_b_id": pawn_b_id,
		"pawn_b_name": pawn_b_name,
		"interaction_type": interaction_type,
		"topic": topic,
		"message": _generate_social_message(pawn_a_name, pawn_b_name, interaction_type, topic)
	}
	communication_log.append(entry)


## Log clan/house formation
func log_clan_formation(clan_name: String, founder_id: int, founder_name: String, members: Array[int], region: int) -> void:
	var entry: Dictionary = {
		"tick": GameManager.tick_count,
		"type": "clan_formation",
		"clan_name": clan_name,
		"founder_id": founder_id,
		"founder_name": founder_name,
		"members": members,
		"region": region,
		"message": "Clan %s founded by %s with %d members" % [clan_name, founder_name, members.size()]
	}
	clan_formations.append(entry)
	communication_log.append(entry)


## Log religious/cultural event
func log_religious_event(event_type: String, leader_id: int, leader_name: String, participants: Array[int], location: Vector2i, description: String) -> void:
	var entry: Dictionary = {
		"tick": GameManager.tick_count,
		"type": "religious_event",
		"event_type": event_type,
		"leader_id": leader_id,
		"leader_name": leader_name,
		"participants": participants,
		"location": {"x": location.x, "y": location.y},
		"description": description,
		"message": "%s led by %s: %s" % [event_type, leader_name, description]
	}
	religious_events.append(entry)
	communication_log.append(entry)


## Log group building project
func log_group_project(project_id: String, leader_id: int, leader_name: String, members: Array[int], goal: String, tile: Vector2i) -> void:
	group_projects[project_id] = {
		"tick_started": GameManager.tick_count,
		"leader_id": leader_id,
		"leader_name": leader_name,
		"members": members,
		"goal": goal,
		"tile": {"x": tile.x, "y": tile.y},
		"progress": 0,
		"status": "active"
	}
	
	var entry: Dictionary = {
		"tick": GameManager.tick_count,
		"type": "group_project",
		"project_id": project_id,
		"leader_name": leader_name,
		"members": members,
		"goal": goal,
		"message": "%s organized building project: %s" % [leader_name, goal]
	}
	communication_log.append(entry)


## Update group project progress
func update_group_project(project_id: String, progress: int, status: String = "active") -> void:
	if group_projects.has(project_id):
		group_projects[project_id].progress = progress
		group_projects[project_id].status = status


func _job_type_name(job_type: int) -> String:
	match job_type:
		1: return "Forage"
		2: return "Mine"
		3: return "Chop"
		4: return "Hunt"
		5: return "Build Bed"
		6: return "Build Wall"
		7: return "Build Door"
		10: return "Build Fire Pit"
		11: return "Build Storage Hut"
		12: return "Build Shrine"
		13: return "Build Shelter"
		_: return "Job #%d" % job_type


func _generate_work_message(pawn_name: String, job_type: int, reason: String) -> String:
	var messages: Dictionary = {
		"Build Wall": "%s declares: 'I'm building a wall here for protection!'",
		"Build Bed": "%s announces: 'Crafting a bed for better rest!'",
		"Build Fire Pit": "%s says: 'Building a fire pit for warmth and cooking!'",
		"Build Shelter": "%s proclaims: 'Constructing shelter from the elements!'",
		"Build Storage Hut": "%s states: 'Erecting storage for our supplies!'",
		"Forage": "%s says: 'Gathering food from the land!'",
		"Mine": "%s declares: 'Mining for stone and ore!'",
		"Chop": "%s announces: 'Chopping wood for construction!'",
		"Hunt": "%s states: 'Hunting for meat and hides!'"
	}
	
	var template: String = messages.get(_job_type_name(job_type), "%s begins working.")
	return template % pawn_name


func _generate_social_message(pawn_a: String, pawn_b: String, interaction_type: String, topic: String) -> String:
	match interaction_type:
		"gossip":
			return "%s shares news with %s: %s" % [pawn_a, pawn_b, topic]
		"teaching":
			return "%s teaches %s about %s" % [pawn_a, pawn_b, topic]
		"planning":
			return "%s and %s discuss plans: %s" % [pawn_a, pawn_b, topic]
		"storytelling":
			return "%s tells %s a story about %s" % [pawn_a, pawn_b, topic]
		"argument":
			return "%s and %s debate: %s" % [pawn_a, pawn_b, topic]
		_:
			return "%s interacts with %s" % [pawn_a, pawn_b]


## Get recent communications for F10 report
func get_recent_communications(limit: int = 50) -> Array[Dictionary]:
	if communication_log.size() <= limit:
		return communication_log
	return communication_log.slice(-limit)


## Get all clan formations
func get_clan_formations() -> Array[Dictionary]:
	return clan_formations


## Get all religious events
func get_religious_events() -> Array[Dictionary]:
	return religious_events


## Get active group projects
func get_active_projects() -> Array[Dictionary]:
	var active: Array[Dictionary] = []
	for project_id in group_projects:
		var project: Dictionary = group_projects[project_id]
		if project.status == "active":
			active.append(project)
	return active


## Generate F10 report text
func generate_communication_report() -> String:
	var report: String = ""
	report += "=== HEELKAWN COMMUNICATION LOG ===\n\n"
	
	# Recent communications
	report += "--- RECENT CONVERSATIONS (Last 30) ---\n"
	var recent: Array[Dictionary] = get_recent_communications(30)
	if recent.is_empty():
		report += "  (No recent conversations)\n"
	else:
		for entry in recent:
			report += "  [Tick %d] %s\n" % [entry.tick, entry.message]
	
	report += "\n"
	
	# Clan formations
	report += "--- CLAN FORMATIONS ---\n"
	if clan_formations.is_empty():
		report += "  (No clans formed yet)\n"
	else:
		for clan in clan_formations:
			report += "  • %s founded by %s (%d members)\n" % [clan.clan_name, clan.founder_name, clan.members.size()]
	
	report += "\n"
	
	# Religious events
	report += "--- RELIGIOUS/CULTURAL EVENTS ---\n"
	if religious_events.is_empty():
		report += "  (No religious events yet)\n"
	else:
		for event in religious_events:
			report += "  • %s\n" % [event.message]
	
	report += "\n"
	
	# Group projects
	report += "--- ACTIVE BUILDING PROJECTS ---\n"
	var projects: Array[Dictionary] = get_active_projects()
	if projects.is_empty():
		report += "  (No active group projects)\n"
	else:
		for project in projects:
			report += "  • %s (led by %s, %d workers, %d%% complete)\n" % [
				project.goal, project.leader_name, project.members.size(), 
				int(float(project.progress) / 10.0) if project.has("progress") else 0
			]
	
	return report
