extends Node
## LanguageSystem — Emergent language dialects across settlements.
## Each settlement develops its own naming patterns over time.
## Dialects diverge more with distance. Trade and contact slow divergence.
## Names, words, and phrases are generated deterministically per settlement.
## Very Dwarf Fortress. Adds texture to world without mechanical overhead.

const VOWELS: String = "aeiouy"
const CONSONANTS: String = "bcdfghjklmnpqrstvwxz"

# Per-settlement dialect data
var _dialects: Dictionary = {}

func _ready() -> void:
	if GameManager != null:
		GameManager.game_tick.connect(_on_game_tick)

func get_or_create_dialect(settlement_id: int) -> Dictionary:
	if _dialects.has(settlement_id):
		return _dialects[settlement_id]
	var seed_salt: int = settlement_id * 7
	var name_pattern: String = _generate_pattern(seed_salt)
	var consonants: String = _shuffle_string(CONSONANTS, seed_salt)
	var vowels: String = _shuffle_string(VOWELS, seed_salt + 1)
	_dialects[settlement_id] = {
		"settlement_id": settlement_id,
		"name_pattern": name_pattern,
		"consonant_order": consonants,
		"vowel_order": vowels,
		"words": {},
	}
	return _dialects[settlement_id]

func _generate_pattern(seed: int) -> String:
	var patterns: Array = ["CVC", "CVCV", "VCV", "CVCVC", "VCVCV", "CVCCV", "CCVCV"]
	return patterns[seed % patterns.size()]

func _shuffle_string(s: String, seed: int) -> String:
	var chars: Array = []
	for c in s:
		chars.append(c)
	for i in range(chars.size() - 1, 0, -1):
		var j: int = (seed + i * 7) % (i + 1)
		var tmp = chars[i]
		chars[i] = chars[j]
		chars[j] = tmp
	return "".join(chars)

func generate_name(settlement_id: int, length: int = 4) -> String:
	var dialect: Dictionary = get_or_create_dialect(settlement_id)
	var pattern: String = dialect.get("name_pattern", "CVC")
	var cons: String = dialect.get("consonant_order", CONSONANTS)
	var vows: String = dialect.get("vowel_order", VOWELS)
	var name: String = ""
	var ci: int = 0
	var vi: int = 0
	for _i in range(length):
		if _i % 2 == 0:
			name += cons[ci % cons.length()]
			ci += 1
		else:
			name += vows[vi % vows.length()]
			vi += 1
		name = name.capitalize()
	return name

func generate_word(settlement_id: int, meaning: String) -> String:
	var dialect: Dictionary = get_or_create_dialect(settlement_id)
	if not dialect.get("words", {}).has(meaning):
		var word: String = generate_name(settlement_id, WorldRNG.rangei(3, 6, settlement_id, &"word_len_%s" % meaning))
		dialect["words"][meaning] = word
	return dialect["words"][meaning]

func get_dialect_word(settlement_id: int, meaning: String) -> String:
	var dialect: Dictionary = _dialects.get(settlement_id, {})
	if dialect.is_empty():
		return meaning
	return dialect.get("words", {}).get(meaning, meaning)

func _on_game_tick(_tick: int) -> void:
