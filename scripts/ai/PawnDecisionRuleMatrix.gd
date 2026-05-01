class_name PawnDecisionRuleMatrix
extends RefCounted

## Readable if/then policy layer on top of the per-pawn neural forward pass.
## Indices match WorldAI / Pawn job bias: 0 food, 1 rest, 2 social, 3 forage,
## 4 build, 5 mine, 6 defend, 7 idle.
## [method evaluate] mutates [param outs] in place and returns fired rules for UI / telemetry.

const OUT_CLAMP_MIN: float = 0.0
const OUT_CLAMP_MAX: float = 2.0
## Keep in sync with [member Pawn.FOUNDING_PERIOD_TICKS].
const FOUNDING_PERIOD_TICKS: int = 4500


func _bump(outs: Array, idx: int, delta: float) -> void:
	if outs.size() <= idx:
		return
	var v: float = float(outs[idx]) + delta
	outs[idx] = clampf(v, OUT_CLAMP_MIN, OUT_CLAMP_MAX)


func _bump_many(outs: Array, indices: Array, delta: float) -> void:
	for i in indices:
		_bump(outs, int(i), delta)


func evaluate(pd: PawnData, ctx: Dictionary, outs: Array) -> Array:
	var fired: Array = []
	if pd == null or outs.size() < 8:
		return fired

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

	# --- Founding phase (matches Pawn founding blend) ---
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

	fired.sort_custom(func(a, b): return float(a.get("w", 0.0)) > float(b.get("w", 0.0)))
	return fired
