extends Node
## CurrencySystem — Emergent currency from barter to minted coin.
## Phase 1: Pure barter (item-for-item, no currency).
## Phase 2: Commodity money (gems, rare shells, salt — high-value items used as reference).
## Phase 3: Minted currency (settlements mint coins with authority backing).
## Currency emerges naturally when settlements reach sufficient trade volume.
## All tracked in WorldMemory. Deterministic exchange rates.

enum CurrencyPhase {
	BARTER,        # no currency, direct exchange
	COMMODITY,     # gems/salt used as reference value
	MINTED,        # settlement-minted coins
}

var _phase: int = CurrencyPhase.BARTER
var _mints: Dictionary = {}
var _exchange_rates: Dictionary = {}
var _trade_volume: int = 0
const MAX_RATE_SAMPLES_PER_PAIR: int = 64
const RATE_RETENTION_TICKS: int = 5000

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)

func get_phase() -> int:
	return _phase

func record_trade(item_a: int, item_b: int, qty_a: int, qty_b: int) -> void:
	_trade_volume += 1
	var key: String = "%d_%d" % [mini(item_a, item_b), maxi(item_a, item_b)]
	if not _exchange_rates.has(key):
		_exchange_rates[key] = []
	var samples: Array = _exchange_rates[key]
	samples.append({"a": qty_a, "b": qty_b, "tick": GameManager.tick_count if GameManager != null else 0})
	if samples.size() > MAX_RATE_SAMPLES_PER_PAIR:
		samples.remove_at(0)
	_exchange_rates[key] = samples
	if _trade_volume >= 50 and _phase == CurrencyPhase.BARTER:
		_advance_phase(CurrencyPhase.COMMODITY)
	if _trade_volume >= 200 and _phase == CurrencyPhase.COMMODITY:
		if not _mints.is_empty():
			_advance_phase(CurrencyPhase.MINTED)

func _advance_phase(new_phase: int) -> void:
	_phase = new_phase
	WorldMemory.record_event({
		"kind": WorldMemory.Kind.LIFE_EVENT,
		"tick": GameManager.tick_count if GameManager != null else 0,
		"currency_phase": new_phase,
		"trade_volume": _trade_volume,
	})

func establish_mint(settlement_id: int, mint_name: String) -> void:
	_mints[settlement_id] = {
		"name": mint_name,
		"tick_established": GameManager.tick_count if GameManager != null else 0,
		"coins_minted": 0,
	}
	WorldMemory.record_event({
		"kind": WorldMemory.Kind.LIFE_EVENT,
		"tick": GameManager.tick_count if GameManager != null else 0,
		"mint_established": true,
		"settlement_id": settlement_id,
		"mint_name": mint_name,
	})

func mint_coins(settlement_id: int, amount: int) -> void:
	if _mints.has(settlement_id):
		_mints[settlement_id]["coins_minted"] = int(_mints[settlement_id].get("coins_minted", 0)) + amount

func get_approximate_value(item_type: int) -> int:
	match item_type:
		Item.Type.WOOD, Item.Type.STICK: return 1
		Item.Type.STONE, Item.Type.FLINT: return 2
		Item.Type.FOOD, Item.Type.BERRY: return 1
		Item.Type.RAW_FOOD: return 1
		Item.Type.MEAT: return 3
		Item.Type.HIDE: return 5
		Item.Type.COAL: return 4
		Item.Type.IRON_ORE: return 8
		Item.Type.GOLD_ORE: return 20
		Item.Type.GEM: return 50
		Item.Type.MEAD, Item.Type.ALE: return 6
		_: return 1

func _on_game_tick(tick: int) -> void:
	if tick <= 0:
		return
	# Periodic compaction avoids unbounded per-pair history growth in long simulations.
	if tick % 500 != 0:
		return
	var min_tick: int = tick - RATE_RETENTION_TICKS
	for key in _exchange_rates.keys():
		var samples: Array = _exchange_rates.get(key, [])
		if samples.is_empty():
			continue
		var filtered: Array = []
		for sample in samples:
			if int(sample.get("tick", 0)) >= min_tick:
				filtered.append(sample)
		if filtered.size() > MAX_RATE_SAMPLES_PER_PAIR:
			var start: int = filtered.size() - MAX_RATE_SAMPLES_PER_PAIR
			filtered = filtered.slice(start, filtered.size())
		_exchange_rates[key] = filtered
