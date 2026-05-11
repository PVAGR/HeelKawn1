class_name PawnDecisionRuleMatrix
extends RefCounted

## Readable if/then policy layer on top of the per-pawn neural forward pass.
## Indices match WorldAI / HeelKawnian job bias: 0 food, 1 rest, 2 social, 3 forage,
## 4 build, 5 mine, 6 defend, 7 idle.
## [method evaluate] mutates [param outs] in place and returns fired rules for UI / telemetry.

const OUT_CLAMP_MIN: float = 0.0
const OUT_CLAMP_MAX: float = 2.0
## Keep in sync with [member HeelKawnian.FOUNDING_PERIOD_TICKS].
const FOUNDING_PERIOD_TICKS: int = 4500
## Twelve human-readable intent channels (8 action heads + 4 social/cognitive) for UI + parity utility.
const HUMAN_CHANNEL_LABELS: Array[String] = [
	"SeekFood", "SeekRest", "SeekSocial", "WorkGather", "WorkBuild", "WorkMine",
	"FaceThreat", "IdleObserve", "SpeakBond", "HelpAlly", "Withdraw", "ScoutWonder",
]


func _bump(outs: Array, idx: int, delta: float) -> void:
	if outs.size() <= idx:
		return
	var v: float = float(outs[idx]) + delta
	outs[idx] = clampf(v, OUT_CLAMP_MIN, OUT_CLAMP_MAX)


func _bump_many(outs: Array, indices: Array, delta: float) -> void:
	for i in indices:
		_bump(outs, int(i), delta)


func _empty_eval() -> Dictionary:
	var hc: Array = []
	hc.resize(12)
	for i in 12:
		hc[i] = 0.0
	return {"fired": [], "human_channels": hc, "human_channel_labels": HUMAN_CHANNEL_LABELS}


func _build_human_channels(pd: HeelKawnianData, ctx: Dictionary, outs: Array) -> Array:
	var hc: Array = []
	hc.resize(12)
	for i in range(12):
		if i < outs.size():
			hc[i] = float(outs[i])
		else:
			hc[i] = 0.0
	var danger: float = float(ctx.get("danger_level_hint", 0.0))
	var mood: float = float(ctx.get("mood", pd.mood))
	var extra: float = float(ctx.get("extraversion", pd.extraversion))
	var agree: float = float(ctx.get("agreeableness", pd.agreeableness))
	var neuro: float = float(ctx.get("neuroticism", pd.neuroticism))
	var open: float = float(ctx.get("openness", pd.openness))
	var combat_af: float = float(ctx.get("affinity_combat", pd.affinities.get("combat", 0.5)))
	var founding: float = clampf(float(ctx.get("founding_blend", 0.0)), 0.0, 1.0)
	var top_rapport: int = int(ctx.get("top_rapport_score", 0))
	hc[8] = clampf(extra * (1.0 - mood / 100.0) * 0.55 + float(top_rapport) / 3000.0 * 0.25, 0.0, 1.0)
	hc[9] = clampf(agree * (0.35 + float(top_rapport) / 3000.0 * 0.5), 0.0, 1.0)
	hc[10] = clampf(neuro * danger * (1.2 - combat_af * 0.9), 0.0, 1.0)
	hc[11] = clampf(open * (0.25 + founding * 0.55), 0.0, 1.0)
	return hc


func _apply_human_semantic_projection(outs: Array, hc: Array) -> void:
	if hc.size() < 12:
		return
	_bump(outs, 2, float(hc[8]) * 0.12)
	_bump(outs, 7, float(hc[8]) * 0.04)
	_bump(outs, 2, float(hc[9]) * 0.10)
	_bump(outs, 3, float(hc[9]) * 0.05)
	_bump(outs, 4, float(hc[9]) * 0.04)
	_bump(outs, 1, float(hc[10]) * 0.10)
	_bump(outs, 7, float(hc[10]) * 0.08)
	_bump(outs, 5, -float(hc[10]) * 0.06)
	_bump(outs, 6, -float(hc[10]) * 0.05)
	_bump(outs, 3, float(hc[11]) * 0.08)
	_bump(outs, 7, float(hc[11]) * 0.07)
	_bump(outs, 0, float(hc[11]) * 0.03)


func evaluate(pd: HeelKawnianData, ctx: Dictionary, outs: Array) -> Dictionary:
	var fired: Array = []
	if pd == null or outs.size() < 8:
		return _empty_eval()

	var hunger: float = float(ctx.get("hunger", pd.hunger))
	var rest: float = float(ctx.get("rest", pd.rest))
	var mood: float = float(ctx.get("mood", pd.mood))
	var health: float = float(ctx.get("health", pd.health))
	var max_hp: float = float(ctx.get("max_health", maxf(1.0, pd.max_health)))
	var food_units: int = int(ctx.get("food_stockpile_units", 0))
	var food_pressure: float = float(ctx.get("food_pressure", 0.0))
	var founding: float = clampf(float(ctx.get("founding_blend", 0.0)), 0.0, 1.0)
	var tick: int = int(ctx.get("tick", 0))
	var scar_n: int = int(ctx.get("scar_count", pd.physical_scars.size()))
	var top_rapport: int = int(ctx.get("top_rapport_score", 0))
	var top_opinion: int = int(ctx.get("top_opinion_score", 0))
	var top_opinion_peer: int = int(ctx.get("top_opinion_peer_id", -1))
	var martial_place: float = float(ctx.get("martial_settlement", 0.0))
	var pain: float = float(ctx.get("pain", pd.pain))
	var crisis: float = float(ctx.get("crisis_level", pd.get_crisis_level()))
	var children: int = int(ctx.get("children_count", pd.children_count))
	var settlement_id: int = int(ctx.get("settlement_id", pd.settlement_id))
	var extra: float = float(ctx.get("extraversion", pd.extraversion))
	var agree: float = float(ctx.get("agreeableness", pd.agreeableness))
	var neuro: float = float(ctx.get("neuroticism", pd.neuroticism))
	var consc: float = float(ctx.get("conscientiousness", pd.conscientiousness))
	var combat_af: float = float(ctx.get("affinity_combat", pd.affinities.get("combat", 0.5)))
	var farm_af: float = float(ctx.get("affinity_farming", pd.affinities.get("farming", 0.5)))
	var build_af: float = float(ctx.get("affinity_building", pd.affinities.get("building", 0.5)))
	var craft_af: float = float(ctx.get("affinity_crafting", pd.affinities.get("crafting", 0.5)))
	var dip_af: float = float(ctx.get("affinity_diplomacy", pd.affinities.get("diplomacy", 0.5)))
	var carrying: bool = bool(ctx.get("is_carrying", pd.is_carrying()))
	var carrying_food: bool = bool(ctx.get("carrying_food", false))
	var work_forage: bool = bool(ctx.get("work_forage", pd.work_forage))
	var work_mine: bool = bool(ctx.get("work_mine", pd.work_mine))
	var work_build: bool = bool(ctx.get("work_build", pd.work_build))
	var work_hunt: bool = bool(ctx.get("work_hunt", pd.work_hunt))
	var weather_tag: String = str(ctx.get("weather_tag", "clear"))

	# --- Weather (WorldAI band, drives environment utility + outdoor work) ---
	if weather_tag == "storm":
		_bump_many(outs, [1, 7], 0.08)
		_bump(outs, 3, -0.07)
		fired.append({"id": "weather_storm", "line": "IF storm band THEN shelter/rest/idle up; outdoor gather down.", "w": 0.62})
	elif weather_tag == "rain" or weather_tag == "gusty":
		_bump_many(outs, [1, 4], 0.05)
		_bump(outs, 3, -0.04)
		fired.append({"id": "weather_wet_windy", "line": "IF rain or gusty THEN favor indoor work and recovery; mild outdoor penalty.", "w": 0.48})
	elif weather_tag == "overcast":
		_bump(outs, 7, 0.03)
		fired.append({"id": "weather_overcast", "line": "IF overcast THEN slight idle/explore patience.", "w": 0.22})

	# --- Survival & needs (RimWorld-style gates) ---
	if hunger <= 22.0:
		_bump_many(outs, [0, 7], 0.22)
		fired.append({"id": "need_starving", "line": "IF hunger is critical THEN push Seek_Food and cautious Idle.", "w": 0.95})
	elif hunger <= 38.0:
		_bump_many(outs, [0, 3], 0.14)
		fired.append({"id": "need_hungry", "line": "IF hunger is low THEN favor Seek_Food and forage work.", "w": 0.72})

	if rest <= 32.0:
		_bump_many(outs, [1, 7], 0.20)
		fired.append({"id": "need_exhausted", "line": "IF rest is critical THEN prioritize sleep / recovery (Rest + Idle).", "w": 0.88})
	elif rest <= 48.0:
		_bump(outs, 1, 0.10)
		fired.append({"id": "need_tired", "line": "IF rest is low THEN nudge Seek_Rest.", "w": 0.55})

	if mood <= 35.0:
		_bump_many(outs, [2, 7], 0.12)
		fired.append({"id": "need_low_mood", "line": "IF mood is poor THEN seek social relief and lighter Idle pacing.", "w": 0.60})

	if health < max_hp * 0.45:
		_bump_many(outs, [1, 7, 6], 0.14)
		fired.append({"id": "need_injured", "line": "IF health is badly low THEN favor rest, self-preservation, and guard posture.", "w": 0.78})

	if pain >= 40.0:
		_bump_many(outs, [1, 7], 0.10)
		_bump(outs, 5, -0.06)
		fired.append({"id": "need_pain", "line": "IF pain is high THEN avoid heavy labor; prefer recovery.", "w": 0.62})

	# --- Colony stock & pressure (ColonySimServices / stockpile) ---
	if food_units <= 3:
		_bump_many(outs, [0, 3], 0.16)
		if work_hunt:
			_bump(outs, 6, 0.06)
		fired.append({"id": "colony_food_stock_critical", "line": "IF colony food stock is critical THEN push food seeking and forage.", "w": 0.85})

	if food_pressure >= 0.72:
		_bump_many(outs, [0, 3], 0.12)
		fired.append({"id": "colony_food_pressure", "line": "IF colony food pressure is high THEN bias toward feeding the pile (forage/seek).", "w": 0.70})

	# --- Founding phase (matches HeelKawnian founding blend) ---
	if founding >= 0.35:
		_bump_many(outs, [2, 3, 7], 0.10 * founding)
		fired.append({"id": "phase_founding", "line": "IF world is in founding phase THEN wander-meet-forage-social slightly up.", "w": 0.45 + founding * 0.3})

	# --- Scars & crisis (WorldPersistence / mood systems) ---
	if scar_n >= 2:
		_bump_many(outs, [6, 1], 0.08 + float(scar_n) * 0.03)
		_bump(outs, 3, -0.05)
		fired.append({"id": "identity_scarred", "line": "IF many scars THEN more Defend/Rest, less blind foraging.", "w": 0.50})

	if crisis >= 0.65:
		_bump_many(outs, [0, 1, 6], 0.10)
		fired.append({"id": "state_crisis", "line": "IF personal crisis is high THEN survival triage (food, rest, defend).", "w": 0.68})

	# --- Settlement & culture ---
	if settlement_id >= 0:
		if work_build:
			_bump(outs, 4, 0.08 + dip_af * 0.06)
		fired.append({"id": "place_in_settlement", "line": "IF registered to a settlement THEN slight civic build/diplomacy bias.", "w": 0.40})

	if martial_place >= 0.5:
		_bump_many(outs, [6, 4], 0.10)
		fired.append({"id": "culture_martial_site", "line": "IF site culture is Martial THEN defend and fortify work rise.", "w": 0.55})

	# --- Social graph (rapport / CK opinions) ---
	if top_rapport >= 120:
		_bump(outs, 2, 0.12 + extra * 0.08)
		fired.append({"id": "social_strong_bond", "line": "IF strongest rapport bond is strong THEN Seek_Social up (extraversion scales it).", "w": 0.52})

	if top_opinion_peer >= 0 and top_opinion >= 40:
		_bump(outs, 2, 0.08)
		fired.append({"id": "social_positive_opinion", "line": "IF someone is strongly liked THEN more social seeking.", "w": 0.42})

	if top_opinion_peer >= 0 and top_opinion <= -35:
		_bump_many(outs, [6, 7], 0.07)
		_bump(outs, 2, -0.05)
		fired.append({"id": "social_rivalry", "line": "IF a strong negative opinion of a specific peer THEN tension: guard/idle up, social down.", "w": 0.48})

	if extra >= 0.62:
		_bump(outs, 2, 0.08)
		fired.append({"id": "trait_extravert", "line": "IF extraversion is high THEN baseline social seeking.", "w": 0.35})

	if agree >= 0.65:
		_bump_many(outs, [2, 3], 0.05)
		_bump(outs, 6, -0.04)
		fired.append({"id": "trait_agreeable", "line": "IF agreeable THEN cooperative forage/social; less confrontational defend.", "w": 0.33})

	if neuro >= 0.62:
		_bump_many(outs, [1, 7], 0.07)
		if mood < 50.0:
			_bump(outs, 5, -0.05)
		fired.append({"id": "trait_neurotic", "line": "IF neurotic THEN more rest/idle volatility; avoid harsh mine under poor mood.", "w": 0.38})

	if consc >= 0.65:
		_bump_many(outs, [4, 5], 0.06)
		fired.append({"id": "trait_conscientious", "line": "IF conscientious THEN structured build/mine nudge.", "w": 0.34})

	# --- Affinity lanes (job flavor) ---
	if combat_af >= 0.62 and work_hunt:
		_bump_many(outs, [6, 3], 0.10)
		fired.append({"id": "affinity_martial", "line": "IF combat-affine AND hunts THEN hunt/defend bias.", "w": 0.44})

	if farm_af >= 0.58 and work_forage:
		_bump(outs, 3, 0.12)
		fired.append({"id": "affinity_green", "line": "IF farming-affine AND forage enabled THEN forage work up.", "w": 0.41})

	if build_af >= 0.58 and work_build:
		_bump(outs, 4, 0.12)
		fired.append({"id": "affinity_builder", "line": "IF building-affine AND build enabled THEN construction bias.", "w": 0.41})

	if craft_af >= 0.58:
		_bump_many(outs, [4, 5], 0.06)
		fired.append({"id": "affinity_craft", "line": "IF crafting-affine THEN site work (build/mine) support.", "w": 0.36})

	if dip_af >= 0.60:
		_bump_many(outs, [2, 4], 0.07)
		fired.append({"id": "affinity_diplomat", "line": "IF diplomacy-affine THEN social + civic build.", "w": 0.37})

	# --- Life stage ---
	if children >= 1:
		_bump_many(outs, [4, 0], 0.06)
		fired.append({"id": "life_parent", "line": "IF has children THEN nest/build and food stability nudge.", "w": 0.39})

	# --- Carry state ---
	if carrying and carrying_food and hunger < 55.0:
		_bump(outs, 0, 0.12)
		fired.append({"id": "carry_food_not_starving", "line": "IF carrying food while not starving THEN route toward eating/handling food.", "w": 0.50})

	if carrying and not carrying_food:
		_bump_many(outs, [4, 7], 0.05)
		fired.append({"id": "carry_cargo", "line": "IF carrying non-food THEN favor delivering / site tasks over wild forage.", "w": 0.30})

	# --- Time-of-day hint (cheap bucket) ---
	if tick >= 0:
		var day_tick: int = posmod(tick, 2400)
		if day_tick > 1800 or day_tick < 400:
			_bump(outs, 1, 0.06)
			fired.append({"id": "cycle_night", "line": "IF night bucket THEN slight sleep alignment.", "w": 0.28})

	# --- Work permissions negatives (if disabled, pull down matching output) ---
	if not work_mine:
		_bump(outs, 5, -0.08)
		fired.append({"id": "perm_no_mine", "line": "IF mining disabled for this pawn THEN suppress Work_Mine channel.", "w": 0.25})
	if not work_forage:
		_bump(outs, 3, -0.08)
		fired.append({"id": "perm_no_forage", "line": "IF forage disabled THEN suppress Work_Forage channel.", "w": 0.25})
	if not work_build:
		_bump(outs, 4, -0.08)
		fired.append({"id": "perm_no_build", "line": "IF build disabled THEN suppress Work_Build channel.", "w": 0.25})

	# --- Profession-driven rules (strong nudge so pawns act their role) ---
	var prof: int = int(pd.current_profession) if pd != null else 0
	match prof:
		HeelKawnianData.Profession.FARMER:
			_bump_many(outs, [0, 3], 0.20)
			_bump(outs, 4, -0.04)
			fired.append({"id": "prof_farmer", "line": "IF farmer THEN strong food/forage bias; less building.", "w": 0.62})
		HeelKawnianData.Profession.BUILDER:
			_bump_many(outs, [4, 5], 0.20)
			fired.append({"id": "prof_builder", "line": "IF builder THEN strong build/mine bias.", "w": 0.62})
		HeelKawnianData.Profession.GATHERER:
			_bump_many(outs, [0, 3], 0.18)
			_bump(outs, 7, 0.06)
			fired.append({"id": "prof_gatherer", "line": "IF gatherer THEN forage + food seeking; slight idle wander.", "w": 0.55})
		HeelKawnianData.Profession.WARRIOR:
			_bump_many(outs, [6, 3], 0.20)
			_bump(outs, 1, -0.04)
			fired.append({"id": "prof_warrior", "line": "IF warrior THEN defend/hunt bias; less rest.", "w": 0.62})
		HeelKawnianData.Profession.SCHOLAR:
			_bump_many(outs, [2, 7], 0.18)
			_bump(outs, 1, 0.06)
			fired.append({"id": "prof_scholar", "line": "IF scholar THEN social + idle/observe; slight rest nudge.", "w": 0.55})

	# --- Life path rules (advisory, reinforces profession) ---
	var lpath: int = int(pd.life_path) if pd != null else 0
	match lpath:
		HeelKawnianData.LifePath.FARMER:
			_bump(outs, 3, 0.10)
			fired.append({"id": "lpath_farmer", "line": "IF life path farmer THEN forage nudge.", "w": 0.35})
		HeelKawnianData.LifePath.SOLDIER:
			_bump(outs, 6, 0.10)
			fired.append({"id": "lpath_soldier", "line": "IF life path soldier THEN defend nudge.", "w": 0.35})
		HeelKawnianData.LifePath.WANDERER:
			_bump_many(outs, [7, 3], 0.08)
			fired.append({"id": "lpath_wanderer", "line": "IF life path wanderer THEN idle + explore nudge.", "w": 0.30})

	# --- Settlement demand awareness ---
	var food_pressure_val: float = float(ctx.get("food_pressure", 0.0))
	var settlement_id_val: int = int(ctx.get("settlement_id", -1))
	if settlement_id_val >= 0 and food_pressure_val >= 0.5:
		_bump_many(outs, [0, 3], 0.10)
		fired.append({"id": "settlement_hungry", "line": "IF settlement food pressure high THEN all pawns nudge food.", "w": 0.55})

	# --- Profession overrepresentation (diversity pressure) ---
	var prof_overrep: bool = bool(ctx.get("profession_overrep", false))
	if prof_overrep:
		# Dampen the dominant profession's bias channels so other roles can emerge
		match prof:
			HeelKawnianData.Profession.FARMER:
				_bump_many(outs, [0, 3], -0.10)
				_bump(outs, 4, 0.08)
				fired.append({"id": "overrep_farmer", "line": "IF too many farmers THEN reduce food/forage bias; nudge build.", "w": 0.50})
			HeelKawnianData.Profession.GATHERER:
				_bump_many(outs, [0, 3], -0.08)
				_bump(outs, 4, 0.06)
				fired.append({"id": "overrep_gatherer", "line": "IF too many gatherers THEN reduce forage bias; nudge build.", "w": 0.45})
			HeelKawnianData.Profession.WARRIOR:
				_bump(outs, 6, -0.06)
				_bump_many(outs, [3, 4], 0.06)
				fired.append({"id": "overrep_warrior", "line": "IF too many warriors THEN reduce defend bias; nudge work.", "w": 0.45})

	# --- World-memory-driven behavior (meaning tags shape decisions) ---
	var m_danger: float = float(ctx.get("meaning_danger", 0.0))
	var m_safety: float = float(ctx.get("meaning_safety", 0.0))
	var m_hunger: float = float(ctx.get("meaning_hunger", 0.0))
	var m_knowledge: float = float(ctx.get("meaning_knowledge", 0.0))

	# Danger memory: avoid danger regions, prefer safety and defense
	if m_danger >= 0.3:
		_bump(outs, 7, 0.12)  # idle/observe more — hesitation
		_bump(outs, 6, 0.10)  # defend bias up
		_bump_many(outs, [0, 3], -0.06)  # food/forage down (avoid the danger zone)
		fired.append({"id": "meaning_danger", "line": "IF region has death/famine memory THEN hesitate + defend; avoid forage.", "w": 0.55})
	elif m_danger >= 0.15:
		_bump(outs, 6, 0.05)
		fired.append({"id": "meaning_danger_low", "line": "IF region has some danger memory THEN slight defend nudge.", "w": 0.35})
	# Ancient danger: even stronger aversion (myth formation)
	if m_danger >= 0.5:
		_bump(outs, 7, 0.15)  # strong hesitation near ancient death places
		_bump_many(outs, [0, 3], -0.10)  # strongly avoid foraging here
		_bump(outs, 6, 0.08)
		fired.append({"id": "meaning_ancient_danger", "line": "IF region has ancient death/famine memory THEN strong avoidance + defend.", "w": 0.65})

	# Safety memory: seek safe hearths, more relaxed
	if m_safety >= 0.3:
		_bump(outs, 1, 0.08)  # rest more — it's safe
		_bump(outs, 2, 0.06)  # social more — community
		_bump_many(outs, [0, 3], 0.05)  # food/forage easier
		fired.append({"id": "meaning_safety", "line": "IF region is safe_hearth THEN rest + social + forage easier.", "w": 0.50})
	# Ancient safety: pilgrimage-worthy — even more attractive (myth formation)
	if m_safety >= 0.5:
		_bump(outs, 1, 0.12)  # deep rest
		_bump(outs, 2, 0.10)  # strong community bonds
		_bump_many(outs, [0, 3], 0.08)
		fired.append({"id": "meaning_ancient_safety", "line": "IF region is ancient_heart THEN pilgrimage-level attraction.", "w": 0.60})

	# Hunger memory: hoard food, avoid the region for new settlement
	if m_hunger >= 0.3:
		_bump_many(outs, [0, 3], 0.12)  # food/forage urgency
		_bump(outs, 1, -0.06)  # rest less — survival mode
		fired.append({"id": "meaning_hunger", "line": "IF region has famine memory THEN food urgency; less rest.", "w": 0.55})
	elif m_hunger >= 0.15:
		_bump(outs, 0, 0.05)
		fired.append({"id": "meaning_hunger_low", "line": "IF region has some hunger memory THEN slight food nudge.", "w": 0.30})

	# Knowledge memory: seek teaching, social learning
	if m_knowledge >= 0.3:
		_bump(outs, 2, 0.10)  # social — learning community
		_bump(outs, 7, 0.05)  # observe/idle — contemplation
		fired.append({"id": "meaning_knowledge", "line": "IF region has teaching memory THEN seek social learning.", "w": 0.45})

	# Ritual Echo System: custom tags shape behavior
	var m_custom: float = float(ctx.get("meaning_custom", 0.0))
	if m_custom >= 0.3:
		# Strong customs: social + rest + community bonds
		_bump(outs, 2, 0.08)  # social — community rituals
		_bump(outs, 1, 0.06)  # rest — customs feel safe
		_bump(outs, 7, 0.04)  # observe — participate in customs
		fired.append({"id": "meaning_custom", "line": "IF region has strong customs THEN social + rest + observe.", "w": 0.50})
	elif m_custom >= 0.15:
		_bump(outs, 2, 0.04)  # mild social nudge
		fired.append({"id": "meaning_custom_low", "line": "IF region has fading customs THEN mild social nudge.", "w": 0.30})

	# Craft meaning: industrial/craftsman regions attract builders and foragers
	var m_craft: float = float(ctx.get("meaning_craft", 0.0))
	if m_craft >= 0.3:
		_bump(outs, 4, 0.08)  # build — craft district needs workers
		_bump(outs, 3, 0.05)  # forage — gather materials for crafting
		_bump(outs, 2, 0.04)  # social — craft community
		fired.append({"id": "meaning_craft", "line": "IF craft district THEN build + forage + social.", "w": 0.45})

	# Authority meaning: governed regions attract social and rest
	var m_authority: float = float(ctx.get("meaning_authority", 0.0))
	if m_authority >= 0.3:
		_bump(outs, 2, 0.10)  # social — power center draws people
		_bump(outs, 1, 0.04)  # rest — governed places feel stable
		_bump(outs, 6, 0.05)  # defend — authority needs protection
		fired.append({"id": "meaning_authority", "line": "IF seat of power THEN social + rest + defend.", "w": 0.50})

	# Trade meaning: trading posts attract forage and social
	var m_trade: float = float(ctx.get("meaning_trade", 0.0))
	if m_trade >= 0.3:
		_bump(outs, 3, 0.08)  # forage — gather goods for trade
		_bump(outs, 2, 0.06)  # social — market draws people
		fired.append({"id": "meaning_trade", "line": "IF trading post THEN forage + social.", "w": 0.40})

	# Conflict meaning: war-torn regions trigger defend and avoid idle
	var m_conflict: float = float(ctx.get("meaning_conflict", 0.0))
	if m_conflict >= 0.4:
		_bump(outs, 6, 0.12)  # defend — war zone
		_bump(outs, 7, -0.08)  # less idle — danger
		_bump(outs, 1, -0.05)  # less rest — no relaxing in war zone
		fired.append({"id": "meaning_conflict", "line": "IF war-torn region THEN defend + less idle + less rest.", "w": 0.55})
	elif m_conflict >= 0.2:
		_bump(outs, 6, 0.06)  # mild defend
		fired.append({"id": "meaning_conflict_low", "line": "IF grudge-haunted THEN mild defend.", "w": 0.35})

	# Legacy meaning: storied regions attract social and observe
	var m_legacy: float = float(ctx.get("meaning_legacy", 0.0))
	if m_legacy >= 0.3:
		_bump(outs, 2, 0.06)  # social — legacy draws community
		_bump(outs, 7, 0.04)  # observe — contemplate history
		fired.append({"id": "meaning_legacy", "line": "IF storied region THEN social + observe.", "w": 0.40})

	# Culture meaning: sacred/hallowed regions attract social and rest
	var m_culture: float = float(ctx.get("meaning_culture", 0.0))
	if m_culture >= 0.3:
		_bump(outs, 2, 0.08)  # social — sacred sites draw community
		_bump(outs, 1, 0.06)  # rest — sanctuary feels safe
		_bump(outs, 7, 0.04)  # observe — ritual participation
		fired.append({"id": "meaning_culture", "line": "IF sacred site THEN social + rest + observe.", "w": 0.45})

	# Knowledge risk: settlement has skills at risk → teach urgency
	var k_risk: float = float(ctx.get("knowledge_at_risk", 0.0))
	if k_risk >= 0.5:
		_bump(outs, 2, 0.12)  # social — seek students
		_bump(outs, 7, -0.05)  # less idle — knowledge is at risk
		fired.append({"id": "knowledge_at_risk", "line": "IF settlement knowledge at risk THEN seek students.", "w": 0.55})
	elif k_risk >= 0.2:
		_bump(outs, 2, 0.06)  # mild social nudge
		fired.append({"id": "knowledge_at_risk_low", "line": "IF some knowledge at risk THEN mild teach nudge.", "w": 0.35})

	# Teaching obligation: master who hasn't taught → social pressure
	var t_obligation: float = float(ctx.get("teaching_obligation", 0.0))
	if t_obligation >= 0.5:
		_bump(outs, 2, 0.15)  # strong social — community expects teaching
		_bump(outs, 1, -0.08)  # less rest — guilt/pressure
		fired.append({"id": "teaching_obligation", "line": "IF master hasn't taught THEN social pressure + less rest.", "w": 0.60})
	elif t_obligation >= 0.2:
		_bump(outs, 2, 0.06)  # mild social nudge
		fired.append({"id": "teaching_obligation_low", "line": "IF some teaching debt THEN mild social nudge.", "w": 0.35})

	# Diaspora exile: exiled pawns seek community bonds and are restless
	var d_exile: float = float(ctx.get("diaspora_exile", 0.0))
	if d_exile >= 0.5:
		_bump(outs, 2, 0.12)  # social — seek new community
		_bump(outs, 0, 0.06)  # forage — work hard to establish
		_bump(outs, 1, -0.05)  # less rest — urgency
		fired.append({"id": "diaspora_exile", "line": "IF pawn is exiled THEN seek community + work hard.", "w": 0.50})

	# ==================== PawnConsciousness rules ====================
	# Trauma: traumatized pawns avoid danger, seek rest, withdraw
	var trauma: float = float(ctx.get("trauma_level", 0.0))
	if trauma >= 75.0:
		_bump(outs, 6, -0.15)  # avoid defend — too traumatized for combat
		_bump(outs, 1, 0.12)   # seek rest — need recovery
		_bump(outs, 7, 0.08)   # withdraw/observe — hypervigilant
		_bump(outs, 3, -0.06)  # less forage — avoid risky expeditions
		fired.append({"id": "trauma_severe", "line": "IF severe trauma THEN avoid combat + seek rest + hypervigilant.", "w": 0.65})
	elif trauma >= 50.0:
		_bump(outs, 6, -0.08)  # less defend
		_bump(outs, 1, 0.06)   # mild rest preference
		_bump(outs, 7, 0.04)   # slight observe
		fired.append({"id": "trauma_moderate", "line": "IF moderate trauma THEN avoid combat + mild rest.", "w": 0.45})
	elif trauma >= 25.0:
		_bump(outs, 6, -0.04)  # slight defend avoidance
		fired.append({"id": "trauma_mild", "line": "IF mild trauma THEN slight defend avoidance.", "w": 0.25})

	# Parental trauma: inherited family stress makes pawns restive and cautious
	var parental_trauma: float = float(ctx.get("parental_trauma_level", 0.0))
	if parental_trauma >= 40.0:
		_bump(outs, 1, 0.08)   # seek rest — inherited grief
		_bump(outs, 6, -0.05)  # avoid combat — learned caution
		_bump(outs, 7, 0.05)   # idle observe — hypervigilance
		fired.append({"id": "parental_trauma_severe", "line": "IF inherited trauma is severe THEN rest + avoid danger.", "w": 0.40})
	elif parental_trauma >= 15.0:
		_bump(outs, 1, 0.03)
		_bump(outs, 7, 0.02)
		fired.append({"id": "parental_trauma_mild", "line": "IF inherited trauma is present THEN mild caution.", "w": 0.18})

	# Self-awareness: aware pawns teach more, seek social, are less idle
	var awareness: int = int(ctx.get("self_awareness", 0))
	if awareness >= 4:
		# Enlightened/transcendent: strong teaching drive, community leadership
		_bump(outs, 2, 0.15)   # social — teach and guide
		_bump(outs, 7, -0.08)  # less idle — purpose-driven
		_bump(outs, 0, 0.06)   # help provide food — civic duty
		fired.append({"id": "awareness_transcendent", "line": "IF transcendent THEN teach + lead + provide.", "w": 0.60})
	elif awareness >= 3:
		# Reflective: teach, plan, seek knowledge
		_bump(outs, 2, 0.10)   # social — share wisdom
		_bump(outs, 7, -0.04)  # less idle — thoughtful
		fired.append({"id": "awareness_reflective", "line": "IF reflective THEN teach + share wisdom.", "w": 0.45})
	elif awareness >= 2:
		# Aware: slight social nudge, learns from mistakes
		_bump(outs, 2, 0.05)   # mild social
		fired.append({"id": "awareness_aware", "line": "IF aware THEN mild social nudge.", "w": 0.25})

	# Dreams: recent dream themes nudge behavior
	var dream_theme: String = str(ctx.get("recent_dream_theme", ""))
	if dream_theme == "trauma":
		_bump(outs, 1, 0.06)   # seek rest — nightmares disturb sleep
		_bump(outs, 6, -0.04)  # avoid combat — fear from dreams
		fired.append({"id": "dream_trauma", "line": "IF trauma dream THEN seek rest + avoid danger.", "w": 0.30})
	elif dream_theme == "desire":
		_bump(outs, 3, 0.05)   # forage — ambition drives work
		_bump(outs, 4, 0.04)   # build — desire for achievement
		fired.append({"id": "dream_desire", "line": "IF desire dream THEN work harder + build.", "w": 0.30})
	elif dream_theme == "survival":
		_bump(outs, 0, 0.06)   # seek food — survival anxiety
		_bump(outs, 1, 0.04)   # seek rest — exhaustion
		fired.append({"id": "dream_survival", "line": "IF survival dream THEN seek food + rest.", "w": 0.30})
	elif dream_theme == "social":
		_bump(outs, 2, 0.06)   # social — dream of belonging
		_bump(outs, 4, 0.03)   # build — community drive
		fired.append({"id": "dream_social", "line": "IF social dream THEN seek community + build.", "w": 0.30})
	elif dream_theme == "achievement":
		_bump(outs, 3, 0.06)   # forage — productive ambition
		_bump(outs, 4, 0.05)   # build — creative drive
		_bump(outs, 5, 0.03)   # craft — mastery drive
		fired.append({"id": "dream_achievement", "line": "IF achievement dream THEN produce + build + craft.", "w": 0.30})
	elif dream_theme == "general":
		_bump(outs, 1, 0.02)   # mild rest — neutral dream
		fired.append({"id": "dream_general", "line": "IF general dream THEN mild restfulness.", "w": 0.10})

	var dream_nudge_action: String = str(ctx.get("dream_nudge_action", ""))
	if dream_nudge_action == "wander":
		_bump(outs, 7, 0.08)
		_bump(outs, 2, 0.03)
		fired.append({"id": "dream_nudge_wander", "line": "IF dream nudges wandering THEN idle observe + social curiosity.", "w": 0.22})
	elif dream_nudge_action == "rest":
		_bump(outs, 1, 0.06)
		fired.append({"id": "dream_nudge_rest", "line": "IF dream nudges rest THEN seek recovery.", "w": 0.22})
	elif dream_nudge_action == "forage":
		_bump(outs, 0, 0.05)
		fired.append({"id": "dream_nudge_forage", "line": "IF dream nudges forage THEN seek food.", "w": 0.22})
	elif dream_nudge_action == "work":
		_bump(outs, 3, 0.04)
		_bump(outs, 4, 0.03)
		fired.append({"id": "dream_nudge_work", "line": "IF dream nudges work THEN gather + build.", "w": 0.22})
	elif dream_nudge_action == "socialize":
		_bump(outs, 2, 0.06)
		fired.append({"id": "dream_nudge_social", "line": "IF dream nudges socializing THEN seek community.", "w": 0.22})

	# Core beliefs: pawns with many beliefs are more community-oriented
	var beliefs_n: int = int(ctx.get("core_beliefs_count", 0))
	if beliefs_n >= 3:
		_bump(outs, 2, 0.08)   # social — belief-driven community
		_bump(outs, 6, 0.04)   # defend — protect what they believe in
		fired.append({"id": "beliefs_strong", "line": "IF many core beliefs THEN social + defend community.", "w": 0.35})

	# ==================== GrudgeManager rules ====================
	# Grudges make pawns withdrawn, avoidant, and potentially vengeful
	var grudge_i: float = float(ctx.get("grudge_intensity", 0.0))
	if grudge_i >= 1.5:
		# Blood feud level: hostile, avoid social, seek revenge
		_bump(outs, 2, -0.12)  # less social — don't trust anyone
		_bump(outs, 6, 0.10)   # defend — ready to fight
		_bump(outs, 7, 0.08)   # observe — hypervigilant
		_bump(outs, 1, -0.05)  # less rest — can't relax
		fired.append({"id": "grudge_blood_feud", "line": "IF blood feud THEN hostile + defensive + hypervigilant.", "w": 0.60})
	elif grudge_i >= 0.8:
		# Hatred level: avoid social, slight defend
		_bump(outs, 2, -0.06)  # less social — avoid people
		_bump(outs, 6, 0.06)   # mild defend — on guard
		_bump(outs, 7, 0.04)   # mild observe — watchful
		fired.append({"id": "grudge_hatred", "line": "IF hatred THEN avoid social + on guard.", "w": 0.40})
	elif grudge_i >= 0.3:
		# Grudge level: slight social withdrawal
		_bump(outs, 2, -0.03)  # mild social avoidance
		fired.append({"id": "grudge_mild", "line": "IF mild grudge THEN slight social avoidance.", "w": 0.20})

	# ==================== HeelKawnianMind rules ====================
	# Emotional pressure from mind snapshot shapes behavior
	var emotional: String = str(ctx.get("mind_emotional_pressure", ""))
	if emotional.contains("desperate"):
		_bump_many(outs, [0, 7], 0.12)  # seek food + withdraw
		_bump(outs, 3, -0.08)  # avoid risky forage
		fired.append({"id": "mind_desperate", "line": "IF desperate THEN seek food urgently + avoid risk.", "w": 0.70})
	elif emotional.contains("anxious"):
		_bump(outs, 0, 0.08)  # seek food
		_bump(outs, 7, 0.04)  # slight caution
		fired.append({"id": "mind_anxious", "line": "IF anxious THEN seek food + cautious.", "w": 0.45})
	elif emotional.contains("fearful"):
		_bump_many(outs, [1, 7], 0.10)  # rest + observe
		_bump(outs, 6, -0.06)  # avoid combat
		fired.append({"id": "mind_fearful", "line": "IF fearful THEN rest + observe + avoid combat.", "w": 0.55})
	elif emotional.contains("gloomy") or emotional.contains("despondent"):
		_bump(outs, 2, 0.08)  # seek social comfort
		_bump(outs, 7, 0.04)  # withdraw
		fired.append({"id": "mind_gloomy", "line": "IF gloomy THEN seek social comfort + withdraw.", "w": 0.40})
	elif emotional.contains("content"):
		_bump_many(outs, [3, 4], 0.05)  # productive — forage + build
		fired.append({"id": "mind_content", "line": "IF content THEN productive work.", "w": 0.30})
	elif emotional.contains("curious"):
		_bump_many(outs, [3, 7], 0.06)  # explore + forage
		fired.append({"id": "mind_curious", "line": "IF curious THEN explore + forage.", "w": 0.30})

	# Place feeling from WorldMeaning tags
	var place: String = str(ctx.get("mind_place_feeling", ""))
	if place == "dangerous":
		_bump_many(outs, [1, 7], 0.08)  # rest + observe — danger sense
		_bump(outs, 6, 0.06)  # defend — danger awareness
		_bump(outs, 3, -0.05)  # less forage — avoid risky areas
		fired.append({"id": "mind_place_dangerous", "line": "IF place feels dangerous THEN observe + defend + avoid forage.", "w": 0.50})
	elif place == "sacred":
		_bump(outs, 2, 0.06)  # social — sacred places draw community
		_bump(outs, 4, 0.04)  # build — sacred places inspire construction
		fired.append({"id": "mind_place_sacred", "line": "IF place feels sacred THEN social + build.", "w": 0.35})
	elif place == "home":
		_bump_many(outs, [2, 4], 0.05)  # social + build — home comfort
		fired.append({"id": "mind_place_home", "line": "IF place feels like home THEN social + build.", "w": 0.30})
	elif place == "haunted":
		_bump(outs, 7, 0.08)  # observe — unease
		_bump(outs, 1, 0.04)  # rest — cautious
		fired.append({"id": "mind_place_haunted", "line": "IF place feels haunted THEN observe + rest cautiously.", "w": 0.40})

	# Culture tradition from CulturalMemory
	var culture_t: String = str(ctx.get("mind_culture_tradition", ""))
	if culture_t == "martial":
		_bump_many(outs, [6, 0], 0.08)  # defend + seek food (warrior culture)
		fired.append({"id": "mind_culture_martial", "line": "IF martial culture THEN defend + provide.", "w": 0.40})
	elif culture_t == "scholarly":
		_bump(outs, 2, 0.10)  # social — teach and share
		_bump(outs, 5, 0.06)  # craft — knowledge work
		fired.append({"id": "mind_culture_scholarly", "line": "IF scholarly culture THEN teach + craft.", "w": 0.40})
	elif culture_t == "agrarian":
		_bump_many(outs, [3, 0], 0.08)  # forage + seek food (farming culture)
		fired.append({"id": "mind_culture_agrarian", "line": "IF agrarian culture THEN forage + feed.", "w": 0.40})
	elif culture_t == "mercantile":
		_bump(outs, 3, 0.06)  # forage — gather trade goods
		_bump(outs, 2, 0.04)  # social — trade requires contact
		fired.append({"id": "mind_culture_mercantile", "line": "IF mercantile culture THEN gather + socialize.", "w": 0.35})

	# Reputation from GossipManager — high reputation pawns lead
	var reputation: float = float(ctx.get("mind_reputation", 0.0))
	if reputation >= 0.7:
		_bump(outs, 2, 0.08)  # social — respected, sought out
		_bump(outs, 6, 0.06)  # defend — protect community
		fired.append({"id": "mind_reputation_high", "line": "IF high reputation THEN lead + defend.", "w": 0.40})
	elif reputation <= -0.5:
		_bump(outs, 2, -0.10)  # less social — shunned
		_bump(outs, 7, 0.06)  # observe — watchful, isolated
		fired.append({"id": "mind_reputation_low", "line": "IF low reputation THEN withdraw + observe.", "w": 0.40})

	# ==================== Knowledge rules ====================
	# Knowledge carriers are more productive and teach-oriented
	var knowledge_n: int = int(ctx.get("mind_knowledge_count", 0))
	if knowledge_n >= 8:
		# Scholar: strong teaching drive, less manual labor
		_bump(outs, 2, 0.12)   # social — teach and share
		_bump(outs, 5, 0.08)   # craft — knowledge work
		_bump(outs, 3, -0.04)  # less raw forage — mind on higher things
		fired.append({"id": "mind_knowledge_scholar", "line": "IF many knowledge THEN teach + craft + less forage.", "w": 0.50})
	elif knowledge_n >= 4:
		# Educated: mild teaching nudge
		_bump(outs, 2, 0.06)   # social — share knowledge
		_bump(outs, 5, 0.04)   # craft — apply knowledge
		fired.append({"id": "mind_knowledge_educated", "line": "IF some knowledge THEN share + apply.", "w": 0.35})

	# Knowledge at risk — only carrier for some knowledge type
	var knowledge_at_risk: bool = bool(ctx.get("mind_knowledge_at_risk", false))
	if knowledge_at_risk:
		_bump(outs, 2, 0.10)   # social — must teach before knowledge dies
		_bump(outs, 7, -0.06)  # less idle — urgency to pass on
		fired.append({"id": "mind_knowledge_at_risk", "line": "IF knowledge at risk THEN teach urgently + avoid idleness.", "w": 0.65})

	# ==================== Conflict/War memory rules ====================
	var conflict_n: int = int(ctx.get("mind_conflict_count", 0))
	if conflict_n >= 3:
		# War-scarred: defensive, watchful, less social trust
		_bump(outs, 6, 0.10)   # defend — battle-hardened
		_bump(outs, 7, 0.06)   # observe — watchful
		_bump(outs, 2, -0.06)  # less social — trust issues
		fired.append({"id": "mind_conflict_scarred", "line": "IF many conflicts THEN defensive + watchful + less social.", "w": 0.50})
	elif conflict_n >= 1:
		# Conflict-aware: mild defensiveness
		_bump(outs, 6, 0.04)   # mild defend
		fired.append({"id": "mind_conflict_aware", "line": "IF some conflicts THEN mild defensiveness.", "w": 0.25})

	# ==================== Combat Rank rules ====================
	# Combat rank from AICombatProgression — soldiers lead, defend, and patrol
	var combat_rank: int = int(ctx.get("combat_rank", pd.military_rank))
	if combat_rank >= 5:
		# GENERAL: strong leadership, defend, social authority
		_bump(outs, 6, 0.18)   # defend — leads military
		_bump(outs, 2, 0.12)   # social — commands, organizes
		_bump(outs, 7, -0.10)  # less idle — duty-bound
		fired.append({"id": "rank_general", "line": "IF general THEN lead + defend + social authority.", "w": 0.70})
	elif combat_rank >= 4:
		# CHAMPION: elite defender, inspires others
		_bump(outs, 6, 0.14)   # defend — champion warrior
		_bump(outs, 2, 0.08)   # social — inspires troops
		_bump(outs, 7, -0.06)  # less idle — vigilant
		fired.append({"id": "rank_champion", "line": "IF champion THEN defend + inspire.", "w": 0.60})
	elif combat_rank >= 3:
		# VETERAN: experienced, defensive, watchful
		_bump(outs, 6, 0.10)   # defend — battle-tested
		_bump(outs, 7, 0.04)   # observe — experienced caution
		fired.append({"id": "rank_veteran", "line": "IF veteran THEN defend + watchful.", "w": 0.50})
	elif combat_rank >= 2:
		# SOLDIER: combat-ready, defend bias
		_bump(outs, 6, 0.08)   # defend — trained fighter
		fired.append({"id": "rank_soldier", "line": "IF soldier THEN defend bias.", "w": 0.40})
	elif combat_rank >= 1:
		# RECRUIT: mild defend, still learning
		_bump(outs, 6, 0.04)   # mild defend — basic training
		fired.append({"id": "rank_recruit", "line": "IF recruit THEN mild defend.", "w": 0.25})

	# ==================== Warrior Threat rules ====================
	# Warriors who never relinquish force become threats
	var threat: String = str(ctx.get("warrior_threat", ""))
	if threat == "menace":
		# Menace: aggressive, antisocial, dangerous
		_bump(outs, 6, 0.20)   # defend — seeks violence
		_bump(outs, 2, -0.15)  # less social — alienated
		_bump(outs, 7, -0.10)  # less idle — can't stop
		_bump(outs, 3, -0.08)  # less forage — contempt for civilian work
		fired.append({"id": "threat_menace", "line": "IF menace THEN aggressive + antisocial + contempt for civilian life.", "w": 0.75})
	elif threat == "threatening":
		# Threatening: drawn to combat, withdrawing from community
		_bump(outs, 6, 0.12)   # defend — combat-seeking
		_bump(outs, 2, -0.08)  # less social — withdrawing
		_bump(outs, 7, -0.04)  # less idle — restless
		fired.append({"id": "threat_threatening", "line": "IF threatening THEN combat-seeking + withdrawing from community.", "w": 0.55})
	elif threat == "restless":
		# Restless: mild combat preference, slight social distance
		_bump(outs, 6, 0.06)   # mild defend — edgy
		_bump(outs, 2, -0.03)  # mild social withdrawal
		fired.append({"id": "threat_restless", "line": "IF restless THEN mild combat preference + slight withdrawal.", "w": 0.35})

	fired.sort_custom(func(a, b): return float(a.get("w", 0.0)) > float(b.get("w", 0.0)))
	var human_ch: Array = _build_human_channels(pd, ctx, outs)
	_apply_human_semantic_projection(outs, human_ch)
	for i in range(mini(8, outs.size())):
		human_ch[i] = float(outs[i])
	return {"fired": fired, "human_channels": human_ch, "human_channel_labels": HUMAN_CHANNEL_LABELS}
